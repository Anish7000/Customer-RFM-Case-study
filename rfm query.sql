create database rfm;

Use rfm;

 CREATE TABLE rfm_data(
 InvoiceNo VARCHAR(20), 
 StockCode VARCHAR(20), 
 Description TEXT, 
 Quantity INT, 
 InvoiceDate DATETIME, 
 UnitPrice DECIMAL(10,2), 
 CustomerID INT, 
 Country VARCHAR(100)
 );
 
 -- 1. Calculate RFM Scores for Each Customer 
 SELECT 
    CustomerID,
    DATEDIFF(CURDATE(), MAX(InvoiceDate)) AS Recency,
    COUNT(DISTINCT InvoiceNo) AS Frequency,
    ROUND(SUM(Quantity * UnitPrice), 2) AS Monetary
FROM cust_rfm
GROUP BY CustomerID;


--  2. Top 10 Most Profitable Customers 
 SELECT CustomerID,
       ROUND(SUM(Quantity * UnitPrice), 2) AS TotalSpent
FROM cust_rfm
GROUP BY CustomerID
ORDER BY TotalSpent DESC
LIMIT 10;


 -- 3. Identify Churned Customers (No purchase in last 180 days)
 SELECT CustomerID,
       MAX(InvoiceDate) AS LastPurchaseDate
FROM cust_rfm
GROUP BY CustomerID
HAVING DATEDIFF(CURDATE(), LastPurchaseDate) > 180;


 -- 4. Segment Customers Based on Quantile RFM Scoring 
 WITH rfm_base AS (
    SELECT 
        CustomerID,
        DATEDIFF(CURDATE(), MAX(InvoiceDate)) AS Recency,
        COUNT(DISTINCT InvoiceNo) AS Frequency,
        SUM(Quantity * UnitPrice) AS Monetary
    FROM cust_rfm
    GROUP BY CustomerID
),
rfm_score AS (
    SELECT *,
        NTILE(4) OVER (ORDER BY Recency DESC) AS R_score,
        NTILE(4) OVER (ORDER BY Frequency) AS F_score,
        NTILE(4) OVER (ORDER BY Monetary) AS M_score
    FROM rfm_base
)
SELECT *, 
       CONCAT(R_score, F_score, M_score) AS RFM_Segment
FROM rfm_score;


-- 5. Bottom 5 Selling Products by Quantity
 SELECT 
  Description,
  SUM(Quantity) AS TotalSold
FROM cust_rfm
WHERE Quantity > 0 AND Description IS NOT NULL
GROUP BY Description
ORDER BY TotalSold ASC
LIMIT 5;


 
 -- 6.  Group Customers by RFM Score into Segments (Champions, At Risk, etc.) 
 WITH rfm_calc AS (
    SELECT 
        CustomerID,
        DATEDIFF(CURDATE(), MAX(InvoiceDate)) AS Recency,
        COUNT(DISTINCT InvoiceNo) AS Frequency,
        SUM(Quantity * UnitPrice) AS Monetary
    FROM cust_rfm
    GROUP BY CustomerID
),
rfm_scores AS (
    SELECT *,
        NTILE(4) OVER (ORDER BY Recency DESC) AS R,
        NTILE(4) OVER (ORDER BY Frequency) AS F,
        NTILE(4) OVER (ORDER BY Monetary) AS M
    FROM rfm_calc
)
SELECT *,
       CASE 
           WHEN R = 4 AND F = 4 AND M = 4 THEN 'Champions'
           WHEN R = 1 AND F <= 2 THEN 'At Risk'
           WHEN R >= 3 AND F <= 2 THEN 'Hibernating'
           WHEN R = 2 AND F = 3 THEN 'Potential Loyalists'
           ELSE 'Others'
       END AS CustomerSegment
FROM rfm_scores;

-- 7.  Top 5 products by revenue 
SELECT 
  Description,
  ROUND(SUM(Quantity * UnitPrice), 2) AS TotalRevenue
FROM cust_rfm
WHERE Description IS NOT NULL
GROUP BY Description
ORDER BY TotalRevenue DESC
LIMIT 5;


 -- 8.  Average Spend per Customer 
SELECT 
  ROUND(AVG(CustomerSpend), 2) AS AvgSpendPerCustomer
FROM (
  SELECT CustomerID, SUM(Quantity * UnitPrice) AS CustomerSpend
  FROM cust_rfm
  WHERE CustomerID IS NOT NULL
  GROUP BY CustomerID
) AS sub;


 -- 9.  Most frequent purchasing customers (Top 5 by invoice count) 

SELECT CustomerID, COUNT(DISTINCT InvoiceNo) AS OrderCount
FROM cust_rfm
WHERE CustomerID IS NOT NULL
GROUP BY CustomerID
ORDER BY OrderCount DESC
LIMIT 5;

 -- 10. Monthly revenue trend 
SELECT
  DATE_FORMAT(STR_TO_DATE(InvoiceDate, '%Y-%m-%d'), '%Y-%m') AS Month,
  ROUND(SUM(Quantity * UnitPrice), 2) AS MonthlyRevenue
FROM cust_rfm
WHERE InvoiceDate IS NOT NULL
GROUP BY DATE_FORMAT(STR_TO_DATE(InvoiceDate, '%Y-%m-%d'), '%Y-%m')
ORDER BY Month;
