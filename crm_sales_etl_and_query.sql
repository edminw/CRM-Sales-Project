DROP SCHEMA IF EXISTS crm_computer_hardware;
CREATE SCHEMA crm_computer_hardware;
USE crm_computer_hardware;

-- Create tables in SQL to load datasets
-- Load date from csv file to mySQL infile 
CREATE TABLE accounts
(
Account VARCHAR(225),
Sector VARCHAR(225),
Year_Established INT,
Revenue FLOAT,
Employees INT,
Office_Location VARCHAR(225),
Subsidiary_Of VARCHAR(225)
);

LOAD DATA INFILE 'C:/mySQLFiles/CRM Computer Hardware/accounts.csv'
INTO TABLE accounts
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SELECT * FROM accounts;

CREATE TABLE products
(
Product VARCHAR(225),
Series VARCHAR(225),
Sales_Price INT
);

LOAD DATA INFILE 'C:/mySQLFiles/CRM Computer Hardware/products.csv'
INTO TABLE products
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SELECT * FROM products;

CREATE TABLE sales_teams
(
Sales_Agent VARCHAR(225),
Manager VARCHAR(225),
Regional_Office VARCHAR(225)
);

LOAD DATA INFILE 'C:/mySQLFiles/CRM Computer Hardware/sales_teams.csv'
INTO TABLE sales_teams
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SELECT * FROM sales_teams;

CREATE TABLE sales_pipeline
(
Opportunity_ID VARCHAR(225),
Sales_Agent VARCHAR(225),
Product VARCHAR(225),
Account VARCHAR(225), 
Deal_Stage VARCHAR(225),
Engage_Date VARCHAR(225),
Close_Date VARCHAR(225),
Close_Value VARCHAR(225)
);

LOAD DATA INFILE 'C:/mySQLFiles/CRM Computer Hardware/sales_pipeline.csv'
INTO TABLE sales_pipeline
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SELECT * FROM sales_pipeline;

-- DATA CLEANING

-- Capitalizing first letter of word 
UPDATE accounts
SET Sector = CONCAT(UCASE(LEFT(Sector, 1)), SUBSTRING(Sector, 2));
 
-- Changing spelling 
UPDATE accounts
SET Sector = 'Technology'
WHERE Sector = 'Technolgy';

-- Set empty values to null 
UPDATE sales_pipeline
SET Close_Value = NULL
WHERE Close_Value = '\r';

-- Change Close_Value column to integer
ALTER TABLE sales_pipeline 
MODIFY Close_Value INTEGER; 

-- Set all fields with empty date fields to null to process queries
UPDATE sales_pipeline
SET Engage_Date= NULL
WHERE Engage_Date = '';

UPDATE sales_pipeline
SET Close_Date = NULL
WHERE Close_Date = '';

ALTER TABLE sales_pipeline 
MODIFY Engage_Date DATE;

ALTER TABLE sales_pipeline
MODIFY Close_Date DATE;

-- Check if products not listed are in column Product
SELECT Product
FROM sales_pipeline
WHERE Product NOT IN ('GTX Basic', 'GTX Pro', 'MG Special', 'MG Advanced', 'GTX Plus Pro', 'GTX Plus Basic', 'GTK 500');

-- Delete where products are stated as "GTXPro" instead of "GTX Pro"
UPDATE sales_pipeline
SET Product = 'GTX Pro'
WHERE Product = 'GTXPro';

-- Join tables to create query that will be used for visualization tool with desired columns
SELECT
	sp.Sales_Agent,
    sp.Product,
    sp.Account,
    sp.Deal_Stage,
    sp.Engage_Date,
    sp.Close_Date,
    sp.Close_Value,
    a.Sector,
    st.Manager,
    st.Regional_Office,
    p.Series,
    p.Sales_Price
FROM sales_pipeline sp
LEFT JOIN accounts a
	ON sp.Account = a.Account
JOIN sales_teams st
	ON sp.Sales_Agent = st.Sales_Agent
JOIN products p
	ON sp.Product = p.Product;

-- QUERIES THAT HAVE BEEN USED FOR ANALYSIS WITH SQL (NOT FOR VISUALIZATION)

-- Find the current total revenue of all won deals.
SELECT SUM(Close_Value) AS total_revenue
FROM sales_pipeline;

-- Find the current total number of won deals.
SELECT COUNT(*) AS total_deals_won
FROM sales_pipeline
WHERE Deal_Stage = 'Won';

-- Find the current total conversion rate of deals.
SELECT 
    ROUND(
        100 * SUM(CASE WHEN Deal_Stage = 'Won' THEN 1 ELSE 0 END) / 
        SUM(CASE WHEN Deal_Stage IN ('Won', 'Lost') THEN 1 ELSE 0 END), 
        2
    ) AS conversion_rate
FROM sales_pipeline;

SELECT * FROM ACCOUNTS;

-- Find total number of deals for each deal stage.
SELECT COUNT(opportunity_id) AS deals, Deal_Stage
FROM sales_pipeline
GROUP BY Deal_Stage;

