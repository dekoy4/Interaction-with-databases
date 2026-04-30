import random
import time
import json
from faker import Faker
import pymysql

fake = Faker(['ru_RU', 'en_US'])

CATEGORIES = ['Electronics', 'Smartphones', 'Laptops', 'Tablets', 'Headphones', 
              'Speakers', 'TVs', 'Cameras', 'Gaming', 'Accessories']
BRANDS = ['Samsung', 'Apple', 'Xiaomi', 'Sony', 'LG', 'JBL', 'Bose', 'Asus', 'Dell', 'HP']
COLORS = ['black', 'white', 'silver', 'gold', 'blue', 'red']

def generate_product(pid):
    category = random.choice(CATEGORIES)
    brand = random.choice(BRANDS)
    
    title = f"{brand} {fake.word()} {category}"
    
    keywords = ['wireless', 'bluetooth', 'noise cancelling', 'portable', 'gaming',
                'headphones', 'speaker', 'laptop', 'phone']
    selected_keywords = random.sample(keywords, random.randint(2, 3))
    description = f"{fake.sentence()} {' '.join(selected_keywords)}. {fake.sentence()}"
    
    tags = json.dumps({
        'color': random.choice(COLORS),
        'material': random.choice(['plastic', 'metal']),
        'warranty': random.choice([12, 24])
    })
    
    return (
        pid,
        title,
        description,
        category,
        brand,
        round(random.uniform(1000, 150000), 2),
        round(random.uniform(1, 5), 1),
        random.randint(0, 10000),
        random.choice([0, 1]),
        tags,
        time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(time.time() - random.randint(1, 31536000)))
    )

def main():
    print(" Подключение к Manticore...")
    conn = pymysql.connect(host='127.0.0.1', port=9306, autocommit=True)
    cursor = conn.cursor()
    
    # Создание таблицы (упрощенная)
    cursor.execute("DROP TABLE IF EXISTS products")
    cursor.execute("""
        CREATE TABLE products (
            id bigint,
            title text indexed,
            description text indexed,
            category string,
            brand string,
            price float,
            rating float,
            reviews_count integer,
            in_stock bool,
            tags json,
            created_at timestamp
        ) min_word_len='2' html_strip='1'
    """)
    print(" Таблица создана")
    
    total = 100000
    batch_size = 500
    
    print(f" Загрузка {total:,} товаров...")
    start_time = time.time()
    
    insert_query = """
        INSERT INTO products (id, title, description, category, brand, 
        price, rating, reviews_count, in_stock, tags, created_at)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """
    
    for i in range(0, total, batch_size):
        batch = []
        for j in range(batch_size):
            if i + j >= total:
                break
            batch.append(generate_product(i + j + 1))
        
        cursor.executemany(insert_query, batch)
        
        loaded = min(i + batch_size, total)
        if loaded % 10000 == 0 or loaded == total:
            elapsed = time.time() - start_time
            speed = loaded / elapsed if elapsed > 0 else 0
            print(f" Загружено: {loaded:6,}/{total:,} ({loaded*100/total:.1f}%) | {speed:.0f} зап/сек")
    
    # Проверка
    cursor.execute("SELECT COUNT(*) FROM products")
    count = cursor.fetchone()[0]
    total_time = time.time() - start_time
    
    print(f"\n Загружено: {count:,} записей")
    print(f" Время: {total_time:.2f} сек")
    print(f" Скорость: {total/total_time:.0f} зап/сек")
    
    cursor.close()
    conn.close()

if __name__ == "__main__":
    main()
