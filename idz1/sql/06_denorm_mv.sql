-- sql/06_denorm_mv.sql
-- Денормализация через материализованное представление

-- MV: ежемесячные продажи по товару и категории
DROP MATERIALIZED VIEW IF EXISTS mv_monthly_sales;

CREATE MATERIALIZED VIEW mv_monthly_sales AS
SELECT
    DATE_TRUNC('month', o.order_date) AS month,
    p.name AS product_name,
    c.name AS category_name,
    SUM(oi.quantity) AS total_qty,
    SUM(oi.quantity * oi.price_at_order) AS total_revenue
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
JOIN products p ON p.product_id = oi.product_id
JOIN categories c ON c.category_id = p.category_id
GROUP BY 1, 2, 3;

-- Индекс для ускорения отчёта
CREATE INDEX IF NOT EXISTS idx_mv_monthly_sales_month
ON mv_monthly_sales(month, total_revenue DESC);