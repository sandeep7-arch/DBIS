USE CPSDB;

DROP PROCEDURE IF EXISTS sp_apply_for_job;
DROP PROCEDURE IF EXISTS sp_record_result;
DROP PROCEDURE IF EXISTS sp_issue_offer;
DROP PROCEDURE IF EXISTS sp_accept_offer;
DROP PROCEDURE IF EXISTS sp_withdraw_application;
DROP PROCEDURE IF EXISTS sp_add_department;
DROP PROCEDURE IF EXISTS sp_add_student;
DROP PROCEDURE IF EXISTS sp_add_skill;
DROP PROCEDURE IF EXISTS sp_add_student_skill;
DROP PROCEDURE IF EXISTS sp_add_company;
DROP PROCEDURE IF EXISTS sp_add_oa;
DROP PROCEDURE IF EXISTS sp_add_job;
DROP PROCEDURE IF EXISTS sp_add_job_skill;
DROP PROCEDURE IF EXISTS sp_add_round;

-- ==================================================================
-- Workflow procedures. Each one is a single transaction: it either
-- commits completely or rolls back and re-raises the original error
-- (including the messages signalled by the triggers).
-- ==================================================================

DELIMITER //
CREATE PROCEDURE sp_apply_for_job(IN p_student INT, IN p_job INT, OUT p_app INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM STUDENT WHERE Student_ID = p_student) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student not found';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM JOB_POSTING WHERE Job_ID = p_job) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Job posting not found';
    END IF;
    IF EXISTS (SELECT 1 FROM APPLICATION WHERE Student_ID = p_student AND Job_ID = p_job) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student has already applied for this job';
    END IF;

    INSERT INTO APPLICATION (Student_ID, Job_ID, Applied_Date, Current_Status)
    VALUES (p_student, p_job, CURDATE(), 'Applied');
    SET p_app = LAST_INSERT_ID();

    COMMIT;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_record_result(
    IN p_app INT, IN p_round INT, IN p_score DECIMAL(7,2),
    IN p_status VARCHAR(30), IN p_remarks TEXT, OUT p_id INT)
BEGIN
    DECLARE v_job INT;
    DECLARE v_round_job INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT Job_ID INTO v_job FROM APPLICATION WHERE Application_ID = p_app;
    IF v_job IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Application not found';
    END IF;
    SELECT Job_ID INTO v_round_job FROM RECRUITMENT_ROUND WHERE Round_ID = p_round;
    IF v_round_job IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Round not found';
    END IF;
    IF v_round_job <> v_job THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This round does not belong to the job of the application';
    END IF;
    IF p_status NOT IN ('Pass', 'Fail', 'Absent') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Result status must be Pass, Fail or Absent';
    END IF;
    IF EXISTS (SELECT 1 FROM RESULT WHERE Application_ID = p_app AND Round_ID = p_round) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A result is already recorded for this round';
    END IF;

    -- triggers check the earlier rounds and update the application status
    INSERT INTO RESULT (Application_ID, Round_ID, Job_ID, Score, Result_Status, Remarks)
    VALUES (p_app, p_round, v_job, p_score, p_status, p_remarks);
    SET p_id = LAST_INSERT_ID();

    COMMIT;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_issue_offer(
    IN p_app INT, IN p_ctc DECIMAL(12,2), IN p_joining DATE, OUT p_offer INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM APPLICATION WHERE Application_ID = p_app) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Application not found';
    END IF;
    IF p_ctc IS NOT NULL AND p_ctc <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Offered CTC must be greater than zero';
    END IF;
    IF p_joining IS NOT NULL AND p_joining < CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Joining date cannot be in the past';
    END IF;

    -- a NULL CTC is filled with the job CTC by the default_offer_values trigger
    INSERT INTO PLACEMENT_OFFER (Application_ID, Offered_CTC, Offer_Date, Expected_Joining_Date, Offer_Status)
    VALUES (p_app, p_ctc, CURDATE(), p_joining, 'Pending');
    SET p_offer = LAST_INSERT_ID();

    COMMIT;
END//
DELIMITER ;

DELIMITER //
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

    -- Locking reads only until the student row is locked: two simultaneous
    -- accepts by the same student are forced to run one after the other, so
    -- the one_accepted_offer trigger always sees the other one's result.
    SELECT a.Student_ID INTO v_student
    FROM PLACEMENT_OFFER o
    JOIN APPLICATION a ON a.Application_ID = o.Application_ID
    WHERE o.Offer_ID = p_offer
    FOR UPDATE;
    IF v_student IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Offer not found';
    END IF;

    SELECT Student_ID INTO v_student FROM STUDENT WHERE Student_ID = v_student FOR UPDATE;
    SELECT Offer_Status INTO v_status FROM PLACEMENT_OFFER WHERE Offer_ID = p_offer FOR UPDATE;
    IF v_status <> 'Pending' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only a pending offer can be accepted';
    END IF;

    UPDATE PLACEMENT_OFFER SET Offer_Status = 'Accepted' WHERE Offer_ID = p_offer;

    UPDATE PLACEMENT_OFFER SET Offer_Status = 'Rejected'
    WHERE Offer_Status = 'Pending'
      AND Offer_ID <> p_offer
      AND Application_ID IN (SELECT Application_ID FROM APPLICATION WHERE Student_ID = v_student);

    COMMIT;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_withdraw_application(IN p_app INT)
