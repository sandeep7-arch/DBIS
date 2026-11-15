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
DROP PROCEDURE IF EXISTS sp_record_oa_result;

DROP TRIGGER IF EXISTS check_cgpa;
DROP TRIGGER IF EXISTS check_backlogs;
DROP TRIGGER IF EXISTS check_deadline;
DROP TRIGGER IF EXISTS check_oa_passed;
DROP TRIGGER IF EXISTS check_compulsory_skills;
DROP TRIGGER IF EXISTS check_any_skill;
DROP TRIGGER IF EXISTS fixed_application_keys;
DROP TRIGGER IF EXISTS check_open_application;
DROP TRIGGER IF EXISTS check_previous_rounds;
DROP TRIGGER IF EXISTS update_status_after_result;
DROP TRIGGER IF EXISTS check_offer_selected;
DROP TRIGGER IF EXISTS default_offer_values;
DROP TRIGGER IF EXISTS one_accepted_offer_insert;
DROP TRIGGER IF EXISTS one_accepted_offer;

DELIMITER //
CREATE TRIGGER check_cgpa
BEFORE INSERT ON APPLICATION
FOR EACH ROW
BEGIN
    IF (SELECT CGPA FROM STUDENT WHERE Student_ID = NEW.Student_ID)
       < (SELECT Min_CGPA FROM JOB_POSTING WHERE Job_ID = NEW.Job_ID) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student CGPA is below the job minimum CGPA';
    END IF;
END//
DELIMITER ;

DELIMITER //
CREATE TRIGGER check_backlogs
BEFORE INSERT ON APPLICATION
FOR EACH ROW
BEGIN
    IF (SELECT Backlogs FROM STUDENT WHERE Student_ID = NEW.Student_ID)
       > (SELECT Allowed_Backlogs FROM JOB_POSTING WHERE Job_ID = NEW.Job_ID) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student backlogs exceed the allowed backlogs for this job';
    END IF;
END//
DELIMITER ;

DELIMITER //
CREATE TRIGGER check_deadline
BEFORE INSERT ON APPLICATION
FOR EACH ROW
BEGIN
    IF NEW.Applied_Date > (SELECT Application_Deadline FROM JOB_POSTING WHERE Job_ID = NEW.Job_ID) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Application deadline has passed for this job';
    END IF;
END//
DELIMITER ;

DELIMITER //
CREATE TRIGGER check_oa_passed
BEFORE INSERT ON APPLICATION
FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT * FROM OA_RESULT r
                   JOIN ONLINE_ASSESSMENT o ON o.OA_ID = r.OA_ID
                   JOIN JOB_POSTING j ON j.Company_ID = o.Company_ID
                   WHERE r.Student_ID = NEW.Student_ID
                     AND j.Job_ID = NEW.Job_ID
                     AND r.Is_Passed = TRUE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student must pass the company Online Assessment to apply';
    END IF;
END//
DELIMITER ;

DELIMITER //
CREATE TRIGGER check_compulsory_skills
BEFORE INSERT ON APPLICATION
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT * FROM JOB_SKILL js
               WHERE js.Job_ID = NEW.Job_ID
                 AND js.Is_Compulsory = TRUE
                 AND NOT EXISTS (SELECT * FROM STUDENT_SKILL ss
                                 WHERE ss.Student_ID = NEW.Student_ID
                                   AND ss.Skill_ID = js.Skill_ID)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student does not possess all compulsory skills required for this job';
    END IF;
END//
DELIMITER ;

DELIMITER //
CREATE TRIGGER check_any_skill
BEFORE INSERT ON APPLICATION
FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT * FROM JOB_SKILL WHERE Job_ID = NEW.Job_ID AND Is_Compulsory = TRUE)
       AND EXISTS (SELECT * FROM JOB_SKILL WHERE Job_ID = NEW.Job_ID)
       AND NOT EXISTS (SELECT * FROM JOB_SKILL js
                       JOIN STUDENT_SKILL ss ON ss.Skill_ID = js.Skill_ID
                       WHERE js.Job_ID = NEW.Job_ID AND ss.Student_ID = NEW.Student_ID) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student must possess at least one skill required for this job';
    END IF;
END//
DELIMITER ;

DELIMITER //
CREATE TRIGGER fixed_application_keys
BEFORE UPDATE ON APPLICATION
FOR EACH ROW
BEGIN
    IF NEW.Student_ID <> OLD.Student_ID OR NEW.Job_ID <> OLD.Job_ID THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student_ID and Job_ID of an application cannot be changed';
    END IF;
END//
DELIMITER ;

DELIMITER //
CREATE TRIGGER check_open_application
BEFORE INSERT ON RESULT
FOR EACH ROW
BEGIN
    IF (SELECT Current_Status FROM APPLICATION WHERE Application_ID = NEW.Application_ID)
       IN ('Rejected', 'Withdrawn', 'Selected') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot add results to a closed application (Rejected/Withdrawn/Selected)';
    END IF;
END//
DELIMITER ;

