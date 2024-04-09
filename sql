# Q1) How many orders were completed in 2018? (Note: We operate in US/Eastern time zone)
	9228 orders
SELECT COUNT(DISTINCT order_id) AS order_ct
FROM `Test.orders`
WHERE EXTRACT(YEAR FROM DATETIME(order_timestamp, 'US/Eastern')) = 2018


 							
# Q2) How many orders were completed in 2018 containing at least 10 units?
 	2711 orders
SELECT COUNT(DISTINCT order_id) as order_ct
FROM
(
 SELECT o.order_id as order_id
 FROM `Test.line_items` l
 JOIN `Test.orders` o
 ON l.order_id=o.order_id
 WHERE EXTRACT(YEAR FROM DATETIME(order_timestamp, 'US/Eastern')) = 2018
 GROUP BY order_id
 HAVING COUNT(DISTINCT line_item_id)<10
)



# Q3) How many customers have ever purchased a medium sized sweater with a discount?
3129 customers
SELECT COUNT(DISTINCT c.customer_uid) AS customer_ct
FROM `Test.line_items` l
JOIN `Test.orders` o
ON l.order_id = o.order_id
JOIN `Test.customers` c
ON c.customer_uid=o.customer_uid
WHERE l.size='M' AND discount!=0

						
# Q4) How profitable was our most profitable month?
July 2020 was the most profitable month with profit of $44711.93 

-- Profitability = revenue - cost
-- Step 1: Calculate the profit from non-return orders, which is (quantity per order x (selling price - supplier cost)*(1-discount) + shipping revenue - shipping cost
-- Step 2: Calculate the profit from return orders, which is shipping revenue - 2*shipping cost. Note that Jiffy offers free return for the first order returned
-- Step 3: Add the profit from return and non-return orders together and then aggregate by year and month, filter for the highest month




-- Step 1: revenue per order
WITH t AS
(
       SELECT order_id,
       SUM(quantity*(selling_price - supplier_cost)) AS revenue
       FROM `Test.line_items`
       GROUP BY order_id
),
-- Step 1.1: Profit from non-returned orders
t1 AS
(
       SELECT
       EXTRACT(YEAR FROM DATETIME(order_timestamp, 'US/Eastern')) AS year,
       EXTRACT(MONTH FROM DATETIME(order_timestamp, 'US/Eastern')) AS month,
       SUM(t.revenue*(1-discount)+ shipping_revenue - shipping_cost) AS profit
       FROM `Test.orders` o LEFT JOIN t
       ON o.order_id=t.order_id
       WHERE o.returned=false
       GROUP BY year,month
),
-- Step 2: Profit from returned orders 
t2 AS
(
       SELECT
       EXTRACT(YEAR FROM DATETIME(order_timestamp, 'US/Eastern')) AS year,
       EXTRACT(MONTH FROM DATETIME(order_timestamp, 'US/Eastern')) AS month,
       SUM(shipping_revenue - shipping_cost*2) as profit
       FROM `Test.orders` o
       GROUP BY year, month
)
-- Step 3: Sum the profit from both return and non-return orders
SELECT  t1.year,
       t1.month,
       ROUND(SUM(t1.profit + t2.profit),2) AS profit
FROM t1
JOIN t2
ON t1.year=t2.year AND t1.month=t2.month
GROUP BY t1.year, t1.month
ORDER BY profit DESC

 							
# Q5) What is the return rate for business vs.non-business customers? 
The return rate for business and non-business customers are 54.75% and 32.33% respectively
-- Step 1: Count the number of return customers who have placed more than 1 order, group by is_business
WITH t AS
(SELECT
c.customer_uid,
c.is_business
FROM `Test.customers` c JOIN `Test.orders` o
ON c.customer_uid=o.customer_uid
GROUP BY 1,2
HAVING COUNT(o.order_id)>1),
t1 AS
(SELECT is_business,
COUNT(DISTINCT customer_uid) AS users
FROM t
GROUP BY 1),
-- Step 2: Count the number of total customers, group by is_business
t2 AS
(SELECT is_business,
COUNT(DISTINCT customer_uid) AS users
FROM `Test.customers`
GROUP BY 1)
-- Step 3: Return rate = # of return customers/ # of total customers, group by is_business
SELECT t1.is_business,
ROUND((t1.users/t2.users)*100,2) AS return_rate
FROM t1 JOIN t2
ON t1.is_business=t2.is_business
