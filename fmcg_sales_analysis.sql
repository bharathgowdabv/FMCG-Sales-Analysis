--#1. Promotion ROI: Which promotion types actually make money?
SELECT
promotion_type,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(SUM(CAST(gross_sales_usd AS FLOAT)), 2) AS gross_sales,
    ROUND(SUM(CAST(marketing_spend_usd AS FLOAT)), 2) AS marketing_spend,
    ROUND(SUM(CAST(profit_usd AS FLOAT)), 2) AS total_profit,
    ROUND(AVG(CAST(profit_margin_pct  AS FLOAT)), 2) AS avg_margin_pct,
    ROUND(AVG(CAST(discount_pct AS FLOAT)), 2) AS avg_discount_pct,

    -- Marketing ROI: profit generated per dollar of marketing spent
    ROUND(SUM(CAST(profit_usd AS FLOAT)) / NULLIF(SUM(marketing_spend_usd), 0), 2) AS marketing_roi,

    -- Are we profitable after marketing? Critical check.
    ROUND(CAST((SUM(profit_usd) - SUM(marketing_spend_usd)) AS FLOAT)/ NULLIF(SUM(gross_sales_usd), 0) * 100,2) AS net_contribution_margin_pct
FROM fmcg_sales_clean
GROUP BY promotion_type
ORDER BY marketing_roi DESC;

--#2. Channel Profitability Decomposition- Online vs Wholesale vs Modern Trade vs Distributor — different margin structures entirely.
WITH channel_metrics AS (
    SELECT
        sales_channel,
        customer_type,
        COUNT(DISTINCT order_id) AS orders,
        SUM(units_sold) AS total_units,
        SUM(gross_sales_usd) AS gross_sales,
        SUM(cogs_usd) AS total_cogs,
        SUM(logistics_cost_usd) AS total_logistics,
        SUM(marketing_spend_usd) AS total_marketing,
        SUM(profit_usd) AS total_profit,
        AVG(profit_margin_pct) AS avg_margin
    FROM fmcg_sales_clean
    GROUP BY sales_channel,customer_type
),
channel_totals AS (
    SELECT
        sales_channel,
        SUM(gross_sales) AS channel_total_sales
    FROM channel_metrics
    GROUP BY sales_channel
)
SELECT
    cm.sales_channel,
    cm.customer_type,
    cm.orders,
    ROUND(CAST(cm.gross_sales AS FLOAT), 0) AS gross_sales,
    ROUND(CAST(cm.total_cogs AS FLOAT), 0) AS cogs,
    ROUND(CAST(cm.total_logistics AS FLOAT), 0) AS logistics,
    ROUND(CAST(cm.total_marketing AS FLOAT), 0) AS marketing,
    ROUND(CAST(cm.total_profit AS FLOAT), 0) AS profit,
    ROUND(CAST(cm.avg_margin AS FLOAT), 2) AS avg_margin_pct,

-- Cost structure breakdown
    ROUND((CAST(cm.total_cogs AS FLOAT)/ NULLIF(cm.gross_sales, 0))*100, 2) AS cogs_pct_of_sales,
    ROUND((CAST(cm.total_logistics AS FLOAT)/ NULLIF(cm.gross_sales, 0))*100, 2) AS logistics_pct_of_sales,
    ROUND((CAST(cm.total_marketing AS FLOAT)/ NULLIF(cm.gross_sales, 0))*100, 2) AS marketing_pct_of_sales,

-- Share of channel within total company sales
    ROUND((CAST(cm.gross_sales AS FLOAT)/ NULLIF(ct.channel_total_sales, 0))*100, 2) AS pct_of_channel_sales
FROM channel_metrics cm
JOIN channel_totals ct 
ON cm.sales_channel = ct.sales_channel
ORDER BY cm.sales_channel, cm.total_profit DESC;

