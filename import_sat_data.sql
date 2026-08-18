-- SAT Data Import Script (SQL Version)
-- Transforms and imports data from temp_csv_import table into permanent tables
-- Prerequisites: CSV must be imported to temp_csv_import table first
-- See import_sat_data.ps1 for the full import process

PRAGMA foreign_keys = ON;

-- ============================================================================
-- Create Temporary CSV Import Table (if needed)
-- ============================================================================

-- Uncomment if running this script standalone without the PowerShell wrapper:
-- CREATE TEMP TABLE temp_csv_import AS SELECT * FROM ... (load CSV data here)

-- ============================================================================
-- Upsert Schools
-- ============================================================================

INSERT OR IGNORE INTO sat_schools (sat_school_id, school_name)
SELECT DISTINCT
  COALESCE(NULLIF(TRIM(AI_NAME), ''), 'Unknown'),
  COALESCE(NULLIF(TRIM(AI_NAME), ''), 'Unknown')
FROM temp_csv_import
WHERE AI_NAME IS NOT NULL AND TRIM(AI_NAME) != '';

-- ============================================================================
-- Upsert Students and Demographics
-- ============================================================================

-- Insert or update students
-- First delete any existing records that will be re-inserted
DELETE FROM sat_student 
WHERE cb_id IN (SELECT TRIM(CB_ID) FROM temp_csv_import WHERE CB_ID IS NOT NULL AND TRIM(CB_ID) != '')
   OR student_id IN (SELECT TRIM(AI_CODE) FROM temp_csv_import WHERE AI_CODE IS NOT NULL AND TRIM(AI_CODE) != '');

-- Then insert fresh records (using GROUP BY to handle duplicates)
INSERT INTO sat_student (cb_id, student_id, last_name, first_name, middle_initial, birth_date)
SELECT
  NULLIF(TRIM(t.CB_ID), ''),
  NULLIF(TRIM(t.AI_CODE), ''),
  NULLIF(TRIM(t.NAME_LAST), ''),
  NULLIF(TRIM(t.NAME_FIRST), ''),
  NULLIF(TRIM(t.NAME_MI), ''),
  CASE WHEN TRIM(t.BIRTH_DATE) IS NULL OR TRIM(t.BIRTH_DATE) = '' THEN NULL ELSE SUBSTR(t.BIRTH_DATE, 1, 10) END
FROM temp_csv_import t
GROUP BY NULLIF(TRIM(t.CB_ID), ''), NULLIF(TRIM(t.AI_CODE), '');

-- ============================================================================
-- Upsert Demographics
-- ============================================================================

-- Upsert Demographics using DELETE + INSERT
-- First delete demographics for students we're re-importing
DELETE FROM sat_demographics
WHERE student_id IN (
  SELECT s.sat_student_id FROM sat_student s
  WHERE s.cb_id IN (SELECT TRIM(CB_ID) FROM temp_csv_import WHERE CB_ID IS NOT NULL AND TRIM(CB_ID) != '')
     OR s.student_id IN (SELECT TRIM(AI_CODE) FROM temp_csv_import WHERE AI_CODE IS NOT NULL AND TRIM(AI_CODE) != '')
);

