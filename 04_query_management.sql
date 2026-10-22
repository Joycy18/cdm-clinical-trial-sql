-- =====================================================
-- File    : 04_query_management.sql
-- Purpose : Auto-generate data queries from edit checks (like EDC systems do)
-- Run ONCE. Expected result: 11 new queries inserted.
-- =====================================================
USE cdm_trial_db;

INSERT INTO data_queries (subject_id, visit_id, check_code, category, description, status, opened_date)
SELECT subject_id, visit_id, check_code, category, description, 'Open', '2025-06-30'
FROM (
    SELECT vt.subject_id, vt.visit_id, 'VIT01' AS check_code, 'Vitals' AS category,
           CONCAT('Diastolic BP (', vt.diastolic_bp, ') >= systolic BP (', vt.systolic_bp, '). Please verify.') AS description
    FROM vitals vt WHERE vt.diastolic_bp >= vt.systolic_bp

    UNION ALL
    SELECT vt.subject_id, vt.visit_id, 'VIT02', 'Vitals',
           CONCAT('Heart rate ', vt.heart_rate, ' bpm is implausible. Please verify.')
    FROM vitals vt WHERE vt.heart_rate NOT BETWEEN 30 AND 220

    UNION ALL
    SELECT vt.subject_id, vt.visit_id, 'VIT03', 'Vitals',
           CONCAT('Weight ', vt.weight_kg, ' kg is implausible. Please verify.')
    FROM vitals vt WHERE vt.weight_kg < 30 OR vt.weight_kg > 250

    UNION ALL
    SELECT s.subject_id, NULL, 'SUB01', 'Subject',
           'Randomization date is before informed consent date. Please clarify.'
    FROM subjects s WHERE s.randomization_date < s.consent_date

    UNION ALL
    SELECT s.subject_id, NULL, 'SUB02', 'Subject',
           CONCAT('Age at consent (', TIMESTAMPDIFF(YEAR, s.birth_date, s.consent_date), ') outside 18-75 inclusion range.')
    FROM subjects s WHERE TIMESTAMPDIFF(YEAR, s.birth_date, s.consent_date) NOT BETWEEN 18 AND 75

    UNION ALL
    SELECT v.subject_id, v.visit_id, 'VIS01', 'Visits',
           'Visit date is before informed consent date. Please clarify.'
    FROM visits v JOIN subjects s ON s.subject_id = v.subject_id
    WHERE v.actual_date < s.consent_date

    UNION ALL
    SELECT v.subject_id, v.visit_id, 'VIS02', 'Visits',
           CONCAT(v.visit_name, ' visit overdue since ', v.planned_date, '. Please enter visit date or reason missed.')
    FROM visits v JOIN subjects s ON s.subject_id = v.subject_id
    WHERE v.actual_date IS NULL
      AND v.planned_date < DATE_SUB('2025-06-30', INTERVAL 7 DAY)
      AND s.status NOT IN ('Withdrawn','Screen Failure')

    UNION ALL
    SELECT v.subject_id, v.visit_id, 'VIS03', 'Visits',
           CONCAT(v.visit_name, ' outside protocol window by ', ABS(DATEDIFF(v.actual_date, v.planned_date)), ' days.')
    FROM visits v
    WHERE v.actual_date IS NOT NULL AND ABS(DATEDIFF(v.actual_date, v.planned_date)) > 3

    UNION ALL
    SELECT l.subject_id, l.visit_id, 'LAB01', 'Labs',
           CONCAT(l.test_name, ' result is missing. Please provide result or reason not done.')
    FROM labs l WHERE l.result_value IS NULL

    UNION ALL
    SELECT l.subject_id, l.visit_id, 'LAB03', 'Labs',
           CONCAT(l.test_name, ' collection date does not match visit date.')
    FROM labs l JOIN visits v ON v.visit_id = l.visit_id
    WHERE l.collected_date <> v.actual_date
) AS generated_queries;

-- Review all queries
SELECT dq.query_id, s.subject_code, dq.check_code, dq.category,
       dq.description, dq.status, dq.opened_date
FROM data_queries dq
JOIN subjects s ON s.subject_id = dq.subject_id
ORDER BY dq.status, dq.opened_date;

-- Simulate site response: answer one query, close another
UPDATE data_queries SET status = 'Answered'
WHERE check_code = 'VIT01' AND status = 'Open';

UPDATE data_queries SET status = 'Closed', closed_date = '2025-06-30'
WHERE check_code = 'LAB01' AND status = 'Open';
