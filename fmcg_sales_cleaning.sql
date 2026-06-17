--Check for duplicates order
SELECT 
order_id,
COUNT(*)
FROM fmcg_sales
GROUP BY order_id
HAVING COUNT(*) > 1

--convert date datatype to date from int
SELECT
CAST(order_date AS DATE) AS orderdate
FROM fmcg_sales

----convert year datatype to date from int
SELECT
DATEPART(YEAR, CAST(order_date AS datetime)) AS year
FROM fmcg_sales

--Quarter
SELECT DISTINCT
quarter
FROM fmcg_sales

--standardize month
SELECT
DATENAME(month, DATEADD(month, month - 1, 0)) AS MonthName
FROM fmcg_sales

--check regions
SELECT DISTINCT
region
FROM fmcg_sales

--check countries
SELECT DISTINCT
country
FROM fmcg_sales

--check cities
SELECT DISTINCT
city
FROM fmcg_sales

--null check
SELECT 
*
FROM fmcg_sales
