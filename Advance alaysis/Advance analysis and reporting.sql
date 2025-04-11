-- Advance data project
USE DataWarehouseAnalytics;
GO

-- 1) change over time analysis (trends)
SELECT 
YEAR(order_date) order_yearly,
MONTH(order_date) order_Monthly,
SUM(sales_amount) Total_amount,
COUNT(customer_key) Toltal_Customers,
SUM(quantity) Total_Quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY YEAR(order_date), MONTH(order_date);

SELECT 
DATETRUNC(MONTH, order_date) Order_Date,
SUM(sales_amount) Total_amount,
COUNT(customer_key) Toltal_Customers,
SUM(quantity) Total_Quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH, order_date)
ORDER BY DATETRUNC(MONTH, order_date);

SELECT 
FORMAT(order_date, 'yyyy-MM') Order_Date,
SUM(sales_amount) Total_amount,
COUNT(customer_key) Toltal_Customers,
SUM(quantity) Total_Quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY FORMAT(order_date, 'yyyy-MM') 
ORDER BY FORMAT(order_date, 'yyyy-MM');

-- 2) CUMILATIVE ANALYSIS
-- calculate the total sales per month and the running total of sales over time
SELECT 
Order_Date,
Total_Amount,
SUM(Total_Amount) OVER(ORDER BY Order_Date) AS running_total_sales,
AVG(avg_price) OVER(ORDER BY Order_Date) AS Moving_Average_sales
FROM
(
SELECT 
DATETRUNC(YEAR, order_date) Order_Date,
SUM(sales_amount) Total_Amount,
AVG(price) avg_price
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(YEAR, order_date)
) t


-- 3) PERFORMANCE ANALYSIS
-- Analayse the yearly performanace of products by comparing each product sales to both its average sales performance and previous years sale
WITH yearly_product_sale AS (
		SELECT 
		YEAR(F.order_date) Orderly_year,
		P.product_name,
		SUM(F.sales_amount) Current_sales
		FROM
		gold.fact_sales F	
		LEFT JOIN gold.dim_products P
			ON F.product_key = P.product_key
		WHERE F.order_date IS NOT NULL
		GROUP BY YEAR(F.order_date), P.product_name
	)	
SELECT 
Orderly_year,
product_name,
Current_sales,
AVG(Current_sales) OVER(PARTITION BY product_name) Moving_Avg,
Current_sales - AVG(Current_sales) OVER(PARTITION BY product_name) Difference_Avg,
CASE 
	WHEN Current_sales - AVG(Current_sales) OVER(PARTITION BY product_name) < 0 THEN 'Below avg'
	WHEN Current_sales - AVG(Current_sales) OVER(PARTITION BY product_name) > 0 THEN 'Above avg'
	ELSE 'Avg'
END Avg_Change,
LAG(Current_sales) OVER(PARTITION BY product_name ORDER BY Orderly_year) Previous_Year_Sales,
Current_sales - LAG(Current_sales) OVER(PARTITION BY product_name ORDER BY Orderly_year) Difference_curr_AND_prev,
CASE 
	WHEN Current_sales - LAG(Current_sales) OVER(PARTITION BY product_name ORDER BY Orderly_year) < 0 THEN 'Increase'
	WHEN Current_sales - LAG(Current_sales) OVER(PARTITION BY product_name ORDER BY Orderly_year) > 0 THEN 'Decrease'
	ELSE 'No change'
END Differnce_Change
FROM
yearly_product_sale
ORDER BY product_name, Orderly_year;

-- 4) PART TO WHOLE ANALYSIS
-- WHICH CATEGORY CONTRIBUTES MOST TO OVERALL SALES
WITH category_sales AS
(
	SELECT 
	P.category category,
	SUM(F.sales_amount) Total_sales
	FROM
	gold.fact_sales F	
	LEFT JOIN gold.dim_products P
		ON F.product_key = P.product_key
	WHERE F.order_date IS NOT NULL
	GROUP BY  P.category
)
SELECT 
category,
Total_sales,
SUM(Total_sales) OVER () Overall_sales,
CONCAT(ROUND((CAST(Total_sales AS float)/ SUM(Total_sales) OVER ())*100, 2), '%') AS percent_sale
FROM
category_sales
ORDER BY Total_sales DESC;



