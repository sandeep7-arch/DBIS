USE CPSDB;

DROP PROCEDURE IF EXISTS sp_apply_for_job;
DROP PROCEDURE IF EXISTS sp_record_result;
DROP PROCEDURE IF EXISTS sp_issue_offer;
DROP PROCEDURE IF EXISTS sp_accept_offer;
DROP PROCEDURE IF EXISTS sp_withdraw_application;

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