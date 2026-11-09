USE CPSDB;

INSERT INTO DEPARTMENT (Dept_ID, Dept_Name, HOD_Name, Contact) VALUES
(1, 'Computer Science', 'Dr. Meenakshi Rao',  '0731-2000001'),
(2, 'Electronics',      'Dr. Suresh Kulkarni','0731-2000002'),
(3, 'Mechanical',       'Dr. Anil Deshmukh',  '0731-2000003'),
(4, 'Information Technology', 'Dr. Pooja Mehta', '0731-2000004');

INSERT INTO STUDENT (Student_ID, Dept_ID, Roll_No, Name, Gender, Email, Phone_Number, CGPA, Backlogs, Passing_Year) VALUES
(1, 1, 'CSE2022001', 'Aarav Sharma', 'Male',   'aarav.sharma@college.edu', '9000000001', 8.75, 0, 2026),
(2, 1, 'CSE2022002', 'Diya Patel',   'Female', 'diya.patel@college.edu',   '9000000002', 9.10, 0, 2026),
(3, 1, 'CSE2022003', 'Rohan Verma',  'Male',   'rohan.verma@college.edu',  '9000000003', 7.20, 1, 2026),
(4, 2, 'ECE2022001', 'Ananya Iyer',  'Female', 'ananya.iyer@college.edu',  '9000000004', 8.40, 0, 2026),
(5, 2, 'ECE2022002', 'Karan Singh',  'Male',   'karan.singh@college.edu',  '9000000005', 6.80, 2, 2026),
(6, 3, 'ME2022001',  'Meera Nair',   'Female', 'meera.nair@college.edu',   '9000000006', 7.90, 0, 2026),
(7, 4, 'IT2022001',  'Vikram Joshi', 'Male',   'vikram.joshi@college.edu', '9000000007', 8.10, 0, 2026),
(8, 4, 'IT2022002',  'Sneha Reddy',  'Female', 'sneha.reddy@college.edu',  '9000000008', 9.30, 0, 2026);

INSERT INTO SKILL (Skill_ID, Skill_Name) VALUES
(1, 'Python'),
(2, 'Java'),
(3, 'SQL'),
(4, 'Machine Learning'),
(5, 'Embedded Systems'),
(6, 'CAD/CAM');

INSERT INTO STUDENT_SKILL (Student_ID, Skill_ID) VALUES
(1, 1), (1, 3),
(2, 1), (2, 4),
(3, 3),
(4, 5),
(5, 5),
(6, 6),
(7, 2), (7, 3),
(8, 1), (8, 4);

INSERT INTO COMPANY (Company_ID, Company_Name, Industry, Address, Website, Contact, Email) VALUES
(1, 'TechNova Solutions',     'Software', 'Indore, MP',    'https://technova.example.com',    '0731-4000001', 'hr@technova.example.com'),
(2, 'Infracore Engineering',  'Manufacturing', 'Bhopal, MP','https://infracore.example.com',  '0755-4000002', 'hr@infracore.example.com'),
(3, 'DataWave Analytics',     'Data & AI', 'Bengaluru, KA','https://datawave.example.com',    '080-4000003',  'hr@datawave.example.com'),
(4, 'CircuitWorks Electronics','Electronics','Hyderabad, TS','https://circuitworks.example.com','040-4000004', 'hr@circuitworks.example.com');

INSERT INTO ONLINE_ASSESSMENT (OA_ID, Company_ID, OA_Name, Passing_Score) VALUES
(1, 1, 'TechNova Screening OA', 60.00),
(2, 2, 'Infracore Aptitude OA', 50.00),
(3, 3, 'DataWave Tech OA', 70.00),
(4, 4, 'CircuitWorks Electronics OA', 55.00);

INSERT INTO OA_RESULT (OA_ID, Student_ID, Score, Is_Passed) VALUES
(1, 1, 85.00, TRUE),
(1, 2, 90.00, TRUE),
(1, 3, 65.00, TRUE),
(1, 6, 40.00, FALSE),
(1, 7, 70.00, TRUE),
(1, 8, 88.00, TRUE),
(2, 5, 55.00, TRUE),
(2, 6, 60.00, TRUE),
(3, 2, 92.00, TRUE),
(3, 8, 95.00, TRUE),
(4, 4, 75.00, TRUE),
(4, 7, 60.00, TRUE);

INSERT INTO JOB_POSTING (Job_ID, Company_ID, Job_Title, Job_Description, Min_CGPA, Allowed_Backlogs, CTC, Job_Location, Application_Deadline) VALUES
(1, 1, 'Software Engineer',            'Backend development',          7.50, 0,  900000.00, 'Indore',    '2026-09-30'),
(2, 1, 'Associate Analyst',            'Business and data analysis',   7.00, 1,  600000.00, 'Pune',      '2026-10-10'),
(3, 2, 'Graduate Engineer Trainee',    'Plant engineering trainee',    6.50, 2,  450000.00, 'Bhopal',    '2026-10-05'),
(4, 3, 'Data Scientist',               'Machine learning models',      8.00, 0, 1200000.00, 'Bengaluru', '2026-10-20'),
(5, 4, 'Embedded Engineer',            'Firmware development',         7.50, 0,  750000.00, 'Hyderabad', '2026-10-25'),
(6, 3, 'ML Engineer (open)',           'Open posting for new drive',   8.50, 0, 1500000.00, 'Remote',    '2027-03-31');

