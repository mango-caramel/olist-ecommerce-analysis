
SELECT COUNT(*) 
FROM order_items oi
LEFT JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;


SELECT COUNT(*)
FROM order_items oi
LEFT JOIN products p ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;


SELECT COUNT(*)
FROM order_items oi
LEFT JOIN sellers s ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;

SELECT COUNT(*)
FROM order_payments op
LEFT JOIN orders o ON op.order_id = o.order_id
WHERE o.order_id IS NULL;


SELECT COUNT(*)
FROM order_reviews r
LEFT JOIN orders o ON r.order_id = o.order_id
WHERE o.order_id IS NULL;


SELECT COUNT(*)
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;


SELECT COUNT(*)
FROM products p
LEFT JOIN product_category_translation t 
ON p.product_category_name = t.product_category_name
WHERE p.product_category_name IS NOT NULL
AND t.product_category_name IS NULL;


-- Row count check across all tables
SELECT 'customers'               AS table_name, COUNT(*) AS rows FROM customers
UNION ALL SELECT 'orders',                 COUNT(*) FROM orders
UNION ALL SELECT 'order_items',            COUNT(*) FROM order_items
UNION ALL SELECT 'order_payments',         COUNT(*) FROM order_payments
UNION ALL SELECT 'order_reviews',          COUNT(*) FROM order_reviews
UNION ALL SELECT 'products',               COUNT(*) FROM products
UNION ALL SELECT 'sellers',                COUNT(*) FROM sellers
UNION ALL SELECT 'category_translation',   COUNT(*) FROM product_category_translation;

-- Order status breakdown
SELECT
    order_status,
    COUNT(*) AS total_orders,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct
FROM orders
GROUP BY order_status
ORDER BY total_orders DESC;

-- Date range of the dataset
SELECT
    MIN(order_purchase_timestamp) AS first_order,
    MAX(order_purchase_timestamp) AS last_order,
    COUNT(DISTINCT DATE_TRUNC('month', order_purchase_timestamp)) AS months_covered
FROM orders;



-- 1. Overall revenue metrics
SELECT
    ROUND(SUM(oi.price)::NUMERIC, 2)     AS total,
    ROUND(SUM(oi.freight_value)::NUMERIC, 2)AS total_freight,
    ROUND(AVG(order_total), 2)       AS avg_order_value,
    COUNT(DISTINCT oi.order_id)      AS total_orders,
    COUNT(DISTINCT oi.seller_id)     AS active_sellers
FROM order_items oi
JOIN (
    SELECT order_id, SUM(price) AS order_total
    FROM order_items
    GROUP BY order_id
) order_totals ON oi.order_id = order_totals.order_id;

-- 2. Monthly revenue trend
SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp)::DATE     AS month,
    ROUND(SUM(oi.price)::NUMERIC, 2)   AS monthly_revenue,
    COUNT(DISTINCT o.order_id)         AS orders,
    ROUND(AVG(oi.price)::NUMERIC, 2)   AS avg_item_price
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
ORDER BY month;

-- 3. Top 10 product categories by revenue
SELECT
    COALESCE(t.product_category_name_english, p.product_category_name, 'Uncategorised') AS category,
    ROUND(SUM(oi.price)::NUMERIC, 2)      AS revenue,
    COUNT(DISTINCT oi.order_id)           AS orders,
    ROUND(AVG(oi.price)::NUMERIC, 2)      AS avg_price,
    COUNT(DISTINCT oi.seller_id)          AS sellers
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN product_category_translation t
    ON p.product_category_name = t.product_category_name
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY COALESCE(t.product_category_name_english, p.product_category_name, 'Uncategorised')
ORDER BY revenue DESC
LIMIT 10;

