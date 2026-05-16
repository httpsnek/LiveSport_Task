-- Exploratory pass over players_v1 and players_v2.
-- Goal: figure out the shape of the data (keys, time range, cardinalities)
-- before running the formal difference checks.


-- 1. Row counts
SELECT 'players_v1' AS source, COUNT(*) AS rows FROM players_v1
UNION ALL
SELECT 'players_v2',          COUNT(*)         FROM players_v2;


-- 2. Is user_id the natural key, or is the data panel-shaped (one row per
-- user per month)? Compare total rows to distinct user_id and to distinct
-- (user_id, as_of) combinations.
SELECT
    'players_v1'                                     AS source,
    COUNT(*)                                         AS total_rows,
    COUNT(DISTINCT user_id)                          AS unique_user_ids,
    COUNT(DISTINCT user_id || '|' || as_of)          AS unique_user_month
FROM players_v1
UNION ALL
SELECT
    'players_v2',
    COUNT(*),
    COUNT(DISTINCT user_id),
    COUNT(DISTINCT user_id || '|' || as_of)
FROM players_v2;


-- 3. Time coverage: range of as_of and how many distinct months each table holds.
SELECT
    'players_v1'           AS source,
    MIN(as_of)             AS min_as_of,
    MAX(as_of)             AS max_as_of,
    COUNT(DISTINCT as_of)  AS distinct_months
FROM players_v1
UNION ALL
SELECT 'players_v2', MIN(as_of), MAX(as_of), COUNT(DISTINCT as_of) FROM players_v2;


-- 4. Cardinality of the dimension columns.
SELECT
    'players_v1'                  AS source,
    COUNT(DISTINCT country)       AS countries,
    COUNT(DISTINCT platform)      AS platforms,
    COUNT(DISTINCT project_name)  AS projects,
    COUNT(DISTINCT tracker_id)    AS tracker_ids,
    COUNT(DISTINCT tracker_name)  AS tracker_names
FROM players_v1
UNION ALL
SELECT
    'players_v2',
    COUNT(DISTINCT country),
    COUNT(DISTINCT platform),
    COUNT(DISTINCT project_name),
    COUNT(DISTINCT tracker_id),
    COUNT(DISTINCT tracker_name)
FROM players_v2;


-- 5. Per-value row counts for the low-cardinality dimensions, side by side.
WITH dim AS (
    SELECT country, 'v1' AS src FROM players_v1
    UNION ALL
    SELECT country, 'v2'        FROM players_v2
)
SELECT
    country,
    SUM(src = 'v1') AS v1_rows,
    SUM(src = 'v2') AS v2_rows
FROM dim
GROUP BY country
ORDER BY country;

WITH dim AS (
    SELECT platform, 'v1' AS src FROM players_v1
    UNION ALL
    SELECT platform, 'v2'        FROM players_v2
)
SELECT
    platform,
    SUM(src = 'v1') AS v1_rows,
    SUM(src = 'v2') AS v2_rows
FROM dim
GROUP BY platform
ORDER BY platform;

WITH dim AS (
    SELECT project_name, 'v1' AS src FROM players_v1
    UNION ALL
    SELECT project_name, 'v2'        FROM players_v2
)
SELECT
    project_name,
    SUM(src = 'v1') AS v1_rows,
    SUM(src = 'v2') AS v2_rows
FROM dim
GROUP BY project_name
ORDER BY project_name;


-- 6. Date ranges for signup_date and first_deposit_date.
SELECT
    'players_v1'             AS source,
    MIN(signup_date)         AS min_signup,
    MAX(signup_date)         AS max_signup,
    MIN(first_deposit_date)  AS min_first_deposit,
    MAX(first_deposit_date)  AS max_first_deposit
FROM players_v1
UNION ALL
SELECT 'players_v2',
    MIN(signup_date),        MAX(signup_date),
    MIN(first_deposit_date), MAX(first_deposit_date)
FROM players_v2;
