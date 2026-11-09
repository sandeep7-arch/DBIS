USE CPSDB;

DROP TRIGGER IF EXISTS trg_application_bi;
DROP TRIGGER IF EXISTS trg_application_bu;
DROP TRIGGER IF EXISTS trg_result_bi;
DROP TRIGGER IF EXISTS trg_result_bu;
DROP TRIGGER IF EXISTS trg_result_ai;
DROP TRIGGER IF EXISTS trg_result_au;
DROP TRIGGER IF EXISTS trg_result_ad;
DROP TRIGGER IF EXISTS trg_offer_bi;
DROP TRIGGER IF EXISTS trg_offer_bu;
DROP PROCEDURE IF EXISTS sp_sync_application_status;

DELIMITER $$

CREATE PROCEDURE sp_sync_application_status(IN p_app INT)
BEGIN
    DECLARE v_job INT;
    DECLARE v_status VARCHAR(30);
    DECLARE v_total INT DEFAULT 0;
    DECLARE v_pass INT DEFAULT 0;
    DECLARE v_bad INT DEFAULT 0;
    DECLARE v_new VARCHAR(30);

    SELECT Job_ID, Current_Status INTO v_job, v_status
      FROM APPLICATION WHERE Application_ID = p_app;

    IF v_job IS NOT NULL AND v_status <> 'Withdrawn' THEN
        SELECT COUNT(*) INTO v_total FROM RECRUITMENT_ROUND WHERE Job_ID = v_job;
        SELECT COALESCE(SUM(Result_Status IN ('Fail','Absent')), 0),
               COALESCE(SUM(Result_Status = 'Pass'), 0)
          INTO v_bad, v_pass
          FROM RESULT WHERE Application_ID = p_app;

        IF v_bad > 0 THEN
            SET v_new = 'Rejected';
        ELSEIF v_total > 0 AND v_pass >= v_total THEN
            SET v_new = 'Selected';
        ELSEIF v_pass > 0 THEN
            SET v_new = 'In Progress';
        ELSE
            SET v_new = 'Shortlisted';
        END IF;

        IF v_new <> v_status THEN
            UPDATE APPLICATION SET Current_Status = v_new WHERE Application_ID = p_app;
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_application_bi BEFORE INSERT ON APPLICATION
FOR EACH ROW
BEGIN
    DECLARE v_cgpa DECIMAL(4,2);
    DECLARE v_bl INT;
    DECLARE v_min DECIMAL(4,2);
    DECLARE v_allowed INT;
    DECLARE v_deadline DATE;
    DECLARE v_company INT;
    DECLARE v_oa_passed INT DEFAULT 0;
    DECLARE v_compulsory_count INT DEFAULT 0;
    DECLARE v_matched_compulsory INT DEFAULT 0;
    DECLARE v_total_job_skills INT DEFAULT 0;
    DECLARE v_matched_any_skills INT DEFAULT 0;

    SELECT CGPA, Backlogs INTO v_cgpa, v_bl FROM STUDENT WHERE Student_ID = NEW.Student_ID;
    SELECT Company_ID, Min_CGPA, Allowed_Backlogs, Application_Deadline
      INTO v_company, v_min, v_allowed, v_deadline FROM JOB_POSTING WHERE Job_ID = NEW.Job_ID;

    IF v_min IS NOT NULL AND v_cgpa IS NOT NULL AND v_cgpa < v_min THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student CGPA is below the job minimum CGPA';
    END IF;

    IF v_allowed IS NOT NULL AND v_bl IS NOT NULL AND v_bl > v_allowed THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student backlogs exceed the allowed backlogs for this job';
    END IF;

    IF v_deadline IS NOT NULL AND NEW.Applied_Date > v_deadline THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Application deadline has passed for this job';
    END IF;

    SELECT COUNT(*) INTO v_oa_passed
    FROM OA_RESULT oar
    JOIN ONLINE_ASSESSMENT oa ON oa.OA_ID = oar.OA_ID
    WHERE oa.Company_ID = v_company AND oar.Student_ID = NEW.Student_ID AND oar.Is_Passed = TRUE;

    IF v_oa_passed = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student must pass the company Online Assessment to apply/be shortlisted';
    END IF;

    SELECT COUNT(*) INTO v_compulsory_count FROM JOB_SKILL WHERE Job_ID = NEW.Job_ID AND Is_Compulsory = TRUE;

    IF v_compulsory_count > 0 THEN
        SELECT COUNT(*) INTO v_matched_compulsory
        FROM JOB_SKILL js
        JOIN STUDENT_SKILL ss ON js.Skill_ID = ss.Skill_ID
        WHERE js.Job_ID = NEW.Job_ID AND js.Is_Compulsory = TRUE AND ss.Student_ID = NEW.Student_ID;

        IF v_matched_compulsory < v_compulsory_count THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student does not possess all compulsory skills required for this job';
        END IF;
    ELSE
        SELECT COUNT(*) INTO v_total_job_skills FROM JOB_SKILL WHERE Job_ID = NEW.Job_ID;

        IF v_total_job_skills > 0 THEN
            SELECT COUNT(*) INTO v_matched_any_skills
            FROM JOB_SKILL js
            JOIN STUDENT_SKILL ss ON js.Skill_ID = ss.Skill_ID
            WHERE js.Job_ID = NEW.Job_ID AND ss.Student_ID = NEW.Student_ID;

            IF v_matched_any_skills = 0 THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student must possess at least one skill required for this job';
            END IF;
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_application_bu BEFORE UPDATE ON APPLICATION
FOR EACH ROW
BEGIN
    IF NEW.Student_ID <> OLD.Student_ID OR NEW.Job_ID <> OLD.Job_ID THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student_ID and Job_ID of an application cannot be changed';
    END IF;
