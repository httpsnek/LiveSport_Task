-- Formal data quality checks comparing players_v1 vs players_v2.
-- Natural key established in 01_explore.sql: (user_id, as_of).
-- Each section maps to one item in the task brief and reports an
-- "affected rows" count.


-- ============================================================
-- Check 1: Row count differences
-- ============================================================

-- 1a. Top-level totals and net delta.
SELECT
    (SELECT COUNT(*) FROM players_v1) AS v1_rows,
    (SELECT COUNT(*) FROM players_v2) AS v2_rows,
    (SELECT COUNT(*) FROM players_v2)
        - (SELECT COUNT(*) FROM players_v1) AS net_delta;

-- 1b. Decompose the delta into "unique-key contribution" vs "extra duplicates".
SELECT
    'players_v1' AS source,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT user_id || '|' || as_of) AS unique_keys,
    COUNT(*) - COUNT(DISTINCT user_id || '|' || as_of) AS extra_duplicate_rows
FROM players_v1
UNION ALL
SELECT 'players_v2',
    COUNT(*),
    COUNT(DISTINCT user_id || '|' || as_of),
    COUNT(*) - COUNT(DISTINCT user_id || '|' || as_of)
FROM players_v2;

-- 1c. user_ids that exist only in one table.
SELECT 'only_in_v1' AS bucket, COUNT(*) AS users FROM (
    SELECT DISTINCT user_id FROM players_v1
    EXCEPT
    SELECT DISTINCT user_id FROM players_v2
)
UNION ALL
SELECT 'only_in_v2', COUNT(*) FROM (
    SELECT DISTINCT user_id FROM players_v2
    EXCEPT
    SELECT DISTINCT user_id FROM players_v1
);

-- 1d. (user_id, as_of) pairs that exist only in one table.
SELECT 'only_in_v1' AS bucket, COUNT(*) AS pairs FROM (
    SELECT DISTINCT user_id, as_of FROM players_v1
    EXCEPT
    SELECT DISTINCT user_id, as_of FROM players_v2
)
UNION ALL
SELECT 'only_in_v2', COUNT(*) FROM (
    SELECT DISTINCT user_id, as_of FROM players_v2
    EXCEPT
    SELECT DISTINCT user_id, as_of FROM players_v1
);


-- ============================================================
-- Check 2: Missing values per column
-- ============================================================

-- 2a. Raw NULL counts.
SELECT
    'players_v1' AS source,
    SUM(as_of                  IS NULL) AS as_of,
    SUM(country                IS NULL) AS country,
    SUM(tracker_id             IS NULL) AS tracker_id,
    SUM(tracker_name           IS NULL) AS tracker_name,
    SUM(user_id                IS NULL) AS user_id,
    SUM(signup_date            IS NULL) AS signup_date,
    SUM(signup_year            IS NULL) AS signup_year,
    SUM(first_deposit_date     IS NULL) AS first_deposit_date,
    SUM(first_deposit_year     IS NULL) AS first_deposit_year,
    SUM(first_deposit_amount   IS NULL) AS first_deposit_amount,
    SUM(sports_bets_turnover   IS NULL) AS sports_bets_turnover,
    SUM(sportsbook_net_revenue IS NULL) AS sportsbook_net_revenue,
    SUM(total_net_revenue      IS NULL) AS total_net_revenue,
    SUM(deposits               IS NULL) AS deposits,
    SUM(revenue                IS NULL) AS revenue,
    SUM(project_name           IS NULL) AS project_name,
    SUM(platform               IS NULL) AS platform
FROM players_v1
UNION ALL
SELECT 'players_v2',
    SUM(as_of                  IS NULL),
    SUM(country                IS NULL),
    SUM(tracker_id             IS NULL),
    SUM(tracker_name           IS NULL),
    SUM(user_id                IS NULL),
    SUM(signup_date            IS NULL),
    SUM(signup_year            IS NULL),
    SUM(first_deposit_date     IS NULL),
    SUM(first_deposit_year     IS NULL),
    SUM(first_deposit_amount   IS NULL),
    SUM(sports_bets_turnover   IS NULL),
    SUM(sportsbook_net_revenue IS NULL),
    SUM(total_net_revenue      IS NULL),
    SUM(deposits               IS NULL),
    SUM(revenue                IS NULL),
    SUM(project_name           IS NULL),
    SUM(platform               IS NULL)
