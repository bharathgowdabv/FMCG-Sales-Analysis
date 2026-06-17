TRUNCATE TABLE fmcg_sales;

BULK INSERT fmcg_sales
FROM 'E:\SQL projects\FMCG sales\Dataset\fmcg_sales_marketing_profitability_2023_2025.csv'
WITH(
FIRSTROW = 2,
FIELDTERMINATOR = ',',
TABLOCK
);