python -c "
import pymysql
conn = pymysql.connect(host='127.0.0.1', port=9306)
cur = conn.cursor()
cur.execute('DROP TABLE IF EXISTS products')
cur.execute('''
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
''')
print('Таблица создана')
conn.close()
"
