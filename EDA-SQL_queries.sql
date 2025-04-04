USE DataWarehouseAnalytics;
GO

-- 1)Explore database structure

-- Explore all objects  in the Database
SELECT * 
FROM INFORMATION_SCHEMA.TABLES;

-- Explaore all columns in database
SELECT * 
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dim_customers';

-- 2) Daimension exploration

-- explore all countries our customers  come from
SELECT DISTINCT country
FROM gold.dim_customers;

--- explore all catogories "The major divison"
SELECT DISTINCT category, subcategory, product_name
FROM gold.dim_products;

--- 3) date exploation\
--- find the date of first and last order
SELECT order_date
FROM gold.fact_sales;

SELECT MIN(order_date) first_order_date, 
	   MAX(order_date) last_order_date
FROM gold.fact_sales;

-- How many years of sales are available
SELECT MIN(order_date) first_order_date, 
	   MAX(order_date) last_order_date, 
	   DATEDIFF(YEAR, Min(order_date), MAX(order_date)) order_range
FROM gold.fact_sales;

-- find the youngest and oldest customers
SELECT  MIN(birthdate) oldest_birthdate, 
	    DATEDIFF(YEAR, MIN(birthdate), GETDATE()) oldest_age,	
	    MAX(birthdate) youngest_birth_date,
	    DATEDIFF(YEAR, MAX(birthdate), GETDATE()) youngest_age
FROM gold.dim_customers;

-- 4) measure exploration
-- Find the Total Sales
SELECT SUM(sales_amount)
FROM gold.fact_sales


-- Find how many items are sold
SELECT SUM(quantity)
FROM gold.fact_sales


-- Find the average selling price
SELECT AVG(price)
FROM gold.fact_sales


-- Find the Total number of Orders
SELECT COUNT(order_number)
FROM gold.fact_sales

SELECT COUNT(DISTINCT order_number)
FROM gold.fact_sales

-- Find the total number of products
SELECT COUNT(product_key)
FROM gold.dim_products


-- Find the total number of customers
SELECT COUNT(customer_id)
FROM gold.dim_customers


-- Find the total number of customers that has placed an order
SELECT COUNT(DISTINCT customer_key) as Number_of_customers
FROM gold.fact_sales

--- Generate Report that shows all key metrics of the business