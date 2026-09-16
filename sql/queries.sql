-- =============================================================================
-- MiniPay Database Investigation & Analytical Queries
-- Dialect: PostgreSQL / Standard ANSI SQL
-- =============================================================================

-- 1. Transaction count and total value by status and day
SELECT 
    DATE_TRUNC('day', created_at)::DATE AS transaction_date,
    status,
    COUNT(*) AS total_transaction_count,
    COALESCE(SUM(amount), 0) AS total_transaction_value
FROM transactions
GROUP BY DATE_TRUNC('day', created_at)::DATE, status
ORDER BY transaction_date DESC, status;

-- 2. Top 10 customers by successful transaction value
SELECT 
    customer_id,
    COUNT(*) AS total_successful_transactions,
    SUM(amount) AS total_successful_value
FROM transactions
WHERE status = 'SUCCESS'
GROUP BY customer_id
ORDER BY total_successful_value DESC
LIMIT 10;

-- 3. Transactions that have remained in 'PROCESSING' for more than 15 minutes
SELECT 
    id AS transaction_id,
    reference,
    customer_id,
    amount,
    created_at,
    NOW() - created_at AS elapsed_processing_time
FROM transactions
WHERE status = 'PROCESSING'
  AND created_at < NOW() - INTERVAL '15 minutes'
ORDER BY created_at ASC;

-- 4. Duplicate transaction references
SELECT 
    reference,
    COUNT(*) AS occurrence_count,
    ARRAY_AGG(id) AS transaction_ids,
    MIN(created_at) AS first_seen,
    MAX(created_at) AS last_seen
FROM transactions
GROUP BY reference
HAVING COUNT(*) > 1
ORDER BY occurrence_count DESC;

-- 5. Daily success rate as a percentage
SELECT 
    DATE_TRUNC('day', created_at)::DATE AS transaction_date,
    COUNT(*) AS total_transactions,
    COUNT(*) FILTER (WHERE status = 'SUCCESS') AS successful_transactions,
    ROUND(
        (COUNT(*) FILTER (WHERE status = 'SUCCESS')::DECIMAL / NULLIF(COUNT(*), 0)) * 100, 
        2
    ) AS success_rate_percentage
FROM transactions
GROUP BY DATE_TRUNC('day', created_at)::DATE
ORDER BY transaction_date DESC;

-- 6. Reconciliation: successful transaction count/value vs callback-success count/value
SELECT 
    DATE_TRUNC('day', t.created_at)::DATE AS transaction_date,
    COUNT(DISTINCT t.id) FILTER (WHERE t.status = 'SUCCESS') AS db_success_count,
    COALESCE(SUM(t.amount) FILTER (WHERE t.status = 'SUCCESS'), 0) AS db_success_value,
    COUNT(DISTINCT c.transaction_id) FILTER (WHERE c.callback_status = 'SUCCESS') AS callback_success_count,
    COALESCE(SUM(t.amount) FILTER (WHERE c.callback_status = 'SUCCESS'), 0) AS callback_success_value,
    (COUNT(DISTINCT t.id) FILTER (WHERE t.status = 'SUCCESS') - 
     COUNT(DISTINCT c.transaction_id) FILTER (WHERE c.callback_status = 'SUCCESS')) AS count_discrepancy,
    (COALESCE(SUM(t.amount) FILTER (WHERE t.status = 'SUCCESS'), 0) - 
     COALESCE(SUM(t.amount) FILTER (WHERE c.callback_status = 'SUCCESS'), 0)) AS value_discrepancy
FROM transactions t
LEFT JOIN transaction_callbacks c ON t.id = c.transaction_id
GROUP BY DATE_TRUNC('day', t.created_at)::DATE
ORDER BY transaction_date DESC;

-- 7. Average and p95 processing time where timestamps permit calculation
WITH processing_durations AS (
    SELECT 
        id,
        created_at,
        updated_at,
        EXTRACT(EPOCH FROM (updated_at - created_at)) AS duration_seconds
    FROM transactions
    WHERE status IN ('SUCCESS', 'FAILED')
      AND updated_at IS NOT NULL 
      AND updated_at >= created_at
)
SELECT 
    ROUND(AVG(duration_seconds)::NUMERIC, 2) AS avg_processing_time_seconds,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_seconds)::NUMERIC, 2) AS p95_processing_time_seconds
FROM processing_durations;