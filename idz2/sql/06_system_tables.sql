SELECT
    column,
    formatReadableSize(sum(data_compressed_bytes)) AS compressed,
    formatReadableSize(sum(data_uncompressed_bytes)) AS uncompressed,
    round(sum(data_uncompressed_bytes) / sum(data_compressed_bytes), 2) AS ratio
FROM system.parts_columns
WHERE database = 'test_db' AND table = 'orders_flat' AND active
GROUP BY column
ORDER BY sum(data_uncompressed_bytes) DESC;
