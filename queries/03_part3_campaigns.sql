-- Part 3 · Campaign Effectiveness.
-- Keeping the first redemption_id for multiple redemptions per order to avoid double-counting revenue.
WITH 
deduped_redemptions AS (
    SELECT
        campaign_name,
        order_id,
        MIN(redemption_id) AS redemption_id
    FROM 
        campaign_redemptions
    GROUP BY 
        campaign_name, 
        order_id
),
campaign_counts AS (
    SELECT
        campaign_name,
        COUNT(redemption_id) AS raw_redemption_count,
        COUNT(DISTINCT order_id) AS clean_redemption_count
    FROM 
        deduped_redemptions
    GROUP BY 
        campaign_name
)
SELECT
    dr.campaign_name,
    rc.raw_redemption_count,
    rc.clean_redemption_count,
    SUM(o.order_amount) AS total_revenue,
    ROUND(AVG(o.order_amount), 2) AS avg_order_value
FROM 
    deduped_redemptions dr
JOIN 
    orders o  
    ON dr.order_id = o.order_id
JOIN 
    raw_counts rc 
    ON dr.campaign_name = rc.campaign_name
GROUP BY 
    campaign_name, 
    raw_redemption_count, 
    clean_redemption_count;