--#3. SKU Margin Ranking (Best and Worst Performers)
WITH sku_summary AS (
    SELECT
        sku,
        product_name,
        product_category,
        brand,
        SUM(units_sold) AS total_units,
        SUM(gross_sales_usd) AS gross_sales,
        SUM(profit_usd) AS total_profit,
        AVG(profit_margin_pct) AS avg_margin,
        AVG(discount_pct) AS avg_discount
    FROM fmcg_sales_clean
    GROUP BY sku,product_name,product_category,brand
),
ranked AS (
    SELECT *,
        RANK() OVER (PARTITION BY product_category ORDER BY total_profit DESC) AS profit_rank_in_category,
        AVG(total_profit) OVER (PARTITION BY product_category) AS category_avg_profit,
        AVG(avg_margin) OVER (PARTITION BY product_category) AS category_avg_margin
    FROM sku_summary
)
SELECT
    sku, product_name, product_category, brand,
    total_units,
    ROUND(CAST(gross_sales AS FLOAT), 2) AS gross_sales,
    ROUND(CAST(total_profit AS FLOAT), 2) AS total_profit,
    ROUND(CAST(avg_margin AS FLOAT), 2) AS avg_margin_pct,
    ROUND(CAST(avg_discount AS FLOAT), 2) AS avg_discount_pct,
    profit_rank_in_category,
    ROUND(CAST((avg_margin - category_avg_margin) AS FLOAT), 2) AS margin_vs_category_avg,
    CASE
        WHEN total_profit < 0 THEN 'Loss-Making'
        WHEN avg_margin < category_avg_margin - 5 THEN 'Below Benchmark'
        WHEN avg_margin > category_avg_margin + 5 THEN 'Star SKU'
        ELSE 'Normal'
    END  AS sku_flag
FROM ranked
ORDER BY product_category, profit_rank_in_category;

--#4. YoY Growth & Trend Analysis by Category
WITH yearly AS (
    SELECT
        year,
        product_category,
        SUM(gross_sales_usd) AS gross_sales,
        SUM(profit_usd) AS profit,
        AVG(profit_margin_pct) AS avg_margin,
        SUM(units_sold) AS units
    FROM fmcg_sales_clean
    GROUP BY year,product_category
),
yoy AS (
    SELECT
        y23.product_category,
        -- 2023
        y23.gross_sales AS sales_2023,
        y23.profit AS profit_2023,
        y23.avg_margin AS margin_2023,
        -- 2024
        y24.gross_sales AS sales_2024,
        y24.profit AS profit_2024,
        y24.avg_margin AS margin_2024,
        -- 2025
        y25.gross_sales AS sales_2025,
        y25.profit AS profit_2025,
        y25.avg_margin  AS margin_2025
    FROM yearly y23
    JOIN yearly y24
        ON  y23.product_category = y24.product_category
        AND y23.year = 2023
        AND y24.year = 2024
    JOIN yearly y25
        ON  y23.product_category = y25.product_category
        AND y25.year = 2025
)
SELECT
    product_category,

    -- ── 2023 baseline ───────────────────────────────────────────────
    ROUND(CAST(sales_2023 AS FLOAT), 2) AS sales_2023,
    ROUND(CAST(profit_2023 AS FLOAT), 2) AS profit_2023,
    ROUND(CAST(margin_2023 AS FLOAT), 2) AS margin_2023_pct,

    -- ── 2024 vs 2023 ────────────────────────────────────────────────
    ROUND(CAST(sales_2024 AS FLOAT), 2) AS sales_2024,
    ROUND((CAST((sales_2024 - sales_2023) AS FLOAT)/ NULLIF(sales_2023, 0))*100, 2) AS sales_growth_2023_24_pct,
    ROUND(CAST(profit_2024 AS FLOAT), 2) AS profit_2024,
    ROUND((CAST((profit_2024 - profit_2023) AS FLOAT)/ NULLIF(profit_2023, 0))*100, 2) AS profit_growth_2023_24_pct,
    ROUND(CAST(margin_2024 AS FLOAT), 2) AS margin_2024_pct,
    ROUND(CAST((margin_2024 - margin_2023) AS FLOAT), 2) AS margin_change_2023_24_pp,

    -- ── 2025 vs 2024 ────────────────────────────────────────────────
    ROUND(CAST(sales_2025 AS FLOAT), 2) AS sales_2025,
    ROUND((CAST((sales_2025 - sales_2024) AS FLOAT) / NULLIF(sales_2024, 0))*100, 2) AS sales_growth_2024_25_pct,
    ROUND(CAST(profit_2025 AS FLOAT), 2) AS profit_2025,
    ROUND((CAST((profit_2025 - profit_2024) AS FLOAT)/ NULLIF(profit_2024, 0))*100, 2) AS profit_growth_2024_25_pct,
    ROUND(CAST(margin_2025 AS FLOAT), 2) AS margin_2025_pct,
    ROUND(CAST((margin_2025 - margin_2024) AS FLOAT), 2)  AS margin_change_2024_25_pp,

    -- ── 2-year CAGR (2023 → 2025) ───────────────────────────────────
    ROUND(((POWER(CAST(sales_2025 AS FLOAT) / NULLIF(sales_2023, 0), 0.5) - 1))*100, 2) AS sales_cagr_2yr_pct,
    ROUND(((POWER(CAST(profit_2025 AS FLOAT) / NULLIF(profit_2023, 0), 0.5) - 1))*100, 2) AS profit_cagr_2yr_pct

