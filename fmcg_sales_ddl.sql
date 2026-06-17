IF OBJECT_ID('fmcg_sales','U') IS NOT NULL
DROP TABLE fmcg_sales;

CREATE TABLE fmcg_sales (
    order_id              VARCHAR(30)    PRIMARY KEY,
    order_date            DATE,
    year                  INT,
    quarter               VARCHAR(5),
    month                 INT,
    month_name            VARCHAR(15),
    region                VARCHAR(30),
    country               VARCHAR(30),
    city                  VARCHAR(50),
    sales_person          VARCHAR(50),
    customer_type         VARCHAR(5),     
    sales_channel         VARCHAR(30),
    promotion_type        VARCHAR(40),
    product_category      VARCHAR(30),
    brand                 VARCHAR(30),
    product_name          VARCHAR(80),
    sku                   VARCHAR(20),
    units_sold            INT,
    unit_price_usd        NUMERIC(10,2),
    discount_pct          NUMERIC(6,2),
    gross_sales_usd       NUMERIC(12,2),
    marketing_spend_usd   NUMERIC(12,2),
    cogs_usd              NUMERIC(12,2),
    logistics_cost_usd    NUMERIC(12,2),
    net_revenue_usd       NUMERIC(12,2),
    profit_usd            NUMERIC(12,2),
    profit_margin_pct     NUMERIC(6,2)
);