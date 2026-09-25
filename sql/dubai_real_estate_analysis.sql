/*
============================================================
Dubai Real Estate Data Analysis
============================================================

Database: PostgreSQL
Table: dubai_real_estate
Rows: 1,490

Dataset:
Synthetic Dubai real estate transaction dataset created
for data-cleaning and SQL analysis practice.

Important:
This dataset is synthetic and should NOT be interpreted
as official Dubai real estate market statistics.

Analysis Areas:
1. Data Validation
2. Transaction Activity
3. Transaction Value
4. Property Analysis
5. Geographic Analysis
6. AED per Square Meter Analysis
7. Property Size Analysis
8.Transaction-Level Analysis
9. Outlier Investigation
10. Advanced SQL Analysis

Tools:
PostgreSQL | SQL | VS Code | SQLTools

============================================================
*/
/*
============================================================
1. DATA VALIDATION
============================================================

Purpose:
Validate the structure, completeness, uniqueness, and
data quality of the cleaned synthetic dataset.

Dataset:
Synthetic Dubai real estate transaction dataset
Rows: 1,490

Note:
This dataset is synthetic and must NOT be interpreted as
official Dubai real estate market statistics.
*/


/* 1.1 Total number of records */
SELECT COUNT(*) AS total_rows
FROM dubai_real_estate;


/* 1.2 Date range and non-null dates */
SELECT
    MIN(transaction_date) AS earliest_date,
    MAX(transaction_date) AS latest_date,
    COUNT(*) AS total_rows,
    COUNT(transaction_date) AS non_null_dates
FROM dubai_real_estate;


/* 1.3 Check for duplicate Transaction IDs */
SELECT
    transaction_id,
    COUNT(*) AS duplicate_count
FROM dubai_real_estate
GROUP BY transaction_id
HAVING COUNT(*) > 1;


/* 1.4 Check for missing values */
SELECT
    COUNT(*) AS total_rows,
    COUNT(transaction_id) AS transaction_id_present,
    COUNT(transaction_date) AS transaction_date_present,
    COUNT(area) AS area_present,
    COUNT(property_type) AS property_type_present,
    COUNT(property_sub_type) AS subtype_present,
    COUNT(property_size_sqm) AS property_size_present,
    COUNT(transaction_amount_aed) AS amount_present,
    COUNT(rooms) AS rooms_present,
    COUNT(parking_spaces) AS parking_present,
    COUNT(transaction_type) AS transaction_type_present,
    COUNT(source_channel) AS source_present
FROM dubai_real_estate;
/*
============================================================
2. TRANSACTION ACTIVITY
============================================================

Purpose:
Analyze transaction activity by year and transaction type.

Note:
2026 is excluded because the dataset only contains partial
2026 data through August.
*/


/* 2.1 Transaction activity by year and transaction type */

SELECT
    EXTRACT(YEAR FROM transaction_date)::int AS year,
    transaction_type,
    COUNT(*) AS transaction_count,
    ROUND(SUM(transaction_amount_aed)::numeric, 2) AS total_transaction_value,
    ROUND(AVG(transaction_amount_aed)::numeric, 2) AS avg_transaction_value
FROM dubai_real_estate
WHERE transaction_date < '2026-01-01'
GROUP BY
    EXTRACT(YEAR FROM transaction_date),
    transaction_type
ORDER BY
    year,
    transaction_type;
/*
============================================================
3. TRANSACTION VALUE
============================================================

Purpose:
Analyze total, average, and median transaction values
by year and transaction type.

Note:
2026 is excluded because the dataset contains only partial
2026 data through August.
*/


/* 3.1 Transaction value by year and transaction type */

SELECT
    EXTRACT(YEAR FROM transaction_date)::int AS year,
    transaction_type,
    COUNT(*) AS transaction_count,
    ROUND(SUM(transaction_amount_aed)::numeric, 2) AS total_value_aed,
    ROUND(AVG(transaction_amount_aed)::numeric, 2) AS average_value_aed,
    ROUND(
        PERCENTILE_CONT(0.50)
        WITHIN GROUP (
            ORDER BY transaction_amount_aed
        )::numeric,
        2
    ) AS median_value_aed
FROM dubai_real_estate
WHERE transaction_date < '2026-01-01'
GROUP BY
    EXTRACT(YEAR FROM transaction_date),
    transaction_type
ORDER BY
    year,
    transaction_type;