-- Then insert fresh demographics records (only most recent per student)
INSERT INTO sat_demographics (
  student_id, gender, school_id, cohort_year, homeschooled,
  student_search_service, saa, graduation_date, phone, email,
  cuban, mexican, puerto_rican, hispanic_latino, non_hispanic_latino,
  american_indian_alaskan, asian, african_american, hawaiian_pacific_islander,
  white, other, aggregate_race_ethnicity,
  street_line1, street_line2, city, state, zip, county_fips, country_code, province, is_foreign
)
WITH most_recent_records AS (
  SELECT
    s.sat_student_id,
    t.*,
    ROW_NUMBER() OVER (
      PARTITION BY s.sat_student_id
      ORDER BY CASE WHEN TRIM(t.LATEST_SAT_DATE) IS NULL OR TRIM(t.LATEST_SAT_DATE) = '' THEN NULL ELSE SUBSTR(t.LATEST_SAT_DATE, 1, 10) END DESC NULLS LAST
    ) AS rn
  FROM temp_csv_import t
  JOIN sat_student s ON (
    (s.cb_id = NULLIF(TRIM(t.CB_ID), ''))
    OR (s.student_id = NULLIF(TRIM(t.AI_CODE), ''))
  )
)
SELECT
  mr.sat_student_id,
  NULLIF(TRIM(mr.GENDER), ''),
  COALESCE(NULLIF(TRIM(mr.AI_NAME), ''), 'Unknown'),
  CASE WHEN TRIM(mr.COHORT_YEAR) IS NULL OR TRIM(mr.COHORT_YEAR) = '' THEN NULL ELSE CAST(CAST(mr.COHORT_YEAR AS REAL) AS INTEGER) END,
  CASE WHEN LOWER(TRIM(mr.HOMESCHOOL)) IN ('1', 'true', 't', 'y', 'yes') THEN 1 WHEN LOWER(TRIM(mr.HOMESCHOOL)) IN ('0', 'false', 'f', 'n', 'no') THEN 0 ELSE NULL END,
  CASE WHEN LOWER(TRIM(mr.STUDENT_SEARCH_SERVICE)) IN ('1', 'true', 't', 'y', 'yes') THEN 1 WHEN LOWER(TRIM(mr.STUDENT_SEARCH_SERVICE)) IN ('0', 'false', 'f', 'n', 'no') THEN 0 ELSE NULL END,
  CASE WHEN LOWER(TRIM(mr.SAA)) IN ('1', 'true', 't', 'y', 'yes') THEN 1 WHEN LOWER(TRIM(mr.SAA)) IN ('0', 'false', 'f', 'n', 'no') THEN 0 ELSE NULL END,
  CASE WHEN TRIM(mr.GRAD_DATE) IS NULL OR TRIM(mr.GRAD_DATE) = '' THEN NULL ELSE SUBSTR(mr.GRAD_DATE, 1, 10) END,
  NULLIF(TRIM(mr.PHONE), ''),
  NULLIF(TRIM(mr.EMAIL), ''),
  CASE WHEN LOWER(TRIM(mr.RACE_ETH_CUBAN)) IN ('1', 'true', 't', 'y', 'yes') THEN 1 WHEN LOWER(TRIM(mr.RACE_ETH_CUBAN)) IN ('0', 'false', 'f', 'n', 'no') THEN 0 ELSE NULL END,
  CASE WHEN LOWER(TRIM(mr.RACE_ETH_MEXICAN)) IN ('1', 'true', 't', 'y', 'yes') THEN 1 WHEN LOWER(TRIM(mr.RACE_ETH_MEXICAN)) IN ('0', 'false', 'f', 'n', 'no') THEN 0 ELSE NULL END,
  CASE WHEN LOWER(TRIM(mr.RACE_ETH_PUERTORICAN)) IN ('1', 'true', 't', 'y', 'yes') THEN 1 WHEN LOWER(TRIM(mr.RACE_ETH_PUERTORICAN)) IN ('0', 'false', 'f', 'n', 'no') THEN 0 ELSE NULL END,
  CASE WHEN LOWER(TRIM(mr.RACE_ETH_HISP_LAT)) IN ('1', 'true', 't', 'y', 'yes') THEN 1 WHEN LOWER(TRIM(mr.RACE_ETH_HISP_LAT)) IN ('0', 'false', 'f', 'n', 'no') THEN 0 ELSE NULL END,
  CASE WHEN LOWER(TRIM(mr.RACE_ETH_NON_HISP_LAT)) IN ('1', 'true', 't', 'y', 'yes') THEN 1 WHEN LOWER(TRIM(mr.RACE_ETH_NON_HISP_LAT)) IN ('0', 'false', 'f', 'n', 'no') THEN 0 ELSE NULL END,
  CASE WHEN LOWER(TRIM(mr.RACE_ETH_INDIAN_ALASKAN)) IN ('1', 'true', 't', 'y', 'yes') THEN 1 WHEN LOWER(TRIM(mr.RACE_ETH_INDIAN_ALASKAN)) IN ('0', 'false', 'f', 'n', 'no') THEN 0 ELSE NULL END,
  CASE WHEN LOWER(TRIM(mr.RACE_ETH_ASIAN)) IN ('1', 'true', 't', 'y', 'yes') THEN 1 WHEN LOWER(TRIM(mr.RACE_ETH_ASIAN)) IN ('0', 'false', 'f', 'n', 'no') THEN 0 ELSE NULL END,
  CASE WHEN LOWER(TRIM(mr.RACE_ETH_AFRICANAMERICAN)) IN ('1', 'true', 't', 'y', 'yes') THEN 1 WHEN LOWER(TRIM(mr.RACE_ETH_AFRICANAMERICAN)) IN ('0', 'false', 'f', 'n', 'no') THEN 0 ELSE NULL END,
  CASE WHEN LOWER(TRIM(mr.RACE_ETH_HAWAIIAN_PI)) IN ('1', 'true', 't', 'y', 'yes') THEN 1 WHEN LOWER(TRIM(mr.RACE_ETH_HAWAIIAN_PI)) IN ('0', 'false', 'f', 'n', 'no') THEN 0 ELSE NULL END,
  CASE WHEN LOWER(TRIM(mr.RACE_ETH_WHITE)) IN ('1', 'true', 't', 'y', 'yes') THEN 1 WHEN LOWER(TRIM(mr.RACE_ETH_WHITE)) IN ('0', 'false', 'f', 'n', 'no') THEN 0 ELSE NULL END,
  CASE WHEN LOWER(TRIM(mr.RACE_ETH_OTHER)) IN ('1', 'true', 't', 'y', 'yes') THEN 1 WHEN LOWER(TRIM(mr.RACE_ETH_OTHER)) IN ('0', 'false', 'f', 'n', 'no') THEN 0 ELSE NULL END,
  NULLIF(TRIM(mr.DERIVED_AGGREGATE_RACE_ETH), ''),
  NULLIF(TRIM(mr.ADDRESS_LINE1), ''),
  NULLIF(TRIM(mr.ADDRESS_LINE2), ''),
  NULLIF(TRIM(mr.ADDRESS_CITY), ''),
  NULLIF(TRIM(mr.ADDRESS_STATE), ''),
  NULLIF(TRIM(mr.ADDRESS_ZIP), ''),
  NULLIF(TRIM(mr.ADDRESS_COUNTY), ''),
  NULLIF(TRIM(mr.ADDRESS_COUNTRY), ''),
  NULLIF(TRIM(mr.ADDRESS_PROVINCE), ''),
  CASE WHEN LOWER(TRIM(mr.FOREIGN_ADDRESS)) IN ('1', 'true', 't', 'y', 'yes') THEN 1 WHEN LOWER(TRIM(mr.FOREIGN_ADDRESS)) IN ('0', 'false', 'f', 'n', 'no') THEN 0 ELSE NULL END