FROM players_v2;

-- 2b. Logical-NULL sentinels in string dimensions
-- (empty string, the literal text "NULL", the literal text "unknown").
SELECT
    'players_v1' AS source,
    SUM(country = '')             AS country_empty,
    SUM(country = 'unknown')      AS country_unknown,
    SUM(platform = '')            AS platform_empty,
    SUM(platform = 'unknown')     AS platform_unknown,
    SUM(project_name = '')        AS project_empty,
    SUM(project_name = 'unknown') AS project_unknown
FROM players_v1
UNION ALL
SELECT 'players_v2',
    SUM(country = ''),
    SUM(country = 'unknown'),
    SUM(platform = ''),
    SUM(platform = 'unknown'),
    SUM(project_name = ''),
    SUM(project_name = 'unknown')
FROM players_v2;


-- ============================================================
-- Check 3: Duplicates
-- ============================================================

-- 3a. Duplicates by composite key (user_id, as_of).
SELECT
    'players_v1' AS source,
    COUNT(*)    AS duplicate_keys,
    SUM(dupes)  AS extra_rows
FROM (
    SELECT COUNT(*) - 1 AS dupes
    FROM players_v1
    GROUP BY user_id, as_of
    HAVING COUNT(*) > 1
)
UNION ALL
SELECT 'players_v2',
    COUNT(*), SUM(dupes)
FROM (
    SELECT COUNT(*) - 1 AS dupes
    FROM players_v2
    GROUP BY user_id, as_of
    HAVING COUNT(*) > 1
);

-- 3b. Are duplicate rows fully identical, or do they differ in other columns?
-- For each duplicate key we count distinct full-row fingerprints. If > 1 the
-- duplicate is a "soft" duplicate (same key, different values) which is worse.
WITH dup_keys AS (
    SELECT user_id, as_of
    FROM players_v2
    GROUP BY user_id, as_of
    HAVING COUNT(*) > 1
),
fingerprints AS (
    SELECT
        p.user_id, p.as_of,
        COALESCE(country,'∅')||'|'||COALESCE(tracker_id,'∅')||'|'||COALESCE(tracker_name,'∅')||'|'
        ||COALESCE(signup_date,'∅')||'|'||COALESCE(CAST(signup_year AS TEXT),'∅')||'|'
        ||COALESCE(first_deposit_date,'∅')||'|'||COALESCE(CAST(first_deposit_year AS TEXT),'∅')||'|'
        ||COALESCE(CAST(first_deposit_amount AS TEXT),'∅')||'|'
        ||COALESCE(CAST(sports_bets_turnover AS TEXT),'∅')||'|'
        ||COALESCE(CAST(sportsbook_net_revenue AS TEXT),'∅')||'|'
        ||COALESCE(CAST(total_net_revenue AS TEXT),'∅')||'|'
        ||COALESCE(CAST(deposits AS TEXT),'∅')||'|'
        ||COALESCE(CAST(revenue AS TEXT),'∅')||'|'
        ||COALESCE(project_name,'∅')||'|'||COALESCE(platform,'∅') AS fp
    FROM players_v2 p
    JOIN dup_keys USING (user_id, as_of)
)
SELECT
    'players_v2'                AS source,
    COUNT(*)                    AS total_dup_rows,
    COUNT(DISTINCT user_id || '|' || as_of) AS dup_keys,
    COUNT(DISTINCT user_id || '|' || as_of || '|' || fp) AS distinct_fingerprints,
    CASE WHEN COUNT(DISTINCT user_id || '|' || as_of || '|' || fp)
            > COUNT(DISTINCT user_id || '|' || as_of)
         THEN 'soft duplicates present' ELSE 'all duplicates are exact copies' END AS verdict
