import random
from datetime import datetime, timedelta
import csv

START_DATE = datetime(2023, 1, 1)
END_DATE = datetime(2024, 12, 31)
USERS = [
    ('SunnyWalker_88', 'sunny.walker88@test.example'),
    ('PixelPioneer', 'pixel.pioneer@test.example'),
    ('MistyDawn_42', 'misty.dawn42@test.example'),
    ('CryptoKoi', 'crypto.koi@test.example'),
    ('LunaTic_77', 'luna.tic77@test.example'),
    ('SteelPhantom', 'steel.phantom@test.example'),
    ('VelvetRogue', 'velvet.rogue@test.example'),
    ('NeonFalcon_23', 'neon.falcon23@test.example'),
    ('QuietStorm', 'quiet.storm@test.example'),
    ('ByteBard', 'byte.bard@test.example')
]
PRODUCTS = [
    (1, 'Laptop Pro', 'Electronics', 1500.00),
    (2, 'Smartphone X', 'Electronics', 800.00),
    (3, 'Headphones', 'Accessories', 150.00),
    (4, 'Keyboard', 'Accessories', 100.00),
    (5, 'Mouse', 'Accessories', 50.00),
    (6, 'Monitor', 'Electronics', 400.00),
    (7, 'Office Desk', 'Furniture', 300.00),
    (8, 'Office Chair', 'Furniture', 250.00),
    (9, 'Lamp', 'Decor', 80.00),
    (10, 'Phone Case', 'Accessories', 20.00),
]

REGIONS = ['North', 'South', 'East', 'West', 'Central', 'International']
ORDER_STATUSES = ['new', 'processing', 'shipped', 'delivered', 'cancelled']

def generate_customers(n):
    customers = []
    for i in range(1, n + 1):
        customer = random.choice(USERS)
        customer_name, customer_email = customer
        customers.append({
            'id': i,
            'name': customer_name,
            'email': customer_email
        })
    return customers

def random_date(start, end):
    return start + timedelta(days=random.randint(0, (end - start).days))

def random_datetime(start, end):
    delta = end - start
    random_seconds = random.randint(0, int(delta.total_seconds()))
    return start + timedelta(seconds=random_seconds)

def generate_test_data(num_rows=1000):
    customers = generate_customers(10)
    data = []
    
    for order_id in range(1, num_rows + 1):
        customer = random.choice(customers)
        
        order_datetime = random_datetime(START_DATE, END_DATE)
        order_date = order_datetime.date()
        
        product = random.choice(PRODUCTS)
        product_id, product_name, category, price = product
        
        quantity = random.randint(1, 10)
        line_total = price * quantity
        
        status_weights = [0.05, 0.10, 0.15, 0.60, 0.10]
        order_status = random.choices(ORDER_STATUSES, weights=status_weights)[0]
        
        region = random.choice(REGIONS)
        
        data.append({
            'order_date': order_date,
            'order_datetime': order_datetime,
            'order_id': order_id,
            'customer_id': customer['id'],
            'customer_name': customer['name'],
            'customer_email': customer['email'],
            'region': region,
            'product_id': product_id,
            'product_name': product_name,
            'category': category,
            'quantity': quantity,
            'price': price,
            'line_total': line_total,
            'order_status': order_status
        })
    
    return data

def generate_ttl_test_data(num_rows=1000):
    customers = generate_customers(10)
    data = []
    
    for order_id in range(1, num_rows + 1):
        customer = random.choice(customers)
        
        order_datetime = random_datetime(START_DATE, END_DATE)
        order_date = order_datetime.date()
        
        product = random.choice(PRODUCTS)
        product_id, product_name, category, price = product
        
        quantity = random.randint(1, 10)
        line_total = price * quantity
        
        status_weights = [0.05, 0.10, 0.15, 0.60, 0.10]
        order_status = random.choices(ORDER_STATUSES, weights=status_weights)[0]
        
        region = random.choice(REGIONS)
        
        inserted_at = random_inserted_date(min_days_old=91)
        
        data.append({
            'order_date': order_date,
            'order_datetime': order_datetime,
            'order_id': order_id,
            'customer_id': customer['id'],
            'customer_name': customer['name'],
            'customer_email': customer['email'],
            'region': region,
            'product_id': product_id,
            'product_name': product_name,
            'category': category,
            'quantity': quantity,
            'price': price,
            'line_total': line_total,
            'order_status': order_status,
            'inserted_at': inserted_at
        })
    
    return data

def random_inserted_date(min_days_old=91):
    current_date = datetime.now().replace(microsecond=0)
    days_ago = random.randint(min_days_old, 365)
    return current_date - timedelta(days=days_ago)

def generate_insert_sql(data, filename):
    with open(filename, 'w', encoding='utf-8') as sqlfile:
        sqlfile.write("INSERT INTO test_db.orders_flat FORMAT VALUES\n")
        
        for row in data:
            sql = f"('{row['order_date']}', '{row['order_datetime']}', {row['order_id']}, " \
                  f"{row['customer_id']}, '{row['customer_name']}', '{row['customer_email']}', " \
                  f"'{row['region']}', {row['product_id']}, '{row['product_name']}', " \
                  f"'{row['category']}', {row['quantity']}, {row['price']}, " \
                  f"{row['line_total']}, '{row['order_status']}'),\n"
            sqlfile.write(sql)
    
    print(f"SQL script saved to {filename}")

def generate_ttl_insert_sql(data, filename):
    with open(filename, 'w', encoding='utf-8') as sqlfile:
        sqlfile.write("INSERT INTO test_db.orders_ttl FORMAT VALUES\n")
        
        for row in data:
            sql = f"('{row['order_date']}', '{row['order_datetime']}', {row['order_id']}, " \
                  f"{row['customer_id']}, '{row['customer_name']}', '{row['customer_email']}', " \
                  f"'{row['region']}', {row['product_id']}, '{row['product_name']}', " \
                  f"'{row['category']}', {row['quantity']}, {row['price']}, " \
                  f"{row['line_total']}, '{row['order_status']}', '{row['inserted_at']}'),\n"
            sqlfile.write(sql)
    
    print(f"SQL script saved to {filename}")

if __name__ == "__main__":
    print("Generating test data...")
    
    test_data = generate_test_data(1000000)
    ttl_test_data = generate_ttl_test_data(1000)
    
    generate_insert_sql(test_data, 'insert_orders.sql')
    generate_ttl_insert_sql(ttl_test_data, 'ttl_insert_orders.sql')
    
    print(f"\nData generated")
