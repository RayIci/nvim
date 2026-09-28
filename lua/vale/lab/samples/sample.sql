-- Inventory report sample for vale
/* TODO: add index on sku */
CREATE TABLE IF NOT EXISTS items (
    id          INTEGER PRIMARY KEY,
    sku         VARCHAR(8) NOT NULL UNIQUE,
    price       NUMERIC(10, 2) DEFAULT 0.00,
    active      BOOLEAN DEFAULT TRUE,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

WITH recent AS (
    SELECT sku, price, created_at
    FROM items
    WHERE active = TRUE
      AND created_at >= NOW() - INTERVAL '30 days'
      AND sku LIKE 'ABC-%'
)
SELECT
    r.sku,
    ROUND(AVG(r.price), 2) AS avg_price,
    COUNT(*) AS total,
    CASE WHEN COUNT(*) > 100 THEN 'high' ELSE 'low' END AS volume
FROM recent AS r
GROUP BY r.sku
HAVING COUNT(*) >= 1
ORDER BY avg_price DESC
LIMIT 50;
