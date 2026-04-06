<<<<<<< HEAD
АНОМАЛИИ НА ДАННЫХ orders_raw (1000 строк):

1. АНОМАЛИЯ ВСТАВКИ (Insert Anomaly)
   Нельзя создать заказ без товаров — нарушается бизнес-логика.
   Пример: Попытка вставить заказ с NULL product_names:
   INSERT INTO orders_raw 
   VALUES (1001, '2026-04-01', 'Петров П.П.', 'petrov@email.com', '+7(999)123-45-67',
           'Москва, ул.Ленина 10', NULL, NULL, NULL, 0, 'new');
   ОШИБКА: total_amount вычисляется из product_prices*quantities

2. АНОМАЛИЯ ОБНОВЛЕНИЯ (Update Anomaly)
   Клиент "Иванов И.И." в 10+ заказах сменил email:
   UPDATE orders_raw SET customer_email = 'ivanov_new@domain.ru' 
   WHERE customer_name = 'Иванов И.И.';
   ПРОБЛЕМА: 10+ UPDATE вместо 1 записи в customers

3. АНОМАЛИЯ УДАЛЕНИЯ (Delete Anomaly)
   Клиент "Сидоров С.С." сделал единственный заказ #500:
   DELETE FROM orders_raw WHERE order_id = 500;
   ПРОБЛЕМА: Потеряна информация о клиенте навсегда 
=======

>>>>>>> 81d479d2e3b45f850828763c607878d605306a27
