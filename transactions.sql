USE CPSDB;

DROP PROCEDURE IF EXISTS sp_apply_for_job;
DROP PROCEDURE IF EXISTS sp_record_result;
DROP PROCEDURE IF EXISTS sp_issue_offer;
DROP PROCEDURE IF EXISTS sp_accept_offer;
DROP PROCEDURE IF EXISTS sp_withdraw_application;

DELIMITER $$

CREATE PROCEDURE sp_apply_for_job(IN p_student INT, IN p_job INT, OUT p_application INT)
BEGIN
    DECLARE v_company INT;
    DECLARE v_oa_passed INT DEFAULT 0;
    DECLARE v_compulsory_count INT DEFAULT 0;
    DECLARE v_matched_compulsory INT DEFAULT 0;
    DECLARE v_total_job_skills INT DEFAULT 0;
    DECLARE v_matched_any_skills INT DEFAULT 0;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT Company_ID INTO v_company FROM JOB_POSTING WHERE Job_ID = p_job;
    
    SELECT COUNT(*) INTO v_oa_passed
    FROM OA_RESULT oar
    JOIN ONLINE_ASSESSMENT oa ON oa.OA_ID = oar.OA_ID
    WHERE oa.Company_ID = v_company AND oar.Student_ID = p_student AND oar.Is_Passed = TRUE;

    IF v_oa_passed = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student must pass the company Online Assessment to apply';
    END IF;

    SELECT COUNT(*) INTO v_compulsory_count FROM JOB_SKILL WHERE Job_ID = p_job AND Is_Compulsory = TRUE;

    IF v_compulsory_count > 0 THEN
        SELECT COUNT(*) INTO v_matched_compulsory
        FROM JOB_SKILL js
        JOIN STUDENT_SKILL ss ON js.Skill_ID = ss.Skill_ID
        WHERE js.Job_ID = p_job AND js.Is_Compulsory = TRUE AND ss.Student_ID = p_student;

        IF v_matched_compulsory < v_compulsory_count THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student does not possess all compulsory skills required for this job';
        END IF;
    ELSE
        SELECT COUNT(*) INTO v_total_job_skills FROM JOB_SKILL WHERE Job_ID = p_job;

        IF v_total_job_skills > 0 THEN
            SELECT COUNT(*) INTO v_matched_any_skills
            FROM JOB_SKILL js
            JOIN STUDENT_SKILL ss ON js.Skill_ID = ss.Skill_ID
            WHERE js.Job_ID = p_job AND ss.Student_ID = p_student;

            IF v_matched_any_skills = 0 THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student must possess at least one skill required for this job';
            END IF;
        END IF;
    END IF;

    SELECT COALESCE(MAX(Application_ID), 0) + 1 INTO p_application FROM APPLICATION FOR UPDATE;
    INSERT INTO APPLICATION (Application_ID, Student_ID, Job_ID, Applied_Date, Current_Status)
    VALUES (p_application, p_student, p_job, CURDATE(), 'Applied');
    
    COMMIT;
END$$

CREATE PROCEDURE sp_record_result(IN p_application INT, IN p_round INT, IN p_score DECIMAL(7,2),
                                  IN p_status VARCHAR(30), IN p_remarks TEXT, OUT p_result INT)
BEGIN
    DECLARE v_job INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
    SELECT Job_ID INTO v_job FROM RECRUITMENT_ROUND WHERE Round_ID = p_round;
    IF v_job IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Recruitment round not found';
    END IF;
    SELECT COALESCE(MAX(Result_ID), 0) + 1 INTO p_result FROM RESULT FOR UPDATE;
    INSERT INTO RESULT (Result_ID, Application_ID, Round_ID, Job_ID, Score, Result_Status, Remarks)
    VALUES (p_result, p_application, p_round, v_job, p_score, p_status, p_remarks);
    COMMIT;
END$$

CREATE PROCEDURE sp_issue_offer(IN p_application INT, IN p_ctc DECIMAL(12,2),
                                IN p_joining DATE, OUT p_offer INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
    SELECT COALESCE(MAX(Offer_ID), 0) + 1 INTO p_offer FROM PLACEMENT_OFFER FOR UPDATE;
    INSERT INTO PLACEMENT_OFFER (Offer_ID, Application_ID, Offered_CTC, Offer_Date,
                                 Expected_Joining_Date, Offer_Status)
    VALUES (p_offer, p_application, p_ctc, CURDATE(), p_joining, 'Pending');
    COMMIT;
END$$

CREATE PROCEDURE sp_accept_offer(IN p_offer INT)
BEGIN
    DECLARE v_student INT;
    DECLARE v_status VARCHAR(30);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
    SELECT a.Student_ID, po.Offer_Status INTO v_student, v_status
      FROM PLACEMENT_OFFER po JOIN APPLICATION a ON a.Application_ID = po.Application_ID
     WHERE po.Offer_ID = p_offer
       FOR UPDATE;

    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Offer not found';
    END IF;
    IF v_status <> 'Pending' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only Pending offers can be accepted';
    END IF;

    UPDATE PLACEMENT_OFFER po JOIN APPLICATION a ON a.Application_ID = po.Application_ID
       SET po.Offer_Status = 'Rejected'
     WHERE a.Student_ID = v_student AND po.Offer_ID <> p_offer AND po.Offer_Status = 'Pending';

    UPDATE PLACEMENT_OFFER SET Offer_Status = 'Accepted' WHERE Offer_ID = p_offer;
    COMMIT;
END$$

CREATE PROCEDURE sp_withdraw_application(IN p_application INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
    UPDATE PLACEMENT_OFFER SET Offer_Status = 'Revoked'
     WHERE Application_ID = p_application AND Offer_Status = 'Pending';
    UPDATE APPLICATION SET Current_Status = 'Withdrawn' WHERE Application_ID = p_application;
    COMMIT;
END$$

DELIMITER ;