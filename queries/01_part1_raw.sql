-- Part 1 · Core Metrics — Raw (all orders, anomalies included)
SELECT
    l.location_id,
    l.location_name,
    l.city,
    SUM(o.order_amount) AS total_revenue,
    COUNT(o.order_id) AS total_orders,
    ROUND(AVG(o.order_amount), 2) AS avg_order_value
FROM 
    orders o
JOIN 
    locations l 
    ON o.location_id = l.location_id
WHERE 
    o.order_date BETWEEN '2023-03-01' AND '2023-03-31'
GROUP BY 
    location_id, 
    location_name, 
    city
ORDER BY 
    total_revenue DESC;

-- Problem: We have orders with negative amounts. This could polute the result. To fix that, we can filter them out from the query.
SELECT
    l.location_id,
    l.location_name,
    l.city,
    SUM(o.order_amount) AS total_revenue,
    COUNT(o.order_id) AS total_orders,
    ROUND(AVG(o.order_amount), 2) AS avg_order_value
FROM 
    orders o
JOIN 
    locations l 
    ON o.location_id = l.location_id
WHERE 
    o.order_date BETWEEN '2023-03-01' AND '2023-03-31'
    AND o.order_amount > 0
GROUP BY 
    location_id, 
    location_name, 
    city;