FROM most_recent_records mr
WHERE mr.rn = 1;

-- ============================================================================
-- Upsert SAT Scores
-- ============================================================================

-- Upsert SAT Scores using DELETE + INSERT
-- First delete scores for students we're re-importing
DELETE FROM sat_scores
WHERE student_id IN (
  SELECT s.sat_student_id FROM sat_student s
  WHERE s.cb_id IN (SELECT TRIM(CB_ID) FROM temp_csv_import WHERE CB_ID IS NOT NULL AND TRIM(CB_ID) != '')
     OR s.student_id IN (SELECT TRIM(AI_CODE) FROM temp_csv_import WHERE AI_CODE IS NOT NULL AND TRIM(AI_CODE) != '')
);

-- Then insert fresh score records
INSERT INTO sat_scores (
  student_id, registration_number, assessment_date, is_makeup,
  grade_level, is_revised, total_score, ebrw_score, math_section_score,
  reading_test_score, writing_language_score, math_test_score,
  science_cross_score, history_socstudies_cross_score,
  words_context_subscore, command_evidence_subscore,
  expression_ideas_subscore, english_conventions_subscore,
  heart_algebra_subscore, advanced_math_subscore,
  problem_solving_data_subscore,
  essay_reading_subscore, essay_analysis_subscore, essay_writing_subscore
)
SELECT
  s.sat_student_id,
  NULLIF(TRIM(t.LATEST_REGISTRATION_NUM), ''),
  CASE WHEN TRIM(t.LATEST_SAT_DATE) IS NULL OR TRIM(t.LATEST_SAT_DATE) = '' THEN NULL ELSE SUBSTR(t.LATEST_SAT_DATE, 1, 10) END,
  CASE WHEN LOWER(TRIM(t.LATEST_MAKE_UP)) IN ('1', 'true', 't', 'y', 'yes') THEN 1 WHEN LOWER(TRIM(t.LATEST_MAKE_UP)) IN ('0', 'false', 'f', 'n', 'no') THEN 0 ELSE NULL END,
  NULLIF(TRIM(t.LATEST_SAT_GRADE), ''),
  CASE WHEN LOWER(TRIM(t.LATEST_SAT_REVISED)) IN ('1', 'true', 't', 'y', 'yes') THEN 1 WHEN LOWER(TRIM(t.LATEST_SAT_REVISED)) IN ('0', 'false', 'f', 'n', 'no') THEN 0 ELSE NULL END,
  CASE WHEN TRIM(t.LATEST_SAT_TOTAL) IS NULL OR TRIM(t.LATEST_SAT_TOTAL) = '' THEN NULL ELSE CAST(CAST(t.LATEST_SAT_TOTAL AS REAL) AS INTEGER) END,
  CASE WHEN TRIM(t.LATEST_SAT_EBRW) IS NULL OR TRIM(t.LATEST_SAT_EBRW) = '' THEN NULL ELSE CAST(CAST(t.LATEST_SAT_EBRW AS REAL) AS INTEGER) END,
  CASE WHEN TRIM(t.LATEST_SAT_MATH_SECTION) IS NULL OR TRIM(t.LATEST_SAT_MATH_SECTION) = '' THEN NULL ELSE CAST(CAST(t.LATEST_SAT_MATH_SECTION AS REAL) AS INTEGER) END,
  CASE WHEN TRIM(t.LATEST_SAT_READING) IS NULL OR TRIM(t.LATEST_SAT_READING) = '' THEN NULL ELSE CAST(CAST(t.LATEST_SAT_READING AS REAL) AS INTEGER) END,
  CASE WHEN TRIM(t.LATEST_SAT_WRIT_LANG) IS NULL OR TRIM(t.LATEST_SAT_WRIT_LANG) = '' THEN NULL ELSE CAST(CAST(t.LATEST_SAT_WRIT_LANG AS REAL) AS INTEGER) END,
  CASE WHEN TRIM(t.LATEST_SAT_MATH_TEST) IS NULL OR TRIM(t.LATEST_SAT_MATH_TEST) = '' THEN NULL ELSE CAST(t.LATEST_SAT_MATH_TEST AS REAL) END,
  CASE WHEN TRIM(t.LATEST_SAT_SCI_CROSS) IS NULL OR TRIM(t.LATEST_SAT_SCI_CROSS) = '' THEN NULL ELSE CAST(CAST(t.LATEST_SAT_SCI_CROSS AS REAL) AS INTEGER) END,
  CASE WHEN TRIM(t.LATEST_SAT_HIST_SOCST_CROSS) IS NULL OR TRIM(t.LATEST_SAT_HIST_SOCST_CROSS) = '' THEN NULL ELSE CAST(CAST(t.LATEST_SAT_HIST_SOCST_CROSS AS REAL) AS INTEGER) END,
  CASE WHEN TRIM(t.LATEST_SAT_WORDS_CONTEXT) IS NULL OR TRIM(t.LATEST_SAT_WORDS_CONTEXT) = '' THEN NULL ELSE CAST(CAST(t.LATEST_SAT_WORDS_CONTEXT AS REAL) AS INTEGER) END,
  CASE WHEN TRIM(t.LATEST_SAT_COMM_EVIDENCE) IS NULL OR TRIM(t.LATEST_SAT_COMM_EVIDENCE) = '' THEN NULL ELSE CAST(CAST(t.LATEST_SAT_COMM_EVIDENCE AS REAL) AS INTEGER) END,
  CASE WHEN TRIM(t.LATEST_SAT_EXPR_IDEAS) IS NULL OR TRIM(t.LATEST_SAT_EXPR_IDEAS) = '' THEN NULL ELSE CAST(CAST(t.LATEST_SAT_EXPR_IDEAS AS REAL) AS INTEGER) END,
  CASE WHEN TRIM(t.LATEST_SAT_ENG_CONVENT) IS NULL OR TRIM(t.LATEST_SAT_ENG_CONVENT) = '' THEN NULL ELSE CAST(CAST(t.LATEST_SAT_ENG_CONVENT AS REAL) AS INTEGER) END,
  CASE WHEN TRIM(t.LATEST_SAT_HEART_ALGEBRA) IS NULL OR TRIM(t.LATEST_SAT_HEART_ALGEBRA) = '' THEN NULL ELSE CAST(CAST(t.LATEST_SAT_HEART_ALGEBRA AS REAL) AS INTEGER) END,
  CASE WHEN TRIM(t.LATEST_SAT_ADV_MATH) IS NULL OR TRIM(t.LATEST_SAT_ADV_MATH) = '' THEN NULL ELSE CAST(CAST(t.LATEST_SAT_ADV_MATH AS REAL) AS INTEGER) END,
  CASE WHEN TRIM(t.LATEST_SAT_PROBSLV_DATA) IS NULL OR TRIM(t.LATEST_SAT_PROBSLV_DATA) = '' THEN NULL ELSE CAST(CAST(t.LATEST_SAT_PROBSLV_DATA AS REAL) AS INTEGER) END,
  CASE WHEN TRIM(t.LATEST_SAT_ESSAY_READING) IS NULL OR TRIM(t.LATEST_SAT_ESSAY_READING) = '' THEN NULL ELSE CAST(CAST(t.LATEST_SAT_ESSAY_READING AS REAL) AS INTEGER) END,
  CASE WHEN TRIM(t.LATEST_SAT_ESSAY_ANALYSIS) IS NULL OR TRIM(t.LATEST_SAT_ESSAY_ANALYSIS) = '' THEN NULL ELSE CAST(CAST(t.LATEST_SAT_ESSAY_ANALYSIS AS REAL) AS INTEGER) END,
  CASE WHEN TRIM(t.LATEST_SAT_ESSAY_WRITING) IS NULL OR TRIM(t.LATEST_SAT_ESSAY_WRITING) = '' THEN NULL ELSE CAST(CAST(t.LATEST_SAT_ESSAY_WRITING AS REAL) AS INTEGER) END
FROM temp_csv_import t
JOIN sat_student s ON (
  (s.cb_id = NULLIF(TRIM(t.CB_ID), ''))
)
WHERE COALESCE(
  CASE WHEN TRIM(t.LATEST_SAT_DATE) IS NULL OR TRIM(t.LATEST_SAT_DATE) = '' THEN NULL ELSE SUBSTR(t.LATEST_SAT_DATE, 1, 10) END,
  NULLIF(TRIM(t.LATEST_REGISTRATION_NUM), ''),
  NULLIF(TRIM(t.LATEST_SAT_TOTAL), '')
) IS NOT NULL;

-- ============================================================================
-- Cleanup
-- ============================================================================

DROP TABLE IF EXISTS temp_csv_import;