/*
============================================================
4. PROPERTY ANALYSIS
============================================================

Purpose:
Analyze property-type performance over time.

Note:
2026 is excluded because the dataset contains only partial
2026 data through August.
*/

/* 4.1 Property type performance by year */

SELECT
    EXTRACT(YEAR FROM transaction_date)::int AS year,
    property_type,
    COUNT(*) AS transaction_count,
    ROUND(SUM(transaction_amount_aed)::numeric, 2) AS total_value_aed,
    ROUND(AVG(transaction_amount_aed)::numeric, 2) AS average_value_aed,
    ROUND(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (
            PARTITION BY EXTRACT(YEAR FROM transaction_date)
        ),
        2
    ) AS transaction_share_pct
FROM dubai_real_estate
WHERE transaction_date < '2026-01-01'
GROUP BY
    EXTRACT(YEAR FROM transaction_date),
    property_type
ORDER BY
    year,
    transaction_count DESC;
/* 4.2 Property type value share by year */

WITH yearly_property_value AS (
    SELECT
        EXTRACT(YEAR FROM transaction_date)::int AS year,
        property_type,
        SUM(transaction_amount_aed) AS total_value_aed
    FROM dubai_real_estate
    WHERE transaction_date < '2026-01-01'
    GROUP BY
        EXTRACT(YEAR FROM transaction_date),
        property_type
)

SELECT
    year,
    property_type,
    ROUND(total_value_aed::numeric, 2) AS total_value_aed,
    ROUND(
        total_value_aed * 100.0
        / SUM(total_value_aed) OVER (PARTITION BY year),
        2
    ) AS value_share_pct
FROM yearly_property_value
ORDER BY
    year,
    total_value_aed DESC;
/*
============================================================
5. GEOGRAPHIC ANALYSIS
============================================================

Purpose:
Analyze geographic transaction performance and changes
in leading areas over time.

Note:
2026 is excluded because the dataset contains only partial
2026 data through August.
*/

/* 5.1 Top areas by transaction value each year */

WITH yearly_area_value AS (
    SELECT
        EXTRACT(YEAR FROM transaction_date)::int AS year,
        area,
        COUNT(*) AS transaction_count,
        SUM(transaction_amount_aed) AS total_value_aed
    FROM dubai_real_estate
    WHERE transaction_date < '2026-01-01'
      AND area <> 'Unknown'
    GROUP BY
        EXTRACT(YEAR FROM transaction_date),
        area
),

ranked_areas AS (
    SELECT
        year,
        area,
        transaction_count,
        total_value_aed,
        ROW_NUMBER() OVER (
            PARTITION BY year
            ORDER BY total_value_aed DESC
        ) AS rank_by_value
    FROM yearly_area_value
)

SELECT
    year,
    area,
    transaction_count,
    ROUND(total_value_aed::numeric, 2) AS total_value_aed,
    rank_by_value
FROM ranked_areas
WHERE rank_by_value <= 5
ORDER BY
    year,
    rank_by_value;
/*
============================================================
6. AED PER SQUARE METER ANALYSIS
============================================================

Purpose:
Analyze transaction price per square meter to understand
property value relative to size.

Note:
AED per sqm is calculated as transaction amount divided
by property size.
*/

/* 6.1 Overall AED per square meter distribution */

SELECT
    COUNT(*) AS valid_transactions,
    ROUND(
        MIN(transaction_amount_aed / NULLIF(property_size_sqm, 0))::numeric,
        2
    ) AS min_aed_per_sqm,
    ROUND(
        PERCENTILE_CONT(0.25) WITHIN GROUP (
            ORDER BY transaction_amount_aed / NULLIF(property_size_sqm, 0)
        )::numeric,
        2
    ) AS p25_aed_per_sqm,
    ROUND(
        PERCENTILE_CONT(0.50) WITHIN GROUP (
            ORDER BY transaction_amount_aed / NULLIF(property_size_sqm, 0)
        )::numeric,
        2
    ) AS median_aed_per_sqm,
    ROUND(
        PERCENTILE_CONT(0.75) WITHIN GROUP (
            ORDER BY transaction_amount_aed / NULLIF(property_size_sqm, 0)
        )::numeric,
        2
    ) AS p75_aed_per_sqm,
    ROUND(
        MAX(transaction_amount_aed / NULLIF(property_size_sqm, 0))::numeric,
        2
    ) AS max_aed_per_sqm
FROM dubai_real_estate
WHERE property_size_sqm > 0
  AND transaction_amount_aed > 0;
