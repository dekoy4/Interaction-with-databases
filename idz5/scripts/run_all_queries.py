import pymysql
import time
import os
import subprocess

os.makedirs('checks', exist_ok=True)

conn = pymysql.connect(host='127.0.0.1', port=9306)
cursor = conn.cursor()

# Создание connectivity.txt
print('Создание connectivity.txt...')
date = time.strftime("%Y-%m-%d %H:%M:%S")

try:
    cursor.execute('SELECT 1')
    conn_status = 'CONNECTED'
    conn_result = str(cursor.fetchone()[0])
except Exception as e:
    conn_status = 'ERROR'
    conn_result = str(e)

# Получение статуса Docker
try:
    result = subprocess.run(['docker', 'ps', '--filter', 'name=manticore_search', '--format', 'Container: {{.Names}}\nStatus: {{.Status}}\nPorts: {{.Ports}}'], 
                           capture_output=True, text=True)
    docker_status = result.stdout.strip()
except Exception as e:
    docker_status = f'Error getting Docker status: {e}'

with open('checks/connectivity.txt', 'w', encoding='utf-8') as f:
    f.write('='*60 + '\n')
    f.write('MANTICORE CONNECTIVITY CHECK\n')
    f.write('='*60 + '\n\n')
    f.write(f'Date: {date}\n\n')
    f.write('=== Connection Method ===\n')
    f.write('MySQL Protocol: mysql -h 127.0.0.1 -P 9306\n\n')
    f.write('=== Connection Test ===\n')
    f.write(f'Status: {conn_status}\n')
    f.write(f'Test query result: {conn_result}\n\n')
    f.write('=== Docker Container ===\n')
    f.write(f'{docker_status}\n\n')
    f.write('=== HTTP API ===\n')
    f.write('Endpoint: http://localhost:9308/sql\n')
    f.write('Method: POST with query parameter\n')

print('connectivity.txt сохранен')

# Поисковые запросы
queries = [
    ('basic_search.txt', '4.1 Базовый поиск: wireless bluetooth headphones', 
     "SELECT id, price FROM products WHERE MATCH('wireless bluetooth headphones') ORDER BY WEIGHT() DESC LIMIT 10"),
    
    ('phrase_search.txt', '4.2 Поиск точной фразы: "noise cancelling"', 
     "SELECT id, price FROM products WHERE MATCH('\"noise cancelling\"') ORDER BY WEIGHT() DESC LIMIT 10"),
    
    ('proximity_search.txt', '4.3 Proximity поиск: "portable speaker"~3', 
     "SELECT id, price FROM products WHERE MATCH('\"portable speaker\"~3') ORDER BY WEIGHT() DESC LIMIT 10"),
    
    ('filtered_search.txt', '4.4 Поиск с фильтрацией: laptop, цена 30000-80000, рейтинг >=4.0', 
     "SELECT id, price, rating FROM products WHERE MATCH('laptop') AND price BETWEEN 30000 AND 80000 AND rating >= 4.0 ORDER BY rating DESC LIMIT 10"),
    
    ('facets.txt', '5. Фасетный поиск', 
     "SELECT category, COUNT(*) AS cnt, AVG(price) AS avg_price FROM products WHERE MATCH('gaming') GROUP BY category ORDER BY cnt DESC"),
    
    ('json_search.txt', '4.5 Поиск по слову phone', 
     "SELECT id, price FROM products WHERE MATCH('phone') LIMIT 10")
]

for filename, description, query in queries:
    start = time.time()
    cursor.execute(query)
    results = cursor.fetchall()
    elapsed = (time.time() - start) * 1000
    
    with open(f'checks/{filename}', 'w', encoding='utf-8') as f:
        f.write('='*60 + '\n')
        f.write(description + '\n')
        f.write('='*60 + '\n\n')
        f.write(f'Запрос:\n{query}\n\n')
        f.write(f'Время выполнения: {elapsed:.2f} мс\n')
        f.write(f'Количество результатов: {len(results)}\n\n')
        f.write('Результаты:\n')
        for i, row in enumerate(results[:10], 1):
            f.write(f'{i}. {row}\n')
    
    print(f'{filename} сохранен ({elapsed:.2f} мс)')

# UPDATE/DELETE демонстрация
cursor.execute("SELECT id, price, rating FROM products LIMIT 1")
original = cursor.fetchone()
test_id = original[0]

with open('checks/update_delete.txt', 'w', encoding='utf-8') as f:
    f.write('='*60 + '\n')
    f.write('6. UPDATE и DELETE в Manticore\n')
    f.write('='*60 + '\n\n')
    
    f.write('=== ИСХОДНАЯ ЗАПИСЬ ===\n')
    f.write(f'ID: {original[0]}, Price: {original[1]}, Rating: {original[2]}\n\n')
    
    cursor.execute(f"UPDATE products SET price = 99999.99, rating = 4.9 WHERE id = {test_id}")
    cursor.execute(f"SELECT price, rating FROM products WHERE id = {test_id}")
    updated = cursor.fetchone()
    f.write('=== ПОСЛЕ UPDATE ===\n')
    f.write(f'UPDATE products SET price = 99999.99, rating = 4.9 WHERE id = {test_id}\n')
    f.write(f'New Price: {updated[0]}, New Rating: {updated[1]}\n\n')
    
    cursor.execute(f"DELETE FROM products WHERE id = {test_id}")
    cursor.execute(f"SELECT COUNT(*) FROM products WHERE id = {test_id}")
    count = cursor.fetchone()[0]
    f.write('=== ПОСЛЕ DELETE ===\n')
    f.write(f'DELETE FROM products WHERE id = {test_id}\n')
    f.write(f'Записей с ID={test_id}: {count}\n\n')
    
    f.write('=== ПРИМЕЧАНИЕ О REPLACE ===\n')
    f.write('В Manticore нет прямой команды REPLACE.\n')
    f.write('Для замены документа нужно выполнить DELETE, а затем INSERT.\n')

print('update_delete.txt сохранен')

cursor.close()
conn.close()
print('\nВсе файлы сохранены в папке checks/')