DELIMITER //
CREATE TRIGGER check_previous_rounds
BEFORE INSERT ON RESULT
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT * FROM RECRUITMENT_ROUND rr
               WHERE rr.Job_ID = NEW.Job_ID
                 AND rr.Round_Order < (SELECT Round_Order FROM RECRUITMENT_ROUND
                                       WHERE Round_ID = NEW.Round_ID)
                 AND NOT EXISTS (SELECT * FROM RESULT r
                                 WHERE r.Application_ID = NEW.Application_ID
                                   AND r.Round_ID = rr.Round_ID
                                   AND r.Result_Status = 'Pass')) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'All earlier rounds must be passed before this round';
    END IF;
END//
DELIMITER ;

DELIMITER //
CREATE TRIGGER update_status_after_result
AFTER INSERT ON RESULT
FOR EACH ROW
BEGIN
    IF NEW.Result_Status <> 'Pass' THEN
        UPDATE APPLICATION SET Current_Status = 'Rejected'
        WHERE Application_ID = NEW.Application_ID;
    ELSEIF NOT EXISTS (SELECT * FROM RECRUITMENT_ROUND
                       WHERE Job_ID = NEW.Job_ID
                         AND Round_Order > (SELECT Round_Order FROM RECRUITMENT_ROUND
                                            WHERE Round_ID = NEW.Round_ID)) THEN
        UPDATE APPLICATION SET Current_Status = 'Selected'
        WHERE Application_ID = NEW.Application_ID;
    ELSE
        UPDATE APPLICATION SET Current_Status = 'In Progress'
        WHERE Application_ID = NEW.Application_ID;
    END IF;
END//
DELIMITER ;

DELIMITER //
CREATE TRIGGER check_offer_selected
BEFORE INSERT ON PLACEMENT_OFFER
FOR EACH ROW
BEGIN
    IF (SELECT Current_Status FROM APPLICATION WHERE Application_ID = NEW.Application_ID) <> 'Selected' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Offers can only be issued for Selected applications';
    END IF;
END//
DELIMITER ;

DELIMITER //
CREATE TRIGGER default_offer_values
BEFORE INSERT ON PLACEMENT_OFFER
FOR EACH ROW
BEGIN
    IF NEW.Offered_CTC IS NULL THEN
        SET NEW.Offered_CTC = (SELECT j.CTC FROM APPLICATION a
                               JOIN JOB_POSTING j ON j.Job_ID = a.Job_ID
                               WHERE a.Application_ID = NEW.Application_ID);
    END IF;
    IF NEW.Offer_Date IS NULL THEN
        SET NEW.Offer_Date = CURDATE();
    END IF;
END//
DELIMITER ;

DELIMITER //
CREATE TRIGGER one_accepted_offer_insert
BEFORE INSERT ON PLACEMENT_OFFER
FOR EACH ROW
BEGIN
    IF NEW.Offer_Status = 'Accepted'
       AND EXISTS (SELECT * FROM PLACEMENT_OFFER po
                   JOIN APPLICATION a ON a.Application_ID = po.Application_ID
                   WHERE po.Offer_Status = 'Accepted'
                     AND a.Student_ID = (SELECT Student_ID FROM APPLICATION
                                         WHERE Application_ID = NEW.Application_ID)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student has already accepted another offer';
    END IF;
END//
DELIMITER ;

DELIMITER //
CREATE TRIGGER one_accepted_offer
BEFORE UPDATE ON PLACEMENT_OFFER
FOR EACH ROW
BEGIN
    IF NEW.Offer_Status = 'Accepted'
       AND EXISTS (SELECT * FROM PLACEMENT_OFFER po
                   JOIN APPLICATION a ON a.Application_ID = po.Application_ID
                   WHERE po.Offer_Status = 'Accepted'
                     AND po.Offer_ID <> NEW.Offer_ID
                     AND a.Student_ID = (SELECT Student_ID FROM APPLICATION
                                         WHERE Application_ID = NEW.Application_ID)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student has already accepted another offer';
    END IF;
END//
DELIMITER ;

-- Records a student's Online Assessment score; Is_Passed is derived from the
-- company's Passing_Score. Re-recording a score overwrites the earlier one.
-- Runs as one transaction and commits, so the row is really saved.
DELIMITER //
CREATE PROCEDURE sp_record_oa_result(
    IN p_oa INT, IN p_student INT, IN p_score DECIMAL(5,2), OUT p_passed TINYINT)
BEGIN
    DECLARE v_pass DECIMAL(5,2);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT Passing_Score INTO v_pass FROM ONLINE_ASSESSMENT WHERE OA_ID = p_oa;
    IF v_pass IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Online assessment not found';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM STUDENT WHERE Student_ID = p_student) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student not found';
    END IF;
    IF p_score < 0 OR p_score > 100 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Score must be between 0 and 100';
    END IF;

    SET p_passed = (p_score >= v_pass);
    INSERT INTO OA_RESULT (OA_ID, Student_ID, Score, Is_Passed)
    VALUES (p_oa, p_student, p_score, p_passed)
    ON DUPLICATE KEY UPDATE Score = p_score, Is_Passed = p_passed;

    COMMIT;
END//
DELIMITER ;