FROM fingerprints;


-- ============================================================
-- Check 4: Numeric mismatches for the same (user_id, as_of)
-- Restricted to keys that are unique in BOTH tables, so the v2 duplicates
-- from Check 3 do not blow up the join.
-- IS NOT here is SQLite's NULL-safe inequality (equivalent to IS DISTINCT FROM).
-- ============================================================

WITH
v1u AS (
    SELECT p.* FROM players_v1 p
    WHERE (p.user_id, p.as_of) IN (
        SELECT user_id, as_of FROM players_v1
        GROUP BY user_id, as_of HAVING COUNT(*) = 1
    )
),
v2u AS (
    SELECT p.* FROM players_v2 p
    WHERE (p.user_id, p.as_of) IN (
        SELECT user_id, as_of FROM players_v2
        GROUP BY user_id, as_of HAVING COUNT(*) = 1
    )
)
SELECT
    COUNT(*) AS comparable_rows,
    SUM(v1.first_deposit_amount   IS NOT v2.first_deposit_amount)   AS first_deposit_amount,
    SUM(v1.sports_bets_turnover   IS NOT v2.sports_bets_turnover)   AS sports_bets_turnover,
    SUM(v1.sportsbook_net_revenue IS NOT v2.sportsbook_net_revenue) AS sportsbook_net_revenue,
    SUM(v1.total_net_revenue      IS NOT v2.total_net_revenue)      AS total_net_revenue,
    SUM(v1.deposits               IS NOT v2.deposits)               AS deposits,
    SUM(v1.revenue                IS NOT v2.revenue)                AS revenue
FROM v1u v1
JOIN v2u v2 USING (user_id, as_of);

-- 4b. Sample of mismatching revenue values.
WITH
v1u AS (
    SELECT p.* FROM players_v1 p
    WHERE (p.user_id, p.as_of) IN (
        SELECT user_id, as_of FROM players_v1
        GROUP BY user_id, as_of HAVING COUNT(*) = 1
    )
),
v2u AS (
    SELECT p.* FROM players_v2 p
    WHERE (p.user_id, p.as_of) IN (
        SELECT user_id, as_of FROM players_v2
        GROUP BY user_id, as_of HAVING COUNT(*) = 1
    )
)
SELECT v1.user_id, v1.as_of,
       v1.revenue AS v1_revenue,
       v2.revenue AS v2_revenue,
       ROUND(v2.revenue - v1.revenue, 2) AS delta
FROM v1u v1 JOIN v2u v2 USING (user_id, as_of)
WHERE v1.revenue IS NOT v2.revenue
LIMIT 5;


-- ============================================================
-- Check 5: Date / text consistency
-- ============================================================

-- 5a. signup_year vs year(signup_date).
SELECT
    'players_v1' AS source,
    SUM(CAST(strftime('%Y', signup_date) AS INTEGER) <> signup_year) AS year_mismatch_rows,
    SUM(signup_year = 9999)                                          AS year_eq_9999
FROM players_v1
UNION ALL
SELECT 'players_v2',
    SUM(CAST(strftime('%Y', signup_date) AS INTEGER) <> signup_year),
    SUM(signup_year = 9999)
FROM players_v2;

-- 5b. first_deposit_year vs year(first_deposit_date).
-- 9999 is the legitimate "no first deposit yet" sentinel, so we report both
-- the raw mismatch and the count excluding the sentinel.
SELECT
    'players_v1' AS source,
    SUM(CAST(strftime('%Y', first_deposit_date) AS INTEGER) <> first_deposit_year) AS mismatch_raw,
    SUM(CAST(strftime('%Y', first_deposit_date) AS INTEGER) <> first_deposit_year
        AND first_deposit_year <> 9999
        AND strftime('%Y', first_deposit_date) <> '9999') AS mismatch_excl_sentinel
