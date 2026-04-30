CREATE TABLE user_dict ON CLUSTER 'cluster_2x2' (
    user_id UInt64,
    name    String,
    segment LowCardinality(String)
) ENGINE = ReplicatedMergeTree(
    '/clickhouse/tables/{shard}/user_dict',
    '{replica}'
)
ORDER BY user_id;

-- Заполнение данными
INSERT INTO user_dict
SELECT
    number AS user_id,
    concat('User_', toString(number)) AS name,
    ['free', 'basic', 'premium', 'enterprise'][1 + (number % 4)] AS segment
FROM numbers(10001);
