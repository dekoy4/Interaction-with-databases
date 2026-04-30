-- 08_triggers.sql
-- Триггеры для поддержания согласованности denormalized поля orders.customer_name

-- 1. Функция для обновления orders.customer_name при изменении customers.name
CREATE OR REPLACE FUNCTION update_customer_name_in_orders()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE orders
    SET customer_name = NEW.name
    WHERE customer_id = NEW.customer_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Триггер на обновление имени клиента
CREATE TRIGGER trig_update_customer_name
    AFTER UPDATE OF name ON customers
    FOR EACH ROW
    EXECUTE FUNCTION update_customer_name_in_orders();

-- 3. Опционально: триггер на создание/изменение заказа, чтобы сразу копировать имя
-- (если хочешь, что имя заказа всегда соответствует актуальному name клиента)
CREATE OR REPLACE FUNCTION copy_customer_name_to_order()
RETURNS TRIGGER AS $$
DECLARE
    c_name TEXT;
BEGIN
    SELECT name INTO c_name FROM customers WHERE customer_id = NEW.customer_id;
    NEW.customer_name = c_name;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Триггер BEFORE INSERT/UPDATE в orders для копирования имени клиента
CREATE TRIGGER trig_copy_customer_name
    BEFORE INSERT OR UPDATE OF customer_id ON orders
    FOR EACH ROW
    EXECUTE FUNCTION copy_customer_name_to_order();