-- 4. Seller revenue concentration (top 10% vs rest)
WITH seller_revenue AS (
    SELECT
        oi.seller_id,
        ROUND(SUM(oi.price)::NUMERIC, 2)    AS total_revenue,
        COUNT(DISTINCT oi.order_id)         AS total_orders,
        NTILE(10) OVER (ORDER BY SUM(oi.price) DESC)     AS decile
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.seller_id
)
SELECT
    CASE WHEN decile = 1 THEN 'Top 10%' ELSE 'Bottom 90%' END AS seller_group,
    COUNT(*)     AS seller_count,
    ROUND(SUM(total_revenue)::NUMERIC, 2)     AS group_revenue,
    ROUND(SUM(total_revenue) * 100.0 /
        SUM(SUM(total_revenue)) OVER ()::NUMERIC, 2)           AS revenue_pct
FROM seller_revenue
GROUP BY CASE WHEN decile = 1 THEN 'Top 10%' ELSE 'Bottom 90%' END
ORDER BY revenue_pct DESC;

-- 5. Revenue by state (top 10)
SELECT
    c.customer_state         AS state,
    COUNT(DISTINCT o.order_id)           AS orders,
    ROUND(SUM(oi.price)::NUMERIC, 2)     AS revenue,
    ROUND(AVG(oi.price)::NUMERIC, 2)     AS avg_order_value
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY revenue DESC
LIMIT 10;



--6. Overall delivery performance
SELECT
    ROUND(AVG(
        EXTRACT(EPOCH FROM (
            o.order_delivered_customer_date - o.order_purchase_timestamp
        )) / 86400
    )::NUMERIC, 2)      AS avg_delivery_days,
    ROUND(AVG(
        EXTRACT(EPOCH FROM (
            o.order_estimated_delivery_date - o.order_purchase_timestamp
        )) / 86400
    )::NUMERIC, 2)   AS avg_estimated_days,
    COUNT(*)         AS total_delivered,
    SUM(CASE 
        WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date 
        THEN 1 ELSE 0 
    END)           AS on_time,
    SUM(CASE 
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date 
        THEN 1 ELSE 0 
    END)             AS late,
    ROUND(SUM(CASE 
        WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date 
        THEN 1 ELSE 0 
    END) * 100.0 / COUNT(*)::NUMERIC, 2)     AS on_time_pct
FROM orders o
WHERE o.order_status = 'delivered'
AND o.order_delivered_customer_date IS NOT NULL;


-- 7. Delivery performance by state (top 10 worst average delay)
SELECT
    c.customer_state     AS state,
    COUNT(DISTINCT o.order_id)   AS total_orders,
    ROUND(AVG(
        EXTRACT(EPOCH FROM (
            o.order_delivered_customer_date - o.order_purchase_timestamp
        )) / 86400
    )::NUMERIC, 2)    AS avg_delivery_days,
    ROUND(AVG(
        EXTRACT(EPOCH FROM (
            o.order_estimated_delivery_date - o.order_purchase_timestamp
        )) / 86400
    )::NUMERIC, 2)    AS avg_estimated_days,
    ROUND(AVG(
        EXTRACT(EPOCH FROM (
            o.order_delivered_customer_date - o.order_estimated_delivery_date
        )) / 86400
    )::NUMERIC, 2)    AS avg_days_vs_estimate,
    ROUND(SUM(CASE 
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date 
        THEN 1 ELSE 0 
    END) * 100.0 / COUNT(*)::NUMERIC, 2)   AS late_pct
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY avg_delivery_days DESC
LIMIT 10;

-- 8. On-time delivery rate by seller (top 10 worst sellers, min 50 orders)
WITH seller_delivery AS (
    SELECT
        oi.seller_id,
        COUNT(DISTINCT o.order_id)     AS total_orders,
        SUM(CASE 
            WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date 
            THEN 1 ELSE 0 
        END)      AS late_orders,
        ROUND(SUM(CASE 
            WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date 
            THEN 1 ELSE 0 
        END) * 100.0 / COUNT(*)::NUMERIC, 2)  AS late_pct,
        ROUND(AVG(
            EXTRACT(EPOCH FROM (
                o.order_delivered_customer_date - o.order_purchase_timestamp
            )) / 86400
        )::NUMERIC, 2)      AS avg_delivery_days
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    AND o.order_delivered_customer_date IS NOT NULL
    GROUP BY oi.seller_id
    HAVING COUNT(DISTINCT o.order_id) >= 50
)
SELECT *
FROM seller_delivery
ORDER BY late_pct DESC
LIMIT 10;

