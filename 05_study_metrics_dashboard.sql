-- =====================================================
-- File    : 05_study_metrics_dashboard.sql
-- Purpose : Study-level KPIs used by Clinical Ops / CDM leads
-- =====================================================
USE cdm_trial_db;

-- 1. Enrollment summary by site
SELECT si.site_name,
       COUNT(s.subject_id)                              AS screened,
       SUM(s.randomization_date IS NOT NULL)            AS randomized,
       SUM(s.status = 'Screen Failure')                 AS screen_failures,
       SUM(s.status = 'Withdrawn')                      AS withdrawn,
       ROUND(100 * SUM(s.status = 'Screen Failure') / COUNT(s.subject_id), 1) AS screen_fail_pct
FROM sites si
LEFT JOIN subjects s ON s.site_id = si.site_id
GROUP BY si.site_id, si.site_name;

-- 2. Visit compliance by site (visits due on or before cutoff)
SELECT si.site_name,
       COUNT(*)                                          AS visits_due,
       SUM(v.actual_date IS NOT NULL)                    AS completed,
       SUM(v.actual_date IS NULL)                        AS missed,
       ROUND(100 * SUM(v.actual_date IS NOT NULL) / COUNT(*), 1) AS compliance_pct
FROM visits v
JOIN subjects s ON s.subject_id = v.subject_id
JOIN sites si   ON si.site_id   = s.site_id
WHERE v.planned_date <= '2025-06-30'
GROUP BY si.site_id, si.site_name;

-- 3. Query aging report (open and answered queries)
SELECT s.subject_code, dq.check_code, dq.status, dq.opened_date,
       DATEDIFF('2025-06-30', dq.opened_date) AS age_days,
       CASE WHEN DATEDIFF('2025-06-30', dq.opened_date) <= 14 THEN '0-14 days'
            WHEN DATEDIFF('2025-06-30', dq.opened_date) <= 30 THEN '15-30 days'
            ELSE '> 30 days (escalate)' END AS aging_bucket
FROM data_queries dq
JOIN subjects s ON s.subject_id = dq.subject_id
WHERE dq.status <> 'Closed'
ORDER BY age_days DESC;

-- 4. Site risk ranking by query rate (CTEs + window function)
WITH site_q AS (
    SELECT s.site_id,
           COUNT(*)                   AS total_queries,
           SUM(dq.status <> 'Closed') AS open_queries
    FROM data_queries dq
    JOIN subjects s ON s.subject_id = dq.subject_id
    GROUP BY s.site_id
),
site_s AS (
    SELECT site_id, COUNT(*) AS subjects FROM subjects GROUP BY site_id
)
SELECT si.site_name, ss.subjects,
       COALESCE(sq.total_queries, 0) AS total_queries,
       COALESCE(sq.open_queries, 0)  AS open_queries,
       ROUND(COALESCE(sq.total_queries, 0) / ss.subjects, 2) AS queries_per_subject,
       RANK() OVER (ORDER BY COALESCE(sq.total_queries, 0) / ss.subjects DESC) AS risk_rank
FROM sites si
JOIN site_s ss       ON ss.site_id = si.site_id
LEFT JOIN site_q sq  ON sq.site_id = si.site_id;

-- 5. Query volume by category
SELECT category, COUNT(*) AS total,
       SUM(status = 'Open')     AS open_q,
       SUM(status = 'Answered') AS answered,
       SUM(status = 'Closed')   AS closed
FROM data_queries
GROUP BY category
ORDER BY total DESC;

-- 6. Systolic BP: Baseline vs Week 8 by treatment arm
--    (illustrative only, n is tiny, no statistical inference)
SELECT s.arm,
       COUNT(*)                                  AS n,
       ROUND(AVG(b.systolic_bp), 1)              AS baseline_sbp,
       ROUND(AVG(w.systolic_bp), 1)              AS week8_sbp,
       ROUND(AVG(w.systolic_bp - b.systolic_bp), 1) AS mean_change
FROM subjects s
JOIN visits vb ON vb.subject_id = s.subject_id AND vb.visit_name = 'Baseline'
JOIN vitals b  ON b.visit_id    = vb.visit_id
JOIN visits vw ON vw.subject_id = s.subject_id AND vw.visit_name = 'Week 8'
JOIN vitals w  ON w.visit_id    = vw.visit_id
WHERE s.arm IS NOT NULL
GROUP BY s.arm;

-- 7. Database-lock readiness view: is each subject "clean"?
CREATE OR REPLACE VIEW vw_subject_clean_status AS
SELECT s.subject_code, si.site_name, s.status,
       COALESCE(q.open_q, 0)  AS open_queries,
       COALESCE(m.missed, 0)  AS missed_visits,
       CASE WHEN COALESCE(q.open_q,0) = 0 AND COALESCE(m.missed,0) = 0
            THEN 'CLEAN' ELSE 'NOT CLEAN' END AS clean_status
FROM subjects s
JOIN sites si ON si.site_id = s.site_id
LEFT JOIN (SELECT subject_id, COUNT(*) AS open_q
           FROM data_queries WHERE status <> 'Closed'
           GROUP BY subject_id) q ON q.subject_id = s.subject_id
LEFT JOIN (SELECT subject_id, COUNT(*) AS missed
           FROM visits
           WHERE actual_date IS NULL AND planned_date < '2025-06-30'
           GROUP BY subject_id) m ON m.subject_id = s.subject_id;

SELECT * FROM vw_subject_clean_status ORDER BY clean_status, site_name;

-- 8. Overall clean-patient percentage
SELECT ROUND(100 * SUM(clean_status = 'CLEAN') / COUNT(*), 1) AS pct_clean_subjects
FROM vw_subject_clean_status
WHERE status NOT IN ('Screen Failure');
