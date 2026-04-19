-- Seller Health Score — Green / Yellow / Red classification
WITH seller_metrics AS (
    SELECT
        oi.seller_id,
        s.seller_state,
        COUNT(DISTINCT oi.order_id)                   AS total_orders,
        ROUND(SUM(oi.price)::NUMERIC, 2)              AS total_revenue,
        ROUND(AVG(r.review_score)::NUMERIC, 2)        AS avg_review_score,
        ROUND(SUM(CASE 
            WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date 
            THEN 1 ELSE 0 END) * 100.0 / 
            COUNT(DISTINCT oi.order_id)::NUMERIC, 2)  AS late_delivery_pct
    FROM order_items oi
    JOIN orders o       ON oi.order_id  = o.order_id
    JOIN sellers s      ON oi.seller_id = s.seller_id
    LEFT JOIN order_reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
    AND o.order_delivered_customer_date IS NOT NULL
    GROUP BY oi.seller_id, s.seller_state
    HAVING COUNT(DISTINCT oi.order_id) >= 10
),
seller_scored AS (
    SELECT
        *,
        -- Health classification based on review score + late delivery rate
        CASE
            WHEN avg_review_score >= 4.0 
                AND late_delivery_pct <= 10  THEN 'Green'
            WHEN avg_review_score >= 3.0 
                AND late_delivery_pct <= 20  THEN 'Yellow'
            ELSE                                  'Red'
        END    AS health_status
    FROM seller_metrics
)
SELECT
    health_status,
    COUNT(*)                                   AS seller_count,
    ROUND(AVG(total_orders)::NUMERIC, 1)       AS avg_orders,
    ROUND(AVG(total_revenue)::NUMERIC, 2)      AS avg_revenue,
    ROUND(AVG(avg_review_score)::NUMERIC, 2)   AS avg_review,
    ROUND(AVG(late_delivery_pct)::NUMERIC, 2)  AS avg_late_pct,
    ROUND(SUM(total_revenue)::NUMERIC, 2)      AS total_group_revenue
FROM seller_scored
GROUP BY health_status
ORDER BY 
    CASE health_status 
        WHEN 'Green' THEN 1 
        WHEN 'Yellow' THEN 2 
        ELSE 3 
    END;



-- Full seller detail table for Power BI
WITH seller_metrics AS (
    SELECT
        oi.seller_id,
        s.seller_state,
        COUNT(DISTINCT oi.order_id)                  AS total_orders,
        ROUND(SUM(oi.price)::NUMERIC, 2)             AS total_revenue,
        ROUND(AVG(r.review_score)::NUMERIC, 2)       AS avg_review_score,
        ROUND(SUM(CASE 
            WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date 
            THEN 1 ELSE 0 END) * 100.0 / 
            COUNT(DISTINCT oi.order_id)::NUMERIC, 2) AS late_delivery_pct
    FROM order_items oi
    JOIN orders o       ON oi.order_id  = o.order_id
    JOIN sellers s      ON oi.seller_id = s.seller_id
    LEFT JOIN order_reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
    AND o.order_delivered_customer_date IS NOT NULL
    GROUP BY oi.seller_id, s.seller_state
    HAVING COUNT(DISTINCT oi.order_id) >= 10
)
SELECT
    seller_id,
    seller_state,
    total_orders,
    total_revenue,
    avg_review_score,
    late_delivery_pct,
    CASE
        WHEN avg_review_score >= 4.0 
            AND late_delivery_pct <= 10  THEN 'Green'
        WHEN avg_review_score >= 3.0 
            AND late_delivery_pct <= 20  THEN 'Yellow'
        ELSE                                  'Red'
    END   AS health_status,
    RANK() OVER (ORDER BY total_revenue DESC)   AS revenue_rank
FROM seller_metrics
ORDER BY total_revenue DESC;