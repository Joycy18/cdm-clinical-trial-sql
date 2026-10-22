-- =====================================================
-- File    : 03_data_validation_checks.sql
-- Purpose : Edit checks / data cleaning listings (CDM core skill)
-- =====================================================
USE cdm_trial_db;

-- CHK01: Diastolic BP >= Systolic BP (physiologically impossible)
SELECT s.subject_code, v.visit_name, vt.systolic_bp, vt.diastolic_bp
FROM vitals vt
JOIN subjects s ON s.subject_id = vt.subject_id
JOIN visits v   ON v.visit_id   = vt.visit_id
WHERE vt.diastolic_bp >= vt.systolic_bp;

-- CHK02: Heart rate outside plausible range (30-220 bpm)
SELECT s.subject_code, v.visit_name, vt.heart_rate
FROM vitals vt
JOIN subjects s ON s.subject_id = vt.subject_id
JOIN visits v   ON v.visit_id   = vt.visit_id
WHERE vt.heart_rate NOT BETWEEN 30 AND 220;

-- CHK03: Implausible weight (<30 kg or >250 kg)
SELECT s.subject_code, v.visit_name, vt.weight_kg
FROM vitals vt
JOIN subjects s ON s.subject_id = vt.subject_id
JOIN visits v   ON v.visit_id   = vt.visit_id
WHERE vt.weight_kg < 30 OR vt.weight_kg > 250;

-- CHK04: Randomized BEFORE informed consent (major GCP finding)
SELECT subject_code, consent_date, randomization_date
FROM subjects
WHERE randomization_date < consent_date;

-- CHK05: Visit performed BEFORE informed consent (major GCP finding)
SELECT s.subject_code, v.visit_name, s.consent_date, v.actual_date
FROM visits v
JOIN subjects s ON s.subject_id = v.subject_id
WHERE v.actual_date < s.consent_date;

-- CHK06: Age at consent outside inclusion criteria (18-75)
SELECT subject_code, birth_date, consent_date,
       TIMESTAMPDIFF(YEAR, birth_date, consent_date) AS age_at_consent
FROM subjects
WHERE TIMESTAMPDIFF(YEAR, birth_date, consent_date) NOT BETWEEN 18 AND 75;

-- CHK07: Missed visits (overdue by > 7 days at cutoff 2025-06-30)
SELECT s.subject_code, si.site_name, v.visit_name, v.planned_date,
       DATEDIFF('2025-06-30', v.planned_date) AS days_overdue
FROM visits v
JOIN subjects s ON s.subject_id = v.subject_id
JOIN sites si   ON si.site_id   = s.site_id
WHERE v.actual_date IS NULL
  AND v.planned_date < DATE_SUB('2025-06-30', INTERVAL 7 DAY)
  AND s.status NOT IN ('Withdrawn','Screen Failure')
ORDER BY days_overdue DESC;

-- CHK08: Visit window deviation (protocol window = +/- 3 days)
SELECT s.subject_code, v.visit_name, v.planned_date, v.actual_date,
       DATEDIFF(v.actual_date, v.planned_date) AS deviation_days
FROM visits v
JOIN subjects s ON s.subject_id = v.subject_id
WHERE v.actual_date IS NOT NULL
  AND ABS(DATEDIFF(v.actual_date, v.planned_date)) > 3;

-- CHK09: Missing lab results
SELECT s.subject_code, v.visit_name, l.test_name
FROM labs l
JOIN subjects s ON s.subject_id = l.subject_id
JOIN visits v   ON v.visit_id   = l.visit_id
WHERE l.result_value IS NULL;

-- CHK10: Lab collection date differs from visit date
SELECT s.subject_code, v.visit_name, v.actual_date AS visit_date,
       l.collected_date, l.test_name
FROM labs l
JOIN subjects s ON s.subject_id = l.subject_id
JOIN visits v   ON v.visit_id   = l.visit_id
WHERE l.collected_date <> v.actual_date;

-- CHK11: Duplicate vital sign records
SELECT subject_id, visit_id, COUNT(*) AS record_count
FROM vitals
GROUP BY subject_id, visit_id
HAVING COUNT(*) > 1;

-- CHK12: Out-of-range labs with severity vs upper limit of normal (ULN)
SELECT s.subject_code, v.visit_name, l.test_name, l.result_value, l.unit,
       CASE WHEN l.result_value < l.ref_low  THEN 'LOW'
            WHEN l.result_value > l.ref_high THEN 'HIGH' END AS flag,
       ROUND(l.result_value / l.ref_high, 2) AS x_uln,
       CASE WHEN l.test_name = 'ALT' AND l.result_value > 2 * l.ref_high
            THEN 'SAFETY REVIEW (>2x ULN)' ELSE 'Review' END AS action
FROM labs l
JOIN subjects s ON s.subject_id = l.subject_id
JOIN visits v   ON v.visit_id   = l.visit_id
WHERE l.result_value NOT BETWEEN l.ref_low AND l.ref_high;