FROM yoy
ORDER BY profit_growth_2024_25_pct DESC;

--#5.  Regional Profitability with Sales Person Performance
WITH rep_metrics AS (
    SELECT
        region,
        country,
        sales_person,
        COUNT(DISTINCT order_id) AS orders,
        SUM(gross_sales_usd) AS gross_sales,
        SUM(profit_usd) AS profit,
        AVG(profit_margin_pct) AS avg_margin,
        SUM(marketing_spend_usd) AS marketing_spend
    FROM fmcg_sales_clean
    GROUP BY region, country, sales_person
),
country_benchmarks AS (
    SELECT
        country,
        AVG(avg_margin) AS country_avg_margin,
        SUM(profit) AS country_total_profit
    FROM rep_metrics
    GROUP BY country
)
SELECT
    r.region,
    r.country,
    r.sales_person,
    r.orders,
    ROUND(CAST(r.gross_sales AS FLOAT), 2) AS gross_sales,
    ROUND(CAST(r.profit AS FLOAT), 2) AS profit,
    ROUND(CAST(r.avg_margin AS FLOAT), 2) AS avg_margin_pct,
    ROUND(CAST((r.avg_margin- b.country_avg_margin) AS FLOAT), 2) AS margin_vs_country_avg,
    ROUND((CAST(r.profit AS FLOAT)/ NULLIF(b.country_total_profit, 0))*100, 2) AS pct_of_country_profit,
    RANK() OVER (PARTITION BY r.country ORDER BY r.profit DESC) AS rank_in_country
FROM rep_metrics r
JOIN country_benchmarks b 
ON r.country = b.country
ORDER BY r.region, r.country, rank_in_country;

--#6. Discount Efficiency: Are discounts generating profitable volume?
WITH discount_bands AS (
    SELECT *,
        CASE
            WHEN discount_pct = 0 THEN 'No Discount'
            WHEN discount_pct < 10 THEN 'Low (0–10%)'
            WHEN discount_pct < 20 THEN 'Medium (10–20%)'
            ELSE 'High (20%+)'
        END AS discount_band
    FROM fmcg_sales_clean
)
SELECT
    product_category,
    discount_band,
    COUNT(DISTINCT order_id) AS orders,
    ROUND(AVG(CAST(units_sold AS FLOAT)), 2) AS avg_units_per_order,
    ROUND(AVG(CAST(gross_sales_usd AS FLOAT)), 2) AS avg_order_value,
    ROUND(AVG(CAST(profit_margin_pct AS FLOAT)), 2) AS avg_margin_pct,
    ROUND(SUM(CAST(profit_usd AS FLOAT)), 2) AS total_profit,

    -- Profit per dollar of discount given — efficiency metric
    ROUND(SUM(CAST(profit_usd AS FLOAT)) /NULLIF(SUM(gross_sales_usd * discount_pct / 100), 0), 2) AS profit_per_discount_dollar
FROM discount_bands
GROUP BY product_category, discount_band
ORDER BY product_category,
    CASE discount_band
        WHEN 'No Discount' THEN 1
        WHEN 'Low (0–10%)' THEN 2
        WHEN 'Medium (10–20%)' THEN 3
        ELSE 4
    END;