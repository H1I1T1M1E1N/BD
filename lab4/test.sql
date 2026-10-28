SELECT 'SELECT * FROM ' || table_name || ';' AS query_to_execute
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_type = 'BASE TABLE'
ORDER BY table_name;

SELECT * FROM applicant;
SELECT * FROM company;
SELECT * FROM department;
SELECT * FROM employer_tariff;
SELECT * FROM interview;
SELECT * FROM interview_participant;
SELECT * FROM job_offer;
SELECT * FROM recruiter;
SELECT * FROM recruiter_authority;
SELECT * FROM response;
SELECT * FROM response_stage;
SELECT * FROM resume;
SELECT * FROM resume_skill;
SELECT * FROM resume_version;
SELECT * FROM skill;
SELECT * FROM vacancy;
SELECT * FROM vacancy_skill_requirement;
SELECT * FROM vacancy_version;