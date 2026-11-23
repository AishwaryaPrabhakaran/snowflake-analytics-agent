-- Total revenue by region for orders placed in 1997.
-- Revenue = net line revenue, SUM(L_EXTENDEDPRICE * (1 - L_DISCOUNT)), the TPC-H standard definition (before tax).
-- Region = the customer's region (customer -> nation -> region).
SELECT
    r.r_name AS region,
    ROUND(SUM(l.l_extendedprice * (1 - l.l_discount)), 2) AS total_revenue
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM l
JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS o   ON o.o_orderkey = l.l_orderkey
JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER c ON c.c_custkey = o.o_custkey
JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.NATION n   ON n.n_nationkey = c.c_nationkey
JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.REGION r   ON r.r_regionkey = n.n_regionkey
WHERE o.o_orderdate >= '1997-01-01'
  AND o.o_orderdate <  '1998-01-01'
GROUP BY r.r_name
ORDER BY total_revenue DESC;
