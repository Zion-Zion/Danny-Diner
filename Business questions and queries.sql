/*SELECT 
    c.TABLE_SCHEMA, 
    c.TABLE_NAME, 
    c.COLUMN_NAME, 
    c.DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS c
ORDER BY c.TABLE_NAME, c.ORDINAL_POSITION;*/


-- What is the total amount each customer spent at the restaurant?

SELECT s.customer_id as Customer, '$' + CAST(SUM(m.price) AS VARCHAR(10)) AS Total_amount
FROM dannys_diner.sales s
JOIN dannys_diner.menu m
ON s.product_id = m.product_id
GROUP BY s.customer_id;

-- How many days has each customer visited the restaurant?

SELECT s.customer_id, ' visited ' + CAST(COUNT(DISTINCT order_date) AS VARCHAR(10)) + ' days' AS visit_days
FROM dannys_diner.sales s
GROUP BY s.customer_id
ORDER BY visit_days DESC;

-- What was the first item from the menu purchased by each customer?

SELECT customer, product_name, order_date
FROM (
    SELECT s.customer_id AS customer, 
        m.product_name, 
        s.order_date, 
        ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY customer_id) rn
    FROM dannys_diner.sales s
    JOIN dannys_diner.menu m
    ON s.product_id = m.product_id
) subquery
WHERE rn = 1;


-- What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT TOP 1 m.product_name, COUNT(*) AS number_of_purchases
FROM dannys_diner.menu m
JOIN dannys_diner.sales s
ON s.product_id = m.product_id
GROUP BY m.product_name
ORDER BY number_of_purchases DESC;

--Which item was the most popular for each customer?

SELECT customer_id, product_name, number_of_purchases
FROM (
	SELECT s.customer_id, m.product_name, COUNT(*) AS number_of_purchases,
	DENSE_RANK() OVER(PARTITION BY customer_id ORDER BY COUNT(*) DESC) rn
FROM dannys_diner.menu m
JOIN dannys_diner.sales s
ON s.product_id = m.product_id
GROUP BY s.customer_id, m.product_name
	) subquery
WHERE rn = 1
ORDER BY customer_id;

-- Which item was purchased first by the customer after they became a member?

SELECT customer_id, product_name
FROM (
	SELECT s.customer_id, m.product_name, mm.join_date, s.order_date,
	ROW_NUMBER() OVER(PARTITION BY s.customer_id ORDER BY s.customer_id) AS rn
	FROM dannys_diner.members mm
	JOIN dannys_diner.sales s
	ON mm.customer_id = s.customer_id
	JOIN dannys_diner.menu m
	ON s.product_id = m.product_id
	WHERE s.order_date >= mm.join_date
		) subquery
WHERE rn = 1;

-- Which item was purchased just before the customer became a member?

SELECT customer_id, product_name
FROM (
	SELECT s.customer_id, m.product_name, mm.join_date, s.order_date,
	ROW_NUMBER() OVER(PARTITION BY s.customer_id ORDER BY s.customer_id, order_date DESC) AS rn
	FROM dannys_diner.members mm
	JOIN dannys_diner.sales s
	ON mm.customer_id = s.customer_id
	JOIN dannys_diner.menu m
	ON s.product_id = m.product_id
	WHERE s.order_date < mm.join_date
	) subquery
WHERE rn = 1;


-- What is the total items and amount spent for each member before they became a member?

SELECT customer_id, total_items,  CONCAT('$', total_amount) as total_amount
FROM(
	SELECT s.customer_id, COUNT(*) total_items, SUM(m.price) total_amount
	FROM dannys_diner.members mm
	JOIN dannys_diner.sales s
	ON mm.customer_id = s.customer_id
	JOIN dannys_diner.menu m
	ON s.product_id = m.product_id
	WHERE s.order_date < mm.join_date
	GROUP BY s.customer_id
		) subquery;


-- If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

SELECT customer_id, CONCAT(SUM(points * 10), ' points') AS points
FROM (
	SELECT s.customer_id,
	CASE WHEN product_name = 'sushi' THEN m.price * 2
		ELSE m.price END AS points
	FROM dannys_diner.sales s
	JOIN dannys_diner.menu m
	ON s.product_id = m.product_id
	) subquery
GROUP BY customer_id;

-- In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

SELECT customer_id, CONCAT(SUM(points * 10), ' points') AS points
FROM (
		SELECT s.customer_id,
				CASE WHEN DATEDIFF(DAY,mm.join_date,s.order_date) >= 0 AND DATEDIFF(DAY,mm.join_date,s.order_date) <=6 THEN m.price * 2
					ELSE m.price END AS points
		FROM dannys_diner.sales s
		JOIN dannys_diner.menu m
		ON s.product_id = m.product_id
		JOIN dannys_diner.members mm
		ON s.customer_id = mm.customer_id
		WHERE s.order_date BETWEEN '2021-01-01' AND '2021-01-31'
		) subquery
GROUP BY customer_id;

/*
SELECT s.customer_id, mm.join_date,s.order_date, m.price*10, DATEDIFF(DAY,mm.join_date,s.order_date), CASE WHEN DATEDIFF(DAY,mm.join_date,s.order_date) >= 0 AND DATEDIFF(DAY,mm.join_date,s.order_date) <=6 THEN m.price * 2
					ELSE m.price END AS points
		FROM dannys_diner.sales s
		JOIN dannys_diner.menu m
		ON s.product_id = m.product_id
		JOIN dannys_diner.members mm
		ON s.customer_id = mm.customer_id
		WHERE s.order_date BETWEEN '2021-01-01' AND '2021-01-31'

*/

-- Bonus questions

SELECT s.customer_id, s.order_date, m.product_name, m.price,
		CASE WHEN s.order_date >= mm.join_date THEN 'Y'
			ELSE 'N' END AS member
FROM dannys_diner.menu m
FULL JOIN dannys_diner.sales s
ON m.product_id = s.product_id
FULL JOIN dannys_diner.members mm
ON s.customer_id = mm.customer_id
ORDER BY customer_id, order_date;


SELECT customer_id, order_date, product_name, price, member,
		CASE WHEN member = 'N' THEN NULL
			 ELSE DENSE_RANK() OVER (PARTITION BY customer_id, member ORDER BY customer_id, order_date)
			 END AS ranking
FROM (
    SELECT s.customer_id, s.order_date, m.product_name, m.price,
        CASE WHEN s.order_date >= mm.join_date THEN 'Y'
             ELSE 'N' END AS member
    FROM dannys_diner.menu m
    FULL JOIN dannys_diner.sales s
	ON m.product_id = s.product_id
    FULL JOIN dannys_diner.members mm
	ON s.customer_id = mm.customer_id
		) AS subquery
ORDER BY customer_id, order_date;