-- 9. Delivery time buckets — how fast are most orders?
SELECT
    CASE
        WHEN delivery_days <= 7  THEN '1. Within 1 week'
        WHEN delivery_days <= 14 THEN '2. 1-2 weeks'
        WHEN delivery_days <= 21 THEN '3. 2-3 weeks'
        WHEN delivery_days <= 30 THEN '4. 3-4 weeks'
        ELSE                          '5. Over 1 month'
    END      AS delivery_bucket,
    COUNT(*)   AS orders,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ()::NUMERIC, 2) AS pct
FROM (
    SELECT
        EXTRACT(EPOCH FROM (
            o.order_delivered_customer_date - o.order_purchase_timestamp
        )) / 86400       AS delivery_days
    FROM orders o
    WHERE o.order_status = 'delivered'
    AND o.order_delivered_customer_date IS NOT NULL
) delivery_times
GROUP BY delivery_bucket
ORDER BY delivery_bucket;



-- 10. Repeat customer rate
SELECT
    total_customers,
    repeat_customers,
    ROUND(repeat_customers * 100.0 / total_customers::NUMERIC, 2) AS repeat_rate_pct,
    single_customers,
    ROUND(single_customers * 100.0 / total_customers::NUMERIC, 2) AS single_rate_pct
FROM (
    SELECT
        COUNT(DISTINCT customer_unique_id)                    AS total_customers,
        SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END)     AS repeat_customers,
        SUM(CASE WHEN order_count = 1 THEN 1 ELSE 0 END)     AS single_customers
    FROM (
        SELECT
            c.customer_unique_id,
            COUNT(o.order_id)     AS order_count
        FROM customers c
        JOIN orders o ON c.customer_id = o.customer_id
        WHERE o.order_status = 'delivered'
        GROUP BY c.customer_unique_id
    ) customer_orders
) summary;

-- 11. Review score distribution
SELECT
    review_score,
    COUNT(*)      AS total_reviews,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ()::NUMERIC, 2) AS pct
FROM order_reviews
GROUP BY review_score
ORDER BY review_score DESC;

-- 12. Average review score by top 10 product categories
SELECT
    COALESCE(t.product_category_name_english,
        p.product_category_name, 'Uncategorised')  AS category,
    ROUND(AVG(r.review_score)::NUMERIC, 2)         AS avg_review_score,
    COUNT(DISTINCT o.order_id)                     AS total_orders,
    SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0    AS negative_reviews,
    ROUND(SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*)::NUMERIC, 2)            AS negative_pct
FROM orders o
JOIN order_items oi      ON o.order_id  = oi.order_id
JOIN products p          ON oi.product_id = p.product_id
LEFT JOIN product_category_translation t
                         ON p.product_category_name = t.product_category_name
JOIN order_reviews r     ON o.order_id  = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY COALESCE(t.product_category_name_english,
    p.product_category_name, 'Uncategorised')
ORDER BY total_orders DESC
LIMIT 10;


-- 13. Delivery delay vs review score correlation
SELECT
    CASE
        WHEN delivery_diff <= -7 THEN '1. 7+ days early'
        WHEN delivery_diff <= 0  THEN '2. On time or early'
        WHEN delivery_diff <= 7  THEN '3. Up to 7 days late'
        ELSE                          '4. 7+ days late'
    END    AS delivery_status,
    COUNT(*)   AS orders,
    ROUND(AVG(r.review_score)::NUMERIC, 2) AS avg_review_score,
    ROUND(SUM(CASE WHEN r.review_score = 5 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*)::NUMERIC, 2)    AS five_star_pct,
    ROUND(SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*)::NUMERIC, 2)    AS negative_pct
FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
JOIN (
    SELECT
        order_id,
        EXTRACT(EPOCH FROM (
            order_delivered_customer_date - order_estimated_delivery_date
        )) / 86400      AS delivery_diff
    FROM orders
    WHERE order_status = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
) delivery ON o.order_id = delivery.order_id
GROUP BY CASE
    WHEN delivery_diff <= -7 THEN '1. 7+ days early'
    WHEN delivery_diff <= 0  THEN '2. On time or early'
    WHEN delivery_diff <= 7  THEN '3. Up to 7 days late'
    ELSE                          '4. 7+ days late'
END
ORDER BY delivery_status;


-- 14. Monthly revenue growth rate using LAG
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp)::DATE AS month,
        ROUND(SUM(oi.price)::NUMERIC, 2)                      AS revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    AND DATE_TRUNC('month', o.order_purchase_timestamp) 
        BETWEEN '2017-01-01' AND '2018-08-01'
    GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
)
SELECT
    month,
    revenue,
    LAG(revenue) OVER (ORDER BY month)                        AS prev_month_revenue,
    ROUND((revenue - LAG(revenue) OVER (ORDER BY month))
        * 100.0 / LAG(revenue) OVER (ORDER BY month)::NUMERIC, 2) AS mom_growth_pct,
    ROUND(SUM(revenue) OVER (ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)::NUMERIC, 2)   AS running_total
FROM monthly_revenue
ORDER BY month;



-- 15. Seller performance ranking using RANK and NTILE
WITH seller_stats AS (
    SELECT
        oi.seller_id,
        s.seller_state,
        ROUND(SUM(oi.price)::NUMERIC, 2)         AS total_revenue,
        COUNT(DISTINCT oi.order_id)              AS total_orders,
        ROUND(AVG(oi.price)::NUMERIC, 2)         AS avg_order_value,
        ROUND(AVG(r.review_score)::NUMERIC, 2)   AS avg_review_score
    FROM order_items oi
    JOIN orders o      ON oi.order_id  = o.order_id
    JOIN sellers s     ON oi.seller_id = s.seller_id
    LEFT JOIN order_reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.seller_id, s.seller_state
    HAVING COUNT(DISTINCT oi.order_id) >= 10
)
SELECT
    seller_id,
    seller_state,
    total_revenue,
    total_orders,
    avg_order_value,
    avg_review_score,
    RANK() OVER (ORDER BY total_revenue DESC)    AS revenue_rank,
    NTILE(4) OVER (ORDER BY total_revenue DESC)  AS revenue_quartile
FROM seller_stats
ORDER BY revenue_rank
LIMIT 20;


-- 16. Customer order frequency cohorts
WITH customer_frequency AS (
    SELECT
        c.customer_unique_id,
        COUNT(o.order_id)                        AS order_count,
        ROUND(SUM(oi.price)::NUMERIC, 2)         AS total_spent,
        ROUND(AVG(oi.price)::NUMERIC, 2)         AS avg_order_value,
        MIN(o.order_purchase_timestamp)::DATE    AS first_order,
        MAX(o.order_purchase_timestamp)::DATE    AS last_order
    FROM customers c
    JOIN orders o      ON c.customer_id   = o.customer_id
    JOIN order_items oi ON o.order_id     = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT
    CASE
        WHEN order_count = 1 THEN '1 order'
        WHEN order_count = 2 THEN '2 orders'
        WHEN order_count = 3 THEN '3 orders'
        ELSE '4+ orders'
    END   AS frequency_segment,
    COUNT(*)    AS customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ()::NUMERIC, 2) AS pct_of_customers,
    ROUND(AVG(total_spent)::NUMERIC, 2)       AS avg_lifetime_value,
    ROUND(AVG(avg_order_value)::NUMERIC, 2)   AS avg_order_value
FROM customer_frequency
GROUP BY CASE
    WHEN order_count = 1 THEN '1 order'
    WHEN order_count = 2 THEN '2 orders'
    WHEN order_count = 3 THEN '3 orders'
    ELSE '4+ orders'
END
ORDER BY frequency_segment;