-- 5) DATA SEGMENTATION
-- SEGMENT PRODUCT INTO COST RANGES AND COUNT HOW MANY PRODUCT FALLS INTO EACH SEGMENTS
WITH product_segment AS
(
	SELECT 
	product_key,
	product_name,
	cost,
	CASE
		WHEN cost < 100 THEN 'BELOW 100'
		WHEN cost BETWEEN 100 AND 500 THEN '100-500'
		WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
		ELSE 'ABOVE 1000'
	END cost_range
	FROM 
	gold.dim_products
)
SELECT 
cost_range,
COUNT(product_key) AS Total_products
FROM product_segment
GROUP BY cost_range
ORDER BY Total_products DESC;


/*
Group customers into three segments based on their spending behavior:
	- VIP: Customers with at least 12 months of history and spending more than €5,000.
	- Regular: Customers with at least 12 months of history but spending €5,000 or less.
	- New: Customers with a lifespan less than 12 months.
And find the total number of customers by each group
*/
WITH Customer_Spending AS
(
	SELECT
	C.customer_key,
	SUM(F.sales_amount) Total_Spending,
	MIN(order_date) First_order,
	MAX(order_date) Last_order,
	DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) Lifespan
	FROM gold.fact_sales F
	LEFT JOIN gold.dim_customers C
		ON F.customer_key = C.customer_key
	GROUP BY C.customer_key
)
SELECT 
Customer_Segements,
COUNT(customer_key) AS total_customers
FROM
(
	SELECT 
	customer_key,
	CASE
		WHEN Lifespan >=12 AND Total_Spending > 5000 THEN 'VIP'
		WHEN Lifespan >=12 AND Total_Spending <= 5000 THEN 'Regular'
		ELSE 'New'
	END Customer_Segements
	FROM
	Customer_Spending) t
GROUP BY Customer_Segements
ORDER BY total_customers DESC;


WITH Customer_Spending AS
(
	SELECT
	C.customer_key,
	SUM(F.sales_amount) Total_Spending,
	MIN(order_date) First_order,
	MAX(order_date) Last_order,
	DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) Lifespan
	FROM gold.fact_sales F
	LEFT JOIN gold.dim_customers C
		ON F.customer_key = C.customer_key
	GROUP BY C.customer_key
),
Customer_Segmentation AS
(
	SELECT 
	customer_key,
	CASE
		WHEN Lifespan >=12 AND Total_Spending > 5000 THEN 'VIP'
		WHEN Lifespan >=12 AND Total_Spending <= 5000 THEN 'Regular'
		ELSE 'New'
	END Customer_Segements
	FROM Customer_Spending
)
SELECT
	Customer_Segements,
	COUNT(customer_key) total_customers
FROM Customer_Segmentation
GROUP BY Customer_Segements
ORDER BY total_customers DESC;


-- 6) BUILD REPORT

/*
=====================================================================================
Customer Report
=====================================================================================
Purpose:
	-This report consolidates key customer metrics and behaviors
Highlights:
	1. Gathers essential fields such as names, ages, and transaction details.
	2. Segments customers into categories (VIP, Regular, New) and age groups.
	3. Aggregates customer-level metrics:
		- total orders
		- total sales
		- total quantity purchased
		- total products
		- lifespan (in months)
	4. Calculates valuable KPIs:
		- recency (months since last order)
		- average order value
		- average monthly spend
=====================================================================================
*/
-- 1) BASIC QUERIES:- RETRIVES CORE COLUMNS FROM TABLES
CREATE VIEW gold.report_customers AS 
WITH base_query AS 
(
	SELECT 
	F.order_number,
	F.product_key,
	F.order_date,
	F.sales_amount,
	F.quantity,
	C.customer_key,
	C.customer_number,
	DATEDIFF(YEAR, C.birthdate, GETDATE()) age,
	CONCAT(C.first_name,' ',C.last_name) customer_name
	FROM gold.fact_sales F
	LEFT JOIN 
	gold.dim_customers C
		ON F.customer_key = C.customer_key
	WHERE order_date IS NOT NULL
),
-- 2) Customer Aggregations: Summarizes key metrics at the customer level
customer_aggregation AS 
(
	SELECT 
		customer_key,
		customer_number,
		age,
		customer_name,
		COUNT(DISTINCT order_number) AS total_orders,
		SUM(sales_amount) AS total_sales,
		SUM(quantity) AS total_quantity,
		COUNT(DISTINCT product_key) AS total_product,
		MAX(order_date) Last_order,
		DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) Lifespan	
	FROM base_query
	GROUP BY
		customer_key,
		customer_number,
		age,
		customer_name 
)
SELECT 
customer_key,
customer_number,
customer_name,
age,
CASE
	WHEN age < 20  THEN 'UNDER 20'
	WHEN age BETWEEN 20 AND 29 THEN '20-29'
	WHEN age BETWEEN 30 AND 39 THEN '30-39'
	WHEN age BETWEEN 40 AND 49 THEN '40-49'
	ELSE '50 AND ABOVE'
