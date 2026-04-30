#!/bin/bash
set -euo pipefail

CONTAINER="idz4_ch_s1r1"
TOTAL=2000000
BATCH=50000
BATCHES=$((TOTAL / BATCH))

PAGES=(
    "/index" "/catalog" "/product/123" "/product/456" "/cart"
    "/checkout" "/profile" "/search" "/about" "/contacts"
)
EVENTS=("click" "view" "scroll" "purchase" "search" "logout" "login")

for i in $(seq 1 $BATCHES); do
    docker exec -i "$CONTAINER" clickhouse-client --query "
        INSERT INTO events_distributed
        SELECT
            toDate(now() - toIntervalDay(rand() % 365))   AS event_date,
            now() - toIntervalSecond(rand() % 31536000)   AS event_time,
            rand() % 10000 + 1                             AS user_id,
            generateUUIDv4()                               AS session_id,
            ['click','view','scroll','purchase','search','logout','login']
                [1 + rand() % 7]                           AS event_type,
            ['/index','/catalog','/product/123','/product/456','/cart',
             '/checkout','/profile','/search','/about','/contacts']
                [1 + rand() % 10]                          AS page_url,
            rand() % 30000 + 100                           AS duration_ms
        FROM numbers($BATCH)
    "
    echo "  Batch $i/$BATCHES is done"
done
