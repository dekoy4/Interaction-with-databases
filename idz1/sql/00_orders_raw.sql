-- 00_orders_raw.sql — UNF таблица
DROP TABLE IF EXISTS orders_raw;

CREATE TABLE orders_raw (
    order_id        INTEGER PRIMARY KEY,
    order_date      DATE,
    customer_name   TEXT,
    customer_email  TEXT,
    customer_phone  TEXT,
    delivery_address TEXT,
    product_names   TEXT,          
    product_prices  TEXT,          
    product_quantities TEXT,       
    total_amount    NUMERIC,
    status          TEXT           
);

-- Пока пустая, наполним генератором 