END$$

CREATE TRIGGER trg_result_bi BEFORE INSERT ON RESULT
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(30);
    DECLARE v_order INT;
    DECLARE v_required INT DEFAULT 0;
    DECLARE v_passed INT DEFAULT 0;

    SELECT Current_Status INTO v_status FROM APPLICATION WHERE Application_ID = NEW.Application_ID;
    IF v_status IN ('Rejected','Withdrawn','Selected') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot add results to a closed application (Rejected/Withdrawn/Selected)';
    END IF;

    SELECT Round_Order INTO v_order FROM RECRUITMENT_ROUND WHERE Round_ID = NEW.Round_ID;
    IF v_order IS NOT NULL AND v_order > 1 THEN
        SELECT COUNT(*) INTO v_required FROM RECRUITMENT_ROUND
         WHERE Job_ID = NEW.Job_ID AND Round_Order < v_order;
        SELECT COUNT(DISTINCT r.Round_ID) INTO v_passed
          FROM RESULT r JOIN RECRUITMENT_ROUND rr ON rr.Round_ID = r.Round_ID
         WHERE r.Application_ID = NEW.Application_ID AND rr.Job_ID = NEW.Job_ID
           AND rr.Round_Order < v_order AND r.Result_Status = 'Pass';
        IF v_passed < v_required THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'All earlier rounds must be passed before this round';
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_result_bu BEFORE UPDATE ON RESULT
FOR EACH ROW
BEGIN
    IF NEW.Application_ID <> OLD.Application_ID OR NEW.Round_ID <> OLD.Round_ID OR NEW.Job_ID <> OLD.Job_ID THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Application, round and job of a result cannot be changed';
    END IF;
END$$

CREATE TRIGGER trg_result_ai AFTER INSERT ON RESULT
FOR EACH ROW
BEGIN
    CALL sp_sync_application_status(NEW.Application_ID);
END$$

CREATE TRIGGER trg_result_au AFTER UPDATE ON RESULT
FOR EACH ROW
BEGIN
    CALL sp_sync_application_status(NEW.Application_ID);
END$$

CREATE TRIGGER trg_result_ad AFTER DELETE ON RESULT
FOR EACH ROW
BEGIN
    CALL sp_sync_application_status(OLD.Application_ID);
END$$

CREATE TRIGGER trg_offer_bi BEFORE INSERT ON PLACEMENT_OFFER
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(30);
    DECLARE v_student INT;
    DECLARE v_job_ctc DECIMAL(12,2);
    DECLARE v_cnt INT DEFAULT 0;

    SELECT a.Current_Status, a.Student_ID, j.CTC INTO v_status, v_student, v_job_ctc
      FROM APPLICATION a JOIN JOB_POSTING j ON j.Job_ID = a.Job_ID
     WHERE a.Application_ID = NEW.Application_ID;

    IF v_status IS NOT NULL AND v_status <> 'Selected' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Offers can only be issued for Selected applications';
    END IF;

    IF NEW.Offered_CTC IS NULL THEN SET NEW.Offered_CTC = v_job_ctc; END IF;
    IF NEW.Offer_Date  IS NULL THEN SET NEW.Offer_Date  = CURDATE(); END IF;

    IF NEW.Offer_Status = 'Accepted' THEN
        SELECT COUNT(*) INTO v_cnt
          FROM PLACEMENT_OFFER po JOIN APPLICATION a ON a.Application_ID = po.Application_ID
         WHERE a.Student_ID = v_student AND po.Offer_Status = 'Accepted';
        IF v_cnt > 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student has already accepted another offer';
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_offer_bu BEFORE UPDATE ON PLACEMENT_OFFER
FOR EACH ROW
BEGIN
    DECLARE v_student INT;
    DECLARE v_cnt INT DEFAULT 0;

    IF NEW.Application_ID <> OLD.Application_ID THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Application_ID of an offer cannot be changed';
    END IF;

    IF NEW.Offer_Status = 'Accepted' THEN
        SELECT Student_ID INTO v_student FROM APPLICATION WHERE Application_ID = NEW.Application_ID;
        SELECT COUNT(*) INTO v_cnt
          FROM PLACEMENT_OFFER po JOIN APPLICATION a ON a.Application_ID = po.Application_ID
         WHERE a.Student_ID = v_student AND po.Offer_Status = 'Accepted'
           AND po.Offer_ID <> NEW.Offer_ID;
        IF v_cnt > 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student has already accepted another offer';
        END IF;
    END IF;
END$$

DELIMITER ;