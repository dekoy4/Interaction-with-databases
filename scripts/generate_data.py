import psycopg2
import random
from faker import Faker
from datetime import datetime, timedelta

fake = Faker('ru_RU')
random.seed(42)

conn = psycopg2.connect(
    host="localhost",
    port=5432,
    dbname="idz1",
    user="postgres",
    password="password"
)
cur = conn.cursor()

products = [
    ("Ноутбук Dell XPS", 85000),
    ("Мышь Logitech", 1500),
    ("Клавиатура", 5000),
    ("Коврик", 500),
    ("Монитор 27\"", 25000),
    ("SSD 1TB", 8000),
    ("HDMI кабель", 300),
    ("Веб-камера", 3500),
]

statuses = ['new', 'processing', 'shipped', 'delivered', 'cancelled']

for i in range(1, 1001):
    customer_name = fake.name()
    customer_email = fake.email()
    customer_phone = fake.phone_number()[:15]
    delivery_address = f"г. Москва, ул. Ленина {random.randint(1, 100)}"

    num_items = random.randint(1, 3)
    items = random.choices(products, k=num_items)

    product_names = ', '.join([name for name, _ in items])
    product_prices = ', '.join([str(price) for _, price in items])
    product_quantities = ', '.join([str(random.randint(1, 2)) for _ in items])
    total_amount = sum(price * random.randint(1, 2) for _, price in items)
    order_date = fake.date_between(start_date='-2y', end_date='today')
    status = random.choice(statuses)

    cur.execute("""
        INSERT INTO orders_raw VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """, (i, order_date, customer_name, customer_email, customer_phone,
          delivery_address, product_names, product_prices, product_quantities,
          total_amount, status))

    if i % 100 == 0:
        print(f"✅ {i} строк добавлено...")

conn.commit()
cur.close()
conn.close()
print("✅ Генерация завершена: 1000 строк в таблице orders_raw!")