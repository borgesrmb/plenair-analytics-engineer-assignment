-- Part 2 · Loyalty vs Non-member Comparison (March 2023, order_amount > 0)
WITH 
march_orders AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.order_amount,
        c.loyalty_member
    FROM 
        orders o
    JOIN 
        customers c 
        ON o.customer_id = c.customer_id
    WHERE 
        o.order_date BETWEEN '2023-03-01' AND '2023-03-31'
        AND o.order_amount > 0
),
per_customer AS (
    SELECT
        customer_id,
        loyalty_member,
        COUNT(*) AS order_count,
        SUM(order_amount) AS total_spent
    FROM 
        march_orders
    GROUP BY 
        customer_id, 
        loyalty_member
)
SELECT
    loyalty_member,
    SUM(order_count) AS total_orders,
    COUNT(customer_id) AS distinct_customers,
    ROUND(
        SUM(total_spent) / SUM(order_count), 
        2
    ) AS avg_order_value,
    ROUND(
        SUM(order_count) / COUNT(customer_id), 
        2
    ) AS orders_per_customer,
    ROUND(
        SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(customer_id), 0),
        2
    ) AS repeat_rate
FROM 
    per_customer
GROUP BY 
    loyalty_member;