/* 6.2 AED per square meter by property type */

SELECT
    property_type,
    COUNT(*) AS transaction_count,
    ROUND(
        SUM(transaction_amount_aed)::numeric
        / NULLIF(SUM(property_size_sqm), 0),
        2
    ) AS weighted_aed_per_sqm
FROM dubai_real_estate
WHERE property_size_sqm > 0
  AND transaction_amount_aed > 0
GROUP BY property_type
ORDER BY weighted_aed_per_sqm DESC;
/* 6.3 AED per square meter distribution by property type */

SELECT
    property_type,
    COUNT(*) AS transaction_count,
    ROUND(
        PERCENTILE_CONT(0.25) WITHIN GROUP (
            ORDER BY transaction_amount_aed / NULLIF(property_size_sqm, 0)
        )::numeric,
        2
    ) AS p25_aed_per_sqm,
    ROUND(
        PERCENTILE_CONT(0.50) WITHIN GROUP (
            ORDER BY transaction_amount_aed / NULLIF(property_size_sqm, 0)
        )::numeric,
        2
    ) AS median_aed_per_sqm,
    ROUND(
        PERCENTILE_CONT(0.75) WITHIN GROUP (
            ORDER BY transaction_amount_aed / NULLIF(property_size_sqm, 0)
        )::numeric,
        2
    ) AS p75_aed_per_sqm
FROM dubai_real_estate
WHERE property_size_sqm > 0
  AND transaction_amount_aed > 0
GROUP BY property_type
ORDER BY median_aed_per_sqm DESC;
/*
============================================================
7. PROPERTY SIZE ANALYSIS
============================================================

Purpose:
Analyze how property size relates to transaction value
and identify unusual property-size observations.

Completed analyses:
/* 7.1 Property size bands */

SELECT
    CASE
        WHEN property_size_sqm < 50 THEN 'Under 50 sqm'
        WHEN property_size_sqm < 100 THEN '50-99 sqm'
        WHEN property_size_sqm < 150 THEN '100-149 sqm'
        WHEN property_size_sqm < 250 THEN '150-249 sqm'
        WHEN property_size_sqm < 500 THEN '250-499 sqm'
        ELSE '500+ sqm'
    END AS size_band,
    COUNT(*) AS transaction_count,
    ROUND(AVG(transaction_amount_aed)::numeric, 2) AS average_transaction_value,
    ROUND(
        PERCENTILE_CONT(0.50)
        WITHIN GROUP (ORDER BY transaction_amount_aed)::numeric,
        2
    ) AS median_transaction_value
FROM dubai_real_estate
WHERE property_size_sqm > 0
GROUP BY
    CASE
        WHEN property_size_sqm < 50 THEN 'Under 50 sqm'
        WHEN property_size_sqm < 100 THEN '50-99 sqm'
        WHEN property_size_sqm < 150 THEN '100-149 sqm'
        WHEN property_size_sqm < 250 THEN '150-249 sqm'
        WHEN property_size_sqm < 500 THEN '250-499 sqm'
        ELSE '500+ sqm'
    END
ORDER BY
    MIN(property_size_sqm);
/* 7.2 Property size quartiles */

WITH size_quartiles AS (
    SELECT
        property_size_sqm,
        transaction_amount_aed,
        NTILE(4) OVER (
            ORDER BY property_size_sqm
        ) AS size_quartile
    FROM dubai_real_estate
    WHERE property_size_sqm > 0
)

SELECT
    size_quartile,
    COUNT(*) AS transaction_count,
    ROUND(MIN(property_size_sqm)::numeric, 2) AS min_size_sqm,
    ROUND(MAX(property_size_sqm)::numeric, 2) AS max_size_sqm,
    ROUND(AVG(property_size_sqm)::numeric, 2) AS average_size_sqm,
    ROUND(AVG(transaction_amount_aed)::numeric, 2) AS average_transaction_value,
    ROUND(
        SUM(transaction_amount_aed)
        / NULLIF(SUM(property_size_sqm), 0)::numeric,
        2
    ) AS weighted_aed_per_sqm
FROM size_quartiles
GROUP BY size_quartile
ORDER BY size_quartile;
/* 7.3 Property size vs transaction value correlation */

SELECT
    COUNT(*) AS valid_transactions,
    ROUND(
        CORR(property_size_sqm, transaction_amount_aed)::numeric,
        4
    ) AS size_value_correlation