INSERT INTO JOB_SKILL (Job_ID, Skill_ID, Is_Compulsory) VALUES
(1, 1, TRUE),
(1, 2, FALSE),
(2, 3, FALSE),
(3, 6, TRUE),
(4, 4, TRUE),
(5, 5, TRUE),
(6, 1, TRUE),
(6, 4, FALSE);

INSERT INTO APPLICATION (Application_ID, Student_ID, Job_ID, Applied_Date, Current_Status) VALUES
(1,  1, 1, '2026-09-10', 'Selected'),
(2,  2, 1, '2026-09-10', 'Selected'),
(3,  7, 1, '2026-09-12', 'Rejected'),
(4,  8, 1, '2026-09-12', 'In Progress'),
(5,  3, 2, '2026-09-20', 'Selected'),
(6,  6, 2, '2026-09-21', 'Rejected'),
(7,  5, 3, '2026-09-25', 'Selected'),
(8,  6, 3, '2026-09-25', 'Applied'),
(9,  2, 4, '2026-10-01', 'Selected'),
(10, 8, 4, '2026-10-02', 'Applied'),
(11, 4, 5, '2026-10-05', 'Selected'),
(12, 7, 5, '2026-10-06', 'Applied'),
(13, 1, 2, '2026-09-22', 'Withdrawn');

INSERT INTO RECRUITMENT_ROUND (Round_ID, Job_ID, Round_Name, Round_Type, Round_Order, Description) VALUES
(1,  1, 'Online Aptitude',     'Aptitude',  1, 'MCQ test'),
(2,  1, 'Technical Interview', 'Technical', 2, 'DSA and system basics'),
(3,  1, 'HR Interview',        'HR',        3, 'Culture fit'),
(4,  2, 'Aptitude Test',       'Aptitude',  1, 'MCQ test'),
(5,  2, 'HR Interview',        'HR',        2, 'Final discussion'),
(6,  3, 'Group Discussion',    'GD',        1, 'Topic based GD'),
(7,  3, 'HR Interview',        'HR',        2, 'Final discussion'),
(8,  4, 'Coding Test',         'Coding',    1, 'Online coding'),
(9,  4, 'Technical Interview', 'Technical', 2, 'ML and statistics'),
(10, 4, 'HR Interview',        'HR',        3, 'Final discussion'),
(11, 5, 'Written Test',        'Aptitude',  1, 'Electronics fundamentals'),
(12, 5, 'Technical Interview', 'Technical', 2, 'Embedded concepts'),
(13, 6, 'Coding Test',         'Coding',    1, 'Online coding'),
(14, 6, 'Technical Interview', 'Technical', 2, 'ML deep dive');

INSERT INTO RESULT (Result_ID, Application_ID, Round_ID, Job_ID, Score, Result_Status, Remarks) VALUES
(1,  1, 1,  1, 82.00, 'Pass', 'Good aptitude'),
(2,  1, 2,  1, 78.00, 'Pass', 'Solid fundamentals'),
(3,  1, 3,  1, 85.00, 'Pass', 'Excellent communication'),
(4,  2, 1,  1, 91.00, 'Pass', NULL),
(5,  2, 2,  1, 88.00, 'Pass', NULL),
(6,  2, 3,  1, 90.00, 'Pass', NULL),
(7,  3, 1,  1, 70.00, 'Pass', NULL),
(8,  3, 2,  1, 40.00, 'Fail', 'Weak problem solving'),
(9,  4, 1,  1, 75.00, 'Pass', NULL),
(10, 4, 2,  1, 69.00, 'Pass', 'HR round pending'),
(11, 5, 4,  2, 72.00, 'Pass', NULL),
(12, 5, 5,  2, 80.00, 'Pass', NULL),
(13, 6, 4,  2, 35.00, 'Fail', 'Below cutoff'),
(14, 7, 6,  3, 65.00, 'Pass', NULL),
(15, 7, 7,  3, 70.00, 'Pass', NULL),
(16, 9, 8,  4, 88.00, 'Pass', NULL),
(17, 9, 9,  4, 85.00, 'Pass', NULL),
(18, 9, 10, 4, 92.00, 'Pass', NULL),
(19, 11, 11, 5, 80.00, 'Pass', NULL),
(20, 11, 12, 5, 83.00, 'Pass', NULL);

INSERT INTO PLACEMENT_OFFER (Offer_ID, Application_ID, Offered_CTC, Offer_Date, Expected_Joining_Date, Offer_Status) VALUES
(1, 1,  900000.00, '2026-10-15', '2027-07-01', 'Accepted'),
(2, 2,  900000.00, '2026-10-15', '2027-07-01', 'Rejected'),
(3, 9, 1200000.00, '2026-10-28', '2027-07-15', 'Accepted'),
(4, 5,  600000.00, '2026-10-10', '2027-07-01', 'Accepted'),
(5, 7,  450000.00, '2026-10-12', '2027-08-01', 'Revoked'),
(6, 11, 750000.00, '2026-10-30', '2027-07-10', 'Pending'),
(7, 7,  480000.00, '2026-10-20', '2027-08-01', 'Pending');