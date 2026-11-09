USE CPSDB;

ALTER TABLE DEPARTMENT ADD CONSTRAINT uq_dept_name UNIQUE (Dept_Name);
ALTER TABLE COMPANY    ADD CONSTRAINT uq_company_name UNIQUE (Company_Name);

ALTER TABLE STUDENT
    MODIFY Backlogs INTEGER NOT NULL DEFAULT 0,
    ADD CONSTRAINT uq_student_email UNIQUE (Email),
    ADD CONSTRAINT chk_student_cgpa CHECK (CGPA BETWEEN 0 AND 10),
    ADD CONSTRAINT chk_student_backlogs CHECK (Backlogs >= 0),
    ADD CONSTRAINT chk_student_passing_year CHECK (Passing_Year BETWEEN 2000 AND 2100);

ALTER TABLE JOB_POSTING
    MODIFY Allowed_Backlogs INTEGER NOT NULL DEFAULT 0,
    ADD CONSTRAINT chk_job_min_cgpa CHECK (Min_CGPA BETWEEN 0 AND 10),
    ADD CONSTRAINT chk_job_allowed_backlogs CHECK (Allowed_Backlogs >= 0),
    ADD CONSTRAINT chk_job_ctc CHECK (CTC >= 0);

ALTER TABLE APPLICATION
    ADD CONSTRAINT chk_app_status CHECK (Current_Status IN
        ('Applied','Shortlisted','In Progress','Selected','Rejected','Withdrawn'));

ALTER TABLE RECRUITMENT_ROUND
    ADD CONSTRAINT chk_round_order CHECK (Round_Order > 0);

ALTER TABLE RESULT
    ADD CONSTRAINT chk_result_status CHECK (Result_Status IN ('Pass','Fail','Absent')),
    ADD CONSTRAINT chk_result_score  CHECK (Score >= 0);

ALTER TABLE PLACEMENT_OFFER
    ADD CONSTRAINT chk_offer_status CHECK (Offer_Status IN ('Pending','Accepted','Rejected','Revoked')),
    ADD CONSTRAINT chk_offer_ctc    CHECK (Offered_CTC > 0),
    ADD CONSTRAINT chk_offer_dates  CHECK (Expected_Joining_Date IS NULL OR Offer_Date IS NULL
                                           OR Expected_Joining_Date >= Offer_Date);