FROM dubai_real_estate
WHERE property_size_sqm > 0
  AND transaction_amount_aed > 0;
/* 7.4 Extreme property-size investigation */

SELECT
    transaction_id,
    transaction_date,
    area,
    property_type,
    property_sub_type,
    property_size_sqm,
    transaction_amount_aed,
    ROUND(
        (
            transaction_amount_aed
            / NULLIF(property_size_sqm, 0)
        )::numeric,
        2
    ) AS aed_per_sqm
FROM dubai_real_estate
WHERE property_size_sqm > 500
ORDER BY property_size_sqm DESC;
/* 7.5 Property subtype size audit */

SELECT
    property_sub_type,
    COUNT(*) AS transaction_count,
    ROUND(AVG(property_size_sqm)::numeric, 2) AS average_size_sqm,
    ROUND(
        PERCENTILE_CONT(0.50)
        WITHIN GROUP (ORDER BY property_size_sqm)::numeric,
        2
    ) AS median_size_sqm,
    ROUND(MAX(property_size_sqm)::numeric, 2) AS max_size_sqm
FROM dubai_real_estate
WHERE property_sub_type IN ('studio', '2 br', '3 br')
GROUP BY property_sub_type
ORDER BY property_sub_type;

Note:
Extreme size observations were investigated but not
automatically corrected because their true values are unknown.
*/
/* 8.1 Transaction-Level Analysis */
WITH ranked_transactions AS (
    SELECT
        transaction_id,
        transaction_date,
        area,
        property_type,
        property_sub_type,
        property_size_sqm,
        transaction_amount_aed,
        transaction_type,

        ROW_NUMBER() OVER (
            PARTITION BY property_type
            ORDER BY transaction_amount_aed DESC
        ) AS rank_within_property_type

    FROM dubai_real_estate
    WHERE transaction_amount_aed > 0
)

SELECT
    transaction_id,
    transaction_date,
    area,
    property_type,
    property_sub_type,
    property_size_sqm,
    transaction_amount_aed,
    transaction_type,
    rank_within_property_type
FROM ranked_transactions
WHERE rank_within_property_type <= 5
ORDER BY
    property_type,
    rank_within_property_type;
    /* 8.2 Top transactions contribution to total value */

WITH ranked_transactions AS (
    SELECT
        transaction_id,
        transaction_date,
        area,
        property_type,
        property_sub_type,
        transaction_amount_aed,
        ROW_NUMBER() OVER (
            ORDER BY transaction_amount_aed DESC
        ) AS overall_rank
    FROM dubai_real_estate
    WHERE transaction_amount_aed > 0
),

total_value AS (
    SELECT
        SUM(transaction_amount_aed) AS total_transaction_value
    FROM dubai_real_estate
    WHERE transaction_amount_aed > 0
)

SELECT
    r.overall_rank,
    r.transaction_id,
    r.transaction_date,
    r.area,
    r.property_type,
    r.property_sub_type,
    ROUND(r.transaction_amount_aed::numeric, 2) AS transaction_amount_aed,
    ROUND(
        (
            r.transaction_amount_aed
            / NULLIF(t.total_transaction_value, 0)
            * 100
        )::numeric,
        4
    ) AS value_share_pct
FROM ranked_transactions r
CROSS JOIN total_value t
WHERE r.overall_rank <= 10
ORDER BY r.overall_rank;
/* 8.3 Cumulative contribution of top transactions */

WITH ranked_transactions AS (
    SELECT
        transaction_id,
        transaction_date,
        area,
        property_type,
        property_sub_type,
        transaction_amount_aed,
        ROW_NUMBER() OVER (
            ORDER BY transaction_amount_aed DESC
        ) AS overall_rank
    FROM dubai_real_estate
    WHERE transaction_amount_aed > 0
),

total_value AS (
    SELECT
        SUM(transaction_amount_aed) AS total_transaction_value
    FROM dubai_real_estate
    WHERE transaction_amount_aed > 0
)

SELECT
    r.overall_rank,
    r.transaction_id,
    r.area,
    r.property_type,
    r.property_sub_type,
    ROUND(r.transaction_amount_aed::numeric, 2) AS transaction_amount_aed,

    ROUND(
        SUM(r.transaction_amount_aed) OVER (
            ORDER BY r.overall_rank
        )::numeric,
        2
    ) AS cumulative_transaction_value,

    ROUND(
        (
            SUM(r.transaction_amount_aed) OVER (
                ORDER BY r.overall_rank
            )
            / NULLIF(t.total_transaction_value, 0)
            * 100
        )::numeric,
        4
    ) AS cumulative_value_share_pct

