-- Reporting views for SAT assessment analysis
-- Run with: sqlite3 "C:\Users\duncan_anderson\OneDrive\Documents\GitHub\DPS Sample Task\assessment_data.db" < "C:\Users\duncan_anderson\OneDrive\Documents\GitHub\DPS Sample Task\sat_reporting_views.sql"

DROP VIEW IF EXISTS vw_sat_student_latest_score;
CREATE VIEW vw_sat_student_latest_score AS
SELECT
    s.sat_student_id,
    s.cb_id,
    s.student_id AS student_code,
    s.last_name,
    s.first_name,
    s.middle_initial,
    s.birth_date,
    sc.sat_score_id,
    sc.registration_number,
    sc.assessment_date,
    sc.is_makeup,
    sc.grade_level,
    sc.is_revised,
    sc.total_score,
    sc.ebrw_score,
    sc.math_section_score,
    sc.reading_test_score,
    sc.writing_language_score,
    sc.math_test_score,
    sc.science_cross_score,
    sc.history_socstudies_cross_score,
    sc.words_context_subscore,
    sc.command_evidence_subscore,
    sc.expression_ideas_subscore,
    sc.english_conventions_subscore,
    sc.heart_algebra_subscore,
    sc.advanced_math_subscore,
    sc.problem_solving_data_subscore,
    sc.essay_reading_subscore,
    sc.essay_analysis_subscore,
    sc.essay_writing_subscore
FROM sat_student s
LEFT JOIN sat_scores sc
    ON sc.student_id = s.sat_student_id
WHERE sc.sat_score_id = (
    SELECT sc2.sat_score_id
    FROM sat_scores sc2
    WHERE sc2.student_id = s.sat_student_id
    ORDER BY sc2.assessment_date DESC, sc2.sat_score_id DESC
    LIMIT 1
);

DROP VIEW IF EXISTS vw_sat_student_profile;
CREATE VIEW vw_sat_student_profile AS
SELECT
    st.sat_student_id,
    st.cb_id,
    st.student_id AS student_code,
    st.last_name,
    st.first_name,
    st.middle_initial,
    st.birth_date,
    demo.gender,
    demo.cohort_year,
    demo.homeschooled,
    demo.student_search_service,
    demo.saa,
    demo.graduation_date,
    demo.phone,
    demo.email,
    demo.cuban,
    demo.mexican,
    demo.puerto_rican,
    demo.hispanic_latino,
    demo.non_hispanic_latino,
    demo.american_indian_alaskan,
    demo.asian,
    demo.african_american,
    demo.hawaiian_pacific_islander,
    demo.white,
    demo.other,
    demo.aggregate_race_ethnicity,
    demo.street_line1,
    demo.street_line2,
    demo.city,
    demo.state,
    demo.zip,
    demo.county_fips,
    demo.country_code,
    demo.province,
    demo.is_foreign,
    sch.school_name,
    lsc.registration_number,
    lsc.assessment_date,
    lsc.is_makeup,
    lsc.grade_level,
    lsc.is_revised,
    lsc.total_score,
    lsc.ebrw_score,
    lsc.math_section_score,
    lsc.reading_test_score,
    lsc.writing_language_score,
    lsc.math_test_score,
    lsc.science_cross_score,
    lsc.history_socstudies_cross_score,
    lsc.words_context_subscore,
    lsc.command_evidence_subscore,
    lsc.expression_ideas_subscore,
    lsc.english_conventions_subscore,
    lsc.heart_algebra_subscore,
    lsc.advanced_math_subscore,
    lsc.problem_solving_data_subscore,
    lsc.essay_reading_subscore,
    lsc.essay_analysis_subscore,
    lsc.essay_writing_subscore
FROM sat_student st
LEFT JOIN sat_demographics demo
    ON demo.student_id = st.sat_student_id
LEFT JOIN sat_schools sch
    ON sch.sat_school_id = demo.school_id
LEFT JOIN vw_sat_student_latest_score lsc
    ON lsc.sat_student_id = st.sat_student_id;

