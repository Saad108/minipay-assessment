# Database Query Performance Optimization & Analysis

## 1. Problem Identification: Inefficient Access Pattern

### Unoptimized Query (Before)
The initial implementation for fetching daily transaction aggregations performed full table scans combined with non-indexed timestamp casting:

```sql
SELECT 
    DATE(created_at) AS date,
    status,
    COUNT(*),
    SUM(amount)
FROM transactions
WHERE DATE(created_at) >= '2026-09-01'
GROUP BY DATE(created_at), status;