END age_groups,
CASE
	WHEN Lifespan >=12 AND total_sales > 5000 THEN 'VIP'
	WHEN Lifespan >=12 AND total_sales <= 5000 THEN 'Regular'
	ELSE 'New'
END Customer_Segements,
total_orders,
total_sales,
total_quantity,
total_product,
Last_order,
DATEDIFF(month, Last_order, GETDATE()) recensy,
Lifespan,
-- compute average order value (AVO)
CASE
	WHEN total_orders = 0 THEN 0
	ELSE (total_sales / total_orders) 
END avg_order_value,
-- computer avaerage monthly spend
CASE
	WHEN Lifespan = 0 THEN 0
	ELSE (total_sales / Lifespan) 
END avg_monthly_spend
FROM customer_aggregation;

SELECT * FROM gold.report_customers;

/*
==========================================================================
Product Report
==========================================================================
Purpose:
	-This report consolidates key product metrics and behaviors.
Highlights:
	1. Gathers essential fields such as product name, category, subcategory, and cost.
	2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
	3. Aggregates product-level metrics:
		- total orders
		- total sales
		- total quantity sold
		- total customers (unique)
		- lifespan (in months)
	4. Calculates valuable KPIs:
		- recency (months since last sale)
		- average order revenue (AOR)
		- average monthly revenue
==========================================================================
*/
CREATE VIEW gold.report_products AS
WITH base_query AS
(
	SELECT 
	F.order_number,
	F.order_date,
	F.customer_key,
	F.sales_amount,
	F.quantity,
	P.product_key,
	P.product_name,
	P.category,
	P.subcategory,
	P.cost
	FROM gold.fact_sales F
	LEFT JOIN 
	gold. dim_products P
		ON F.product_key = P.product_key
	WHERE order_date IS NOT NULL
),
product_aggregation AS 
(
	SELECT 
		product_key,
		product_name,
		category,
		subcategory,
		cost,
		COUNT(DISTINCT order_number) AS total_orders,
		MAX(order_date) Last_order,
		COUNT(DISTINCT customer_key) AS total_customers,
		SUM(sales_amount) AS total_sales,
		SUM(quantity) AS total_quantity,
		DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) Lifespan,
		ROUND(AVG(CAST(sales_amount AS float)/ NULLIF(quantity, 0)),1 ) AS avg_selling_price
	FROM base_query
	GROUP BY
		product_key,
		product_name,
		category,
		subcategory,
		cost
)
SELECT 
	product_key,
	product_name,
	category,
	subcategory,
	cost,
	Last_order,
	DATEDIFF(MONTH, Last_order, GETDATE()) recency_in_month,
	CASE
		WHEN total_sales > 50000 THEN 'High-performer'
		WHEN total_sales >= 10000 THEN 'Mid-performer'
		ELSE 'low-performer'
	END product_segment,
	Lifespan,
	total_orders,
	total_sales,
	total_quantity,
	total_customers,
	avg_selling_price,
	-- AVERAGE OREDER REVENUE (AOR)
	CASE
		WHEN total_orders = 0 THEN 0
		ELSE (total_sales / total_orders) 
	END avg_order_revenue,
-- computer avaerage monthly spend
	CASE
		WHEN Lifespan = 0 THEN 0
		ELSE (total_sales / Lifespan) 
	END avg_monthly_revenue
FROM product_aggregation;

select * from gold.report_products