-- =====================================================
-- Project : CARD-101 Clinical Trial Data Management
-- File    : 01_schema.sql
-- Purpose : Create database and tables
-- Note    : Data is fictional/synthetic. No real patient data.
-- =====================================================

CREATE DATABASE IF NOT EXISTS cdm_trial_db;
USE cdm_trial_db;

DROP TABLE IF EXISTS data_queries;
DROP TABLE IF EXISTS labs;
DROP TABLE IF EXISTS vitals;
DROP TABLE IF EXISTS visits;
DROP TABLE IF EXISTS subjects;
DROP TABLE IF EXISTS sites;

CREATE TABLE sites (
    site_id         INT PRIMARY KEY,
    site_name       VARCHAR(100) NOT NULL,
    country         VARCHAR(50)  NOT NULL,
    pi_name         VARCHAR(80)  NOT NULL,
    activation_date DATE         NOT NULL
);

CREATE TABLE subjects (
    subject_id         INT PRIMARY KEY,
    subject_code       VARCHAR(20) NOT NULL UNIQUE,
    site_id            INT NOT NULL,
    sex                CHAR(1) NOT NULL,
    birth_date         DATE NOT NULL,
    consent_date       DATE NOT NULL,
    randomization_date DATE NULL,
    arm                ENUM('Placebo','Drug A 10mg') NULL,
    status             ENUM('Screening','Randomized','Completed','Withdrawn','Screen Failure') NOT NULL,
    FOREIGN KEY (site_id) REFERENCES sites(site_id)
);

CREATE TABLE visits (
    visit_id     INT PRIMARY KEY,
    subject_id   INT NOT NULL,
    visit_name   ENUM('Screening','Baseline','Week 4','Week 8') NOT NULL,
    planned_date DATE NOT NULL,
    actual_date  DATE NULL,
    FOREIGN KEY (subject_id) REFERENCES subjects(subject_id)
);

-- No UNIQUE(subject_id, visit_id) on purpose, so we can simulate and detect duplicates
CREATE TABLE vitals (
    vital_id      INT AUTO_INCREMENT PRIMARY KEY,
    subject_id    INT NOT NULL,
    visit_id      INT NOT NULL,
    systolic_bp   INT,
    diastolic_bp  INT,
    heart_rate    INT,
    weight_kg     DECIMAL(5,1),
    recorded_date DATE,
    FOREIGN KEY (subject_id) REFERENCES subjects(subject_id),
    FOREIGN KEY (visit_id)   REFERENCES visits(visit_id)
);

CREATE TABLE labs (
    lab_id         INT AUTO_INCREMENT PRIMARY KEY,
    subject_id     INT NOT NULL,
    visit_id       INT NOT NULL,
    test_name      VARCHAR(40) NOT NULL,
    result_value   DECIMAL(7,2) NULL,
    unit           VARCHAR(15),
    ref_low        DECIMAL(7,2),
    ref_high       DECIMAL(7,2),
    collected_date DATE,
    FOREIGN KEY (subject_id) REFERENCES subjects(subject_id),
    FOREIGN KEY (visit_id)   REFERENCES visits(visit_id)
);

CREATE TABLE data_queries (
    query_id    INT AUTO_INCREMENT PRIMARY KEY,
    subject_id  INT NOT NULL,
    visit_id    INT NULL,
    check_code  VARCHAR(10) NOT NULL,
    category    VARCHAR(30) NOT NULL,
    description VARCHAR(255) NOT NULL,
    status      ENUM('Open','Answered','Closed') NOT NULL DEFAULT 'Open',
    opened_date DATE NOT NULL,
    closed_date DATE NULL,
    FOREIGN KEY (subject_id) REFERENCES subjects(subject_id)
);

CREATE INDEX idx_visits_subject ON visits(subject_id);
CREATE INDEX idx_vitals_visit   ON vitals(visit_id);
CREATE INDEX idx_labs_visit     ON labs(visit_id);
CREATE INDEX idx_queries_status ON data_queries(status);