-- Find how many deals were won / lost each month.
SELECT DISTINCT 
    MONTH(Close_Date) AS month,
    SUM(CASE WHEN Deal_Stage = 'Won' THEN 1 ELSE 0 END) AS deals_won,
    SUM(CASE WHEN Deal_Stage = 'Lost' THEN 1 ELSE 0 END) AS deals_lost,
    SUM(CASE WHEN Deal_Stage IN ('Won', 'Lost', 'Engaging') THEN 1 ELSE 0 END) AS total_deals
FROM sales_pipeline
WHERE Close_Date IS NOT NULL
GROUP BY month
ORDER BY month ASC;

-- Find the percentage of deals lost by product by total product.
SELECT 
    product, 
    SUM(CASE WHEN Deal_Stage = 'Lost' THEN 1 ELSE 0 END) AS lost_deals, 
    COUNT(*) AS total_deals, 
    ROUND(
        100 * SUM(CASE WHEN Deal_Stage = 'Lost' THEN 1 ELSE 0 END) / COUNT(*), 
        2
    ) AS lost_percentage
FROM sales_pipeline
GROUP BY product;

-- Find the running sum total revenue at the end of each close date.
SELECT DISTINCT
    Close_Date, 
    SUM(Close_Value) OVER (ORDER BY Close_Date) AS cumulative_revenue,
    SUM(CASE WHEN Deal_Stage = 'Won' THEN 1 ELSE 0 END) OVER (ORDER BY Close_Date) AS cumulative_deals_won
FROM sales_pipeline
WHERE Close_Date IS NOT NULL
ORDER BY Close_Date;

-- Find average duration of engagement between opportunities that were won vs lost.
SELECT AVG(DATEDIFF(Close_Date, Engage_Date)) AS average_duration_of_engagement, Deal_Stage
FROM sales_pipeline
WHERE Deal_Stage = 'Won' OR Deal_Stage = 'Lost'
GROUP BY Deal_Stage;

-- Find the lead to win conversion rate for each sales representative.
SELECT 
	t.Sales_Agent AS agent,
    SUM(CASE WHEN s.Deal_Stage = 'Won' THEN 1 ELSE 0 END) AS won_deals, 
    COUNT(*) AS total_deals, 
    ROUND(100 * SUM(CASE WHEN s.Deal_Stage = 'Won' THEN 1 ELSE 0 END) / COUNT(*), 2) AS lead_to_win_conversion
FROM sales_pipeline s
JOIN sales_teams t
	ON s.Sales_Agent = t.Sales_Agent
GROUP BY agent;

-- Find the monthly sales growth by sector.
WITH MonthlySales AS (
    SELECT 
        MONTH(s.Close_Date) AS month,
        a.Sector AS sector,
        SUM(s.Close_Value) AS total_monthly_sales
    FROM sales_pipeline s
    JOIN accounts a ON s.Account = a.Account
    WHERE s.Deal_Stage = 'Won'
    GROUP BY month, sector
    ORDER BY month
),
SalesGrowth AS (
    SELECT 
        month,
        sector,
        total_monthly_sales,
        ROUND(
            (total_monthly_sales - LAG(total_monthly_sales) 
                OVER (PARTITION BY sector ORDER BY month)) * 100 	
            / NULLIF(LAG(total_monthly_sales) 
                OVER (PARTITION BY sector ORDER BY month), 0), 
            2
        ) AS sales_growth
    FROM MonthlySales
)
SELECT * 
FROM SalesGrowth
ORDER BY month, sector;

SELECT * FROM sales_pipeline;

-- Find the number of each product units sold per month
SELECT
	Month(Close_Date) AS month,
	product,
	COUNT(*) AS products_sold
FROM sales_pipeline
WHERE Deal_Stage = 'Won'
GROUP BY Product, month
ORDER BY month;

-- TOTAL REVENUE AND ENGAGEMENT (TOTAL OPPORTUNITIES) QUERIES
-- Find total revenue and total opportunities by regional office
SELECT SUM(s.Close_Value) AS total_revenue, COUNT(s.opportunity_id) AS total_opportunities, t.Regional_Office
FROM sales_pipeline s
JOIN sales_teams t
	ON s.Sales_Agent = t.Sales_Agent
GROUP BY t.Regional_Office;

-- Find total revenue and total opportunities by sector
SELECT SUM(s.Close_Value) AS total_revenue, COUNT(s.opportunity_id) AS total_opportunies, a.Sector
	FROM sales_pipeline AS s
	JOIN accounts AS a
	ON a.Account = s.Account
GROUP BY a.Sector
ORDER BY Total_Revenue DESC;

-- Find total revenue and total opportunities by product
SELECT SUM(s.Close_Value) AS total_revenue, COUNT(s.Opportunity_ID) AS total_opportunities, s.Product AS product
FROM sales_pipeline s
JOIN products AS p
	ON s.Product = p.Product
GROUP BY s.Product
ORDER BY total_revenue DESC;