FROM ranked_transactions r
CROSS JOIN total_value t
WHERE r.overall_rank <= 20
ORDER BY r.overall_rank;
/* 8.4 Year-over-year transaction value growth by property type */

WITH yearly_property_value AS (
    SELECT
        EXTRACT(YEAR FROM transaction_date)::int AS year,
        property_type,
        SUM(transaction_amount_aed) AS total_value_aed
    FROM dubai_real_estate
    WHERE transaction_date < '2026-01-01'
    GROUP BY
        EXTRACT(YEAR FROM transaction_date),
        property_type
),

property_growth AS (
    SELECT
        year,
        property_type,
        total_value_aed,
        LAG(total_value_aed) OVER (
            PARTITION BY property_type
            ORDER BY year
        ) AS previous_year_value
    FROM yearly_property_value
)

SELECT
    year,
    property_type,
    ROUND(total_value_aed::numeric, 2) AS total_value_aed,
    ROUND(previous_year_value::numeric, 2) AS previous_year_value,
    ROUND(
        (
            (total_value_aed - previous_year_value)
            / NULLIF(previous_year_value, 0)
            * 100
        )::numeric,
        2
    ) AS yoy_growth_pct
FROM property_growth
ORDER BY
    property_type,
    year;
/* 9.1 Transaction amount outlier investigation using IQR */

WITH quartiles AS (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (
            ORDER BY transaction_amount_aed
        ) AS q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (
            ORDER BY transaction_amount_aed
        ) AS q3
    FROM dubai_real_estate
    WHERE transaction_amount_aed > 0
),

bounds AS (
    SELECT
        q1,
        q3,
        q3 - q1 AS iqr,
        q1 - 1.5 * (q3 - q1) AS lower_bound,
        q3 + 1.5 * (q3 - q1) AS upper_bound
    FROM quartiles
)

SELECT
    d.transaction_id,
    d.transaction_date,
    d.area,
    d.property_type,
    d.property_sub_type,
    ROUND(d.transaction_amount_aed::numeric, 2) AS transaction_amount_aed,
    ROUND(b.q1::numeric, 2) AS q1,
    ROUND(b.q3::numeric, 2) AS q3,
    ROUND(b.iqr::numeric, 2) AS iqr,
    ROUND(b.upper_bound::numeric, 2) AS upper_outlier_bound
FROM dubai_real_estate d
CROSS JOIN bounds b
WHERE d.transaction_amount_aed > b.upper_bound
ORDER BY d.transaction_amount_aed DESC;
/* 9.2 Outlier distribution by property type */

WITH quartiles AS (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (
            ORDER BY transaction_amount_aed
        ) AS q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (
            ORDER BY transaction_amount_aed
        ) AS q3
    FROM dubai_real_estate
    WHERE transaction_amount_aed > 0
),

bounds AS (
    SELECT
        q1,
        q3,
        q3 - q1 AS iqr,
        q3 + 1.5 * (q3 - q1) AS upper_bound
    FROM quartiles
),

outliers AS (
    SELECT
        d.property_type,
        d.transaction_amount_aed
    FROM dubai_real_estate d
    CROSS JOIN bounds b
    WHERE d.transaction_amount_aed > b.upper_bound
)

SELECT
    property_type,
    COUNT(*) AS outlier_count,
    ROUND(
        SUM(transaction_amount_aed)::numeric,
        2
    ) AS outlier_transaction_value,
    ROUND(
        AVG(transaction_amount_aed)::numeric,
        2
    ) AS average_outlier_value
FROM outliers
GROUP BY property_type
ORDER BY outlier_transaction_value DESC;
/* 10.1 Three-month rolling average of transaction value */

WITH monthly_values AS (
    SELECT
        DATE_TRUNC('month', transaction_date)::date AS month,
        SUM(transaction_amount_aed) AS total_transaction_value
    FROM dubai_real_estate
    GROUP BY DATE_TRUNC('month', transaction_date)
)

SELECT
    month,
    ROUND(total_transaction_value::numeric, 2) AS total_transaction_value,
    ROUND(
        AVG(total_transaction_value) OVER (
            ORDER BY month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        )::numeric,
        2
    ) AS rolling_3_month_avg
FROM monthly_values
ORDER BY month;