BEGIN
    DECLARE v_status VARCHAR(30);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT Current_Status INTO v_status FROM APPLICATION WHERE Application_ID = p_app FOR UPDATE;
    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Application not found';
    END IF;
    IF v_status = 'Withdrawn' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Application is already withdrawn';
    END IF;
    IF EXISTS (SELECT 1 FROM PLACEMENT_OFFER WHERE Application_ID = p_app AND Offer_Status = 'Accepted') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot withdraw: an offer for this application is already accepted';
    END IF;

    UPDATE PLACEMENT_OFFER SET Offer_Status = 'Revoked'
    WHERE Application_ID = p_app AND Offer_Status = 'Pending';

    UPDATE APPLICATION SET Current_Status = 'Withdrawn' WHERE Application_ID = p_app;

    COMMIT;
END//
DELIMITER ;

-- ==================================================================
-- Master-data procedures (used by the "Manage Data" tab).
-- ==================================================================

DELIMITER //
CREATE PROCEDURE sp_add_department(
    IN p_name VARCHAR(100), IN p_hod VARCHAR(100), IN p_contact VARCHAR(20), OUT p_id INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF EXISTS (SELECT 1 FROM DEPARTMENT WHERE Dept_Name = p_name) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Department already exists';
    END IF;

    INSERT INTO DEPARTMENT (Dept_Name, HOD_Name, Contact) VALUES (p_name, p_hod, p_contact);
    SET p_id = LAST_INSERT_ID();

    COMMIT;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_add_student(
    IN p_dept INT, IN p_roll VARCHAR(30), IN p_name VARCHAR(100), IN p_gender VARCHAR(20),
    IN p_email VARCHAR(100), IN p_phone VARCHAR(20), IN p_cgpa DECIMAL(4,2),
    IN p_backlogs INT, IN p_year INT, OUT p_id INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM DEPARTMENT WHERE Dept_ID = p_dept) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Department not found';
    END IF;
    IF EXISTS (SELECT 1 FROM STUDENT WHERE Roll_No = p_roll) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Roll number already exists';
    END IF;
    IF p_email IS NOT NULL AND EXISTS (SELECT 1 FROM STUDENT WHERE Email = p_email) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Email is already used by another student';
    END IF;
    IF p_cgpa < 0 OR p_cgpa > 10 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CGPA must be between 0 and 10';
    END IF;
    IF p_backlogs < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Backlogs cannot be negative';
    END IF;

    INSERT INTO STUDENT (Dept_ID, Roll_No, Name, Gender, Email, Phone_Number, CGPA, Backlogs, Passing_Year)
    VALUES (p_dept, p_roll, p_name, p_gender, p_email, p_phone, p_cgpa, IFNULL(p_backlogs, 0), p_year);
    SET p_id = LAST_INSERT_ID();

    COMMIT;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_add_skill(IN p_name VARCHAR(100), OUT p_id INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF EXISTS (SELECT 1 FROM SKILL WHERE Skill_Name = p_name) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Skill already exists';
    END IF;

    INSERT INTO SKILL (Skill_Name) VALUES (p_name);
    SET p_id = LAST_INSERT_ID();

    COMMIT;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_add_student_skill(IN p_student INT, IN p_skill INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM STUDENT WHERE Student_ID = p_student) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student not found';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM SKILL WHERE Skill_ID = p_skill) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Skill not found';
    END IF;
    IF EXISTS (SELECT 1 FROM STUDENT_SKILL WHERE Student_ID = p_student AND Skill_ID = p_skill) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student already has this skill';
    END IF;

    INSERT INTO STUDENT_SKILL (Student_ID, Skill_ID) VALUES (p_student, p_skill);

    COMMIT;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_add_company(
    IN p_name VARCHAR(150), IN p_industry VARCHAR(150), IN p_address VARCHAR(255),
    IN p_website VARCHAR(255), IN p_contact VARCHAR(20), IN p_email VARCHAR(100), OUT p_id INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF EXISTS (SELECT 1 FROM COMPANY WHERE Company_Name = p_name) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Company already exists';
    END IF;

    INSERT INTO COMPANY (Company_Name, Industry, Address, Website, Contact, Email)
    VALUES (p_name, p_industry, p_address, p_website, p_contact, p_email);
    SET p_id = LAST_INSERT_ID();

    COMMIT;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_add_oa(
    IN p_company INT, IN p_name VARCHAR(150), IN p_passing DECIMAL(5,2), OUT p_id INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM COMPANY WHERE Company_ID = p_company) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Company not found';
    END IF;
    IF EXISTS (SELECT 1 FROM ONLINE_ASSESSMENT WHERE Company_ID = p_company) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This company already has an Online Assessment';
    END IF;
    IF p_passing < 0 OR p_passing > 100 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Passing score must be between 0 and 100';
    END IF;

    INSERT INTO ONLINE_ASSESSMENT (Company_ID, OA_Name, Passing_Score)
    VALUES (p_company, p_name, p_passing);
    SET p_id = LAST_INSERT_ID();

    COMMIT;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_add_job(
    IN p_company INT, IN p_title VARCHAR(150), IN p_desc TEXT, IN p_min_cgpa DECIMAL(4,2),
    IN p_backlogs INT, IN p_ctc DECIMAL(12,2), IN p_location VARCHAR(150),
    IN p_deadline DATE, OUT p_id INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM COMPANY WHERE Company_ID = p_company) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Company not found';
    END IF;
    IF p_min_cgpa < 0 OR p_min_cgpa > 10 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Minimum CGPA must be between 0 and 10';
    END IF;
    IF p_backlogs < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Allowed backlogs cannot be negative';
    END IF;
    IF p_ctc < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CTC cannot be negative';
    END IF;

    INSERT INTO JOB_POSTING (Company_ID, Job_Title, Job_Description, Min_CGPA, Allowed_Backlogs,
                             CTC, Job_Location, Application_Deadline)
    VALUES (p_company, p_title, p_desc, p_min_cgpa, p_backlogs, p_ctc, p_location, p_deadline);
    SET p_id = LAST_INSERT_ID();

    COMMIT;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_add_job_skill(IN p_job INT, IN p_skill INT, IN p_compulsory TINYINT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM JOB_POSTING WHERE Job_ID = p_job) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Job posting not found';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM SKILL WHERE Skill_ID = p_skill) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Skill not found';
    END IF;

    -- adding a skill that is already linked just updates its compulsory flag
    INSERT INTO JOB_SKILL (Job_ID, Skill_ID, Is_Compulsory)
    VALUES (p_job, p_skill, p_compulsory)
    ON DUPLICATE KEY UPDATE Is_Compulsory = p_compulsory;

    COMMIT;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_add_round(
    IN p_job INT, IN p_name VARCHAR(100), IN p_type VARCHAR(50),
    IN p_order INT, IN p_desc TEXT, OUT p_id INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM JOB_POSTING WHERE Job_ID = p_job) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Job posting not found';
    END IF;

    -- a blank order means "after the last existing round"
    IF p_order IS NULL THEN
        SELECT IFNULL(MAX(Round_Order), 0) + 1 INTO p_order
        FROM RECRUITMENT_ROUND WHERE Job_ID = p_job;
    END IF;
    IF p_order <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Round order must be greater than zero';
    END IF;
    IF EXISTS (SELECT 1 FROM RECRUITMENT_ROUND WHERE Job_ID = p_job AND Round_Order = p_order) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This job already has a round with that order';
    END IF;

    INSERT INTO RECRUITMENT_ROUND (Job_ID, Round_Name, Round_Type, Round_Order, Description)
    VALUES (p_job, p_name, p_type, p_order, p_desc);
    SET p_id = LAST_INSERT_ID();

    COMMIT;
END//
DELIMITER ;

-- ==================================================================
-- Transaction demos (each one is rolled back, nothing is kept)
-- ==================================================================

START TRANSACTION;

INSERT INTO APPLICATION (Application_ID, Student_ID, Job_ID, Applied_Date, Current_Status)
VALUES (14, 8, 6, CURDATE(), 'Applied');

SELECT Application_ID, Student_ID, Job_ID, Current_Status FROM APPLICATION WHERE Application_ID = 14;
ROLLBACK;

START TRANSACTION;

INSERT INTO RESULT (Result_ID, Application_ID, Round_ID, Job_ID, Score, Result_Status, Remarks)
VALUES (21, 4, 3, 1, 80.00, 'Pass', NULL);

SELECT Application_ID, Current_Status FROM APPLICATION WHERE Application_ID = 4;
ROLLBACK;

START TRANSACTION;

INSERT INTO PLACEMENT_OFFER (Offer_ID, Application_ID, Offered_CTC, Offer_Date, Expected_Joining_Date, Offer_Status)
VALUES (8, 2, NULL, NULL, '2027-07-01', 'Pending');

SELECT Offer_ID, Application_ID, Offered_CTC, Offer_Date, Offer_Status FROM PLACEMENT_OFFER WHERE Offer_ID = 8;
ROLLBACK;

START TRANSACTION;

UPDATE PLACEMENT_OFFER
SET Offer_Status = 'Rejected'
WHERE Offer_Status = 'Pending'
  AND Offer_ID <> 7
  AND Application_ID IN (SELECT Application_ID FROM APPLICATION WHERE Student_ID = 5);

UPDATE PLACEMENT_OFFER SET Offer_Status = 'Accepted' WHERE Offer_ID = 7;

SELECT Offer_ID, Application_ID, Offer_Status FROM PLACEMENT_OFFER;
ROLLBACK;

START TRANSACTION;

UPDATE PLACEMENT_OFFER SET Offer_Status = 'Revoked'
WHERE Application_ID = 12 AND Offer_Status = 'Pending';

UPDATE APPLICATION SET Current_Status = 'Withdrawn' WHERE Application_ID = 12;

SELECT Application_ID, Current_Status FROM APPLICATION WHERE Application_ID = 12;
ROLLBACK;