FROM players_v1
UNION ALL
SELECT 'players_v2',
    SUM(CAST(strftime('%Y', first_deposit_date) AS INTEGER) <> first_deposit_year),
    SUM(CAST(strftime('%Y', first_deposit_date) AS INTEGER) <> first_deposit_year
        AND first_deposit_year <> 9999
        AND strftime('%Y', first_deposit_date) <> '9999')
FROM players_v2;

-- 5c. Logical ordering: signup_date should be <= first_deposit_date
-- (excluding the 9999-12-31 sentinel).
SELECT
    'players_v1' AS source,
    SUM(signup_date > first_deposit_date
        AND first_deposit_date <> '9999-12-31') AS signup_after_first_deposit
FROM players_v1
UNION ALL
SELECT 'players_v2',
    SUM(signup_date > first_deposit_date
        AND first_deposit_date <> '9999-12-31')
FROM players_v2;


-- ============================================================
-- Check 6: tracker_id <-> tracker_name relation
-- One tracker_id should map to exactly one tracker_name (and vice versa).
-- ============================================================

-- 6a. tracker_id values that map to more than one tracker_name.
SELECT 'players_v1' AS source,
       COUNT(*) AS ambiguous_tracker_ids
FROM (
    SELECT tracker_id FROM players_v1
    GROUP BY tracker_id HAVING COUNT(DISTINCT tracker_name) > 1
)
UNION ALL
SELECT 'players_v2', COUNT(*)
FROM (
    SELECT tracker_id FROM players_v2
    GROUP BY tracker_id HAVING COUNT(DISTINCT tracker_name) > 1
);

-- 6b. tracker_name values that map to more than one tracker_id (reverse).
SELECT 'players_v1' AS source,
       COUNT(*) AS ambiguous_tracker_names
FROM (
    SELECT tracker_name FROM players_v1
    GROUP BY tracker_name HAVING COUNT(DISTINCT tracker_id) > 1
)
UNION ALL
SELECT 'players_v2', COUNT(*)
FROM (
    SELECT tracker_name FROM players_v2
    GROUP BY tracker_name HAVING COUNT(DISTINCT tracker_id) > 1
);

-- 6c. Swap hypothesis: how many distinct (user_id, as_of) keys appear in
-- both tables with v1.tracker_id = v2.tracker_name AND v1.tracker_name = v2.tracker_id?
-- Using v1u/v2u restricted to keys unique in both tables to keep the join clean.
WITH
v1u AS (
    SELECT user_id, as_of, tracker_id, tracker_name FROM players_v1
    WHERE (user_id, as_of) IN (
        SELECT user_id, as_of FROM players_v1
        GROUP BY user_id, as_of HAVING COUNT(*) = 1
    )
),
v2u AS (
    SELECT user_id, as_of, tracker_id, tracker_name FROM players_v2
    WHERE (user_id, as_of) IN (
        SELECT user_id, as_of FROM players_v2
        GROUP BY user_id, as_of HAVING COUNT(*) = 1
    )
)
SELECT
    COUNT(*) AS comparable_keys,
    SUM(v1.tracker_id = v2.tracker_name AND v1.tracker_name = v2.tracker_id) AS swapped_rows,
    SUM(v1.tracker_id = v2.tracker_id  AND v1.tracker_name = v2.tracker_name) AS aligned_rows
FROM v1u v1 JOIN v2u v2 USING (user_id, as_of);

-- 6d. Sample of the swap pattern to put in the writeup.
SELECT
    v1.user_id, v1.as_of,
    v1.tracker_id   AS v1_tracker_id,   v1.tracker_name AS v1_tracker_name,
    v2.tracker_id   AS v2_tracker_id,   v2.tracker_name AS v2_tracker_name
FROM players_v1 v1
JOIN players_v2 v2 USING (user_id, as_of)
WHERE v1.tracker_id = v2.tracker_name AND v1.tracker_name = v2.tracker_id
LIMIT 5;