DROP VIEW IF EXISTS vw_sat_school_performance;
CREATE VIEW vw_sat_school_performance AS
SELECT
    school_name,
    cohort_year,
    COUNT(*) AS students_assessed,
    ROUND(AVG(total_score), 2) AS avg_total_score,
    ROUND(AVG(ebrw_score), 2) AS avg_ebrw_score,
    ROUND(AVG(math_section_score), 2) AS avg_math_score,
    ROUND(AVG(reading_test_score), 2) AS avg_reading_score,
    ROUND(AVG(writing_language_score), 2) AS avg_writing_language_score,
    ROUND(AVG(math_test_score), 2) AS avg_math_test_score,
    ROUND(
        100.0 * SUM(CASE WHEN total_score >= 1200 THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS pct_1200_or_above,
    ROUND(
        100.0 * SUM(CASE WHEN total_score >= 1400 THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS pct_1400_or_above,
    ROUND(
        100.0 * SUM(CASE WHEN total_score >= 1500 THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS pct_1500_or_above
FROM vw_sat_student_profile
WHERE total_score IS NOT NULL
GROUP BY school_name, cohort_year
ORDER BY cohort_year, school_name;

DROP VIEW IF EXISTS vw_sat_race_performance;
CREATE VIEW vw_sat_race_performance AS
SELECT
    CASE CAST(COALESCE(NULLIF(TRIM(aggregate_race_ethnicity), ''), '0') AS INTEGER)
        WHEN 0 THEN 'No Response'
        WHEN 1 THEN 'American Indian/Alaska Native'
        WHEN 2 THEN 'Asian'
        WHEN 3 THEN 'Black/African American'
        WHEN 4 THEN 'Hispanic/Latino'
        WHEN 8 THEN 'Native Hawaiian/Other Pacific Islander'
        WHEN 9 THEN 'White'
        WHEN 10 THEN 'Other'
        WHEN 12 THEN 'Two or more races'
        ELSE 'Unknown'
    END AS race_ethnicity,
    cohort_year,
    COUNT(*) AS students_assessed,
    ROUND(AVG(total_score), 2) AS avg_total_score,
    ROUND(AVG(ebrw_score), 2) AS avg_ebrw_score,
    ROUND(AVG(math_section_score), 2) AS avg_math_score,
    ROUND(
        100.0 * SUM(CASE WHEN total_score >= 1200 THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS pct_1200_or_above,
    ROUND(
        100.0 * SUM(CASE WHEN total_score >= 1400 THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS pct_1400_or_above
FROM vw_sat_student_profile
WHERE total_score IS NOT NULL
GROUP BY
    CASE CAST(COALESCE(NULLIF(TRIM(aggregate_race_ethnicity), ''), '0') AS INTEGER)
        WHEN 0 THEN 'No Response'
        WHEN 1 THEN 'American Indian/Alaska Native'
        WHEN 2 THEN 'Asian'
        WHEN 3 THEN 'Black/African American'
        WHEN 4 THEN 'Hispanic/Latino'
        WHEN 8 THEN 'Native Hawaiian/Other Pacific Islander'
        WHEN 9 THEN 'White'
        WHEN 10 THEN 'Other'
        WHEN 12 THEN 'Two or more races'
        ELSE 'Unknown'
    END,
    cohort_year
ORDER BY race_ethnicity, cohort_year;

DROP VIEW IF EXISTS vw_sat_gender_performance;
CREATE VIEW vw_sat_gender_performance AS
SELECT
    gender,
    cohort_year,
    COUNT(*) AS students_assessed,
    ROUND(AVG(total_score), 2) AS avg_total_score,
    ROUND(AVG(ebrw_score), 2) AS avg_ebrw_score,
    ROUND(AVG(math_section_score), 2) AS avg_math_score,
    ROUND(
        100.0 * SUM(CASE WHEN total_score >= 1200 THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS pct_1200_or_above,
    ROUND(
        100.0 * SUM(CASE WHEN total_score >= 1400 THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS pct_1400_or_above
FROM vw_sat_student_profile
WHERE total_score IS NOT NULL
GROUP BY gender, cohort_year
ORDER BY cohort_year, gender;

DROP VIEW IF EXISTS vw_sat_school_equity_gap;
CREATE VIEW vw_sat_school_equity_gap AS
WITH school_by_year AS (
    SELECT
        school_name,
        cohort_year,
        AVG(total_score) AS school_avg_total_score
    FROM vw_sat_student_profile
    WHERE total_score IS NOT NULL
    GROUP BY school_name, cohort_year
),
by_race AS (
    SELECT
        school_name,
        cohort_year,
        CASE CAST(COALESCE(NULLIF(TRIM(aggregate_race_ethnicity), ''), '0') AS INTEGER)
            WHEN 0 THEN 'No Response'
            WHEN 1 THEN 'American Indian/Alaska Native'
            WHEN 2 THEN 'Asian'
            WHEN 3 THEN 'Black/African American'
            WHEN 4 THEN 'Hispanic/Latino'
            WHEN 8 THEN 'Native Hawaiian/Other Pacific Islander'
            WHEN 9 THEN 'White'
            WHEN 10 THEN 'Other'
            WHEN 12 THEN 'Two or more races'
            ELSE 'Unknown'
        END AS race_ethnicity,
        AVG(total_score) AS race_avg_total_score,
        COUNT(*) AS students_in_group
    FROM vw_sat_student_profile
    WHERE total_score IS NOT NULL
    GROUP BY school_name, cohort_year,
        CASE CAST(COALESCE(NULLIF(TRIM(aggregate_race_ethnicity), ''), '0') AS INTEGER)
            WHEN 0 THEN 'No Response'
            WHEN 1 THEN 'American Indian/Alaska Native'
            WHEN 2 THEN 'Asian'
            WHEN 3 THEN 'Black/African American'
            WHEN 4 THEN 'Hispanic/Latino'
            WHEN 8 THEN 'Native Hawaiian/Other Pacific Islander'
            WHEN 9 THEN 'White'
            WHEN 10 THEN 'Other'
            WHEN 12 THEN 'Two or more races'
            ELSE 'Unknown'
        END
)
SELECT
    b.school_name,
    b.cohort_year,
    b.race_ethnicity,
    b.race_avg_total_score,
    s.school_avg_total_score,
    ROUND(b.race_avg_total_score - s.school_avg_total_score, 2) AS score_gap_vs_school_average,
    b.students_in_group
FROM by_race b
LEFT JOIN school_by_year s
    ON s.school_name = b.school_name
   AND s.cohort_year = b.cohort_year
ORDER BY b.cohort_year, b.school_name, b.race_ethnicity;
