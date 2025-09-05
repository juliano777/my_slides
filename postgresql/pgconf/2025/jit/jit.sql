-- Check jit settings
SELECT
    name, vartype, context, setting
FROM pg_settings
WHERE name ~ '^jit';

/*
          name           | vartype |      context      | setting 
-------------------------+---------+-------------------+---------
 jit                     | bool    | user              | on
 jit_above_cost          | real    | user              | 100000
 jit_debugging_support   | bool    | superuser-backend | off
 jit_dump_bitcode        | bool    | superuser         | off
 jit_expressions         | bool    | user              | on
 jit_inline_above_cost   | real    | user              | 500000
 jit_optimize_above_cost | real    | user              | 500000
 jit_profiling_support   | bool    | superuser-backend | off
 jit_provider            | string  | postmaster        | llvmjit
 jit_tuple_deforming     | bool    | user              | on
*/

-- Create and access the test database
DROP DATABASE IF EXISTS db_jit;
CREATE DATABASE db_jit;
\c db_jit

-- Crete small table (OLTP case)
CREATE TABLE tb_small AS
SELECT
    i AS id,
    md5(i::text) AS data
FROM generate_series(1, 10000) AS i;

/*
Only 10,000 lines
*/

-- Collect statistics from tb_small
ANALYZE tb_small;


-- Pre-setting parameters to speed up heavy data INSERT
/* WARNING!!!
DON'T DO THIS IN PRODUCTION ENVIRONMENT!
*/
SET synchronous_commit = off;
SET maintenance_work_mem = '2GB';
ALTER SYSTEM SET fsync TO OFF;
ALTER SYSTEM SET full_page_writes TO OFF;
SELECT pg_reload_conf();

-- Create large table (OLAP case)
CREATE TABLE tb_big (
    id_ serial primary key,
    group_id integer,
    data text,
    value numeric
);

-- Generate data for tb_big
INSERT INTO tb_big (group_id, data, value)
SELECT
    g AS group_id,
    md5(i::text) AS data,
    random() * 1000 AS value
FROM generate_series(1, 1000) AS g,
    generate_series(1, 100000) AS i;
    
/*
100,000,000 lines inserted
*/

-- Collect statistics from tb_big    
ANALYZE tb_big;

-- Reset parameters
RESET synchronous_commit;
RESET maintenance_work_mem;
ALTER SYSTEM RESET fsync;
ALTER SYSTEM RESET full_page_writes;
SELECT pg_reload_conf();

/*
******************************************************************************

Let the games (tests) begin!!!

██████████████████████████████████▓▓▓▓▓▓▓▓▓▓▓▓▓▓████████████████████████
██████████████████████▒▒▒▒▒▒▒▒▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓██████████████████
██████████████████▓▓▒▒▒▒▒▒▒▒▒▒▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░▓▓██████████████
████████████████▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░▓▓████████████
██████████████▒▒▒▒░░▒▒▒▒▒▒░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░▒▒░░░░░░░░░░▓▓██████████
████████████▒▒▒▒░░▒▒▒▒▒▒▒▒░░▒▒▒▒▒▒▒▒░░▒▒▒▒▒▒░░░░░░░░░░░░░░░░░░▓▓████████
██████████▒▒▒▒▒▒░░▒▒░░░░░░░░░░░░▒▒▒▒░░▒▒░░░░░░░░░░░░░░░░░░░░░░░░████████
██████████░░▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░▒▒░░░░▒▒░░░░░░░░░░░░░░▒▒░░░░░░░░████████
████████▓▓▒▒░░░░▒▒▒▒▒▒▒▒░░░░░░░░▒▒░░░░▒▒░░░░░░░░░░░░░░░░░░░░░░  ░░██████
████████░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░▒▒░░░░░░░░░░░░░░░░░░▒▒▒▒░░░░░░░░░░██████
██████▓▓▒▒░░░░░░▒▒▒▒▒▒▒▒░░░░▒▒▒▒░░▒▒▒▒░░░░░░░░▒▒▒▒▒▒▒▒░░░░░░░░░░░░██████
██████░░░░░░░░░░░░░░░░░░░░░░░░▒▒▒▒░░░░░░░░░░▒▒░░▒▒░░░░░░░░░░░░  ░░▒▒████
████░░░░░░░░░░▒▒░░░░░░░░░░░░░░░░▒▒▒▒▒▒░░░░▒▒░░░░▒▒    ░░░░░░░░░░  ░░████
████░░░░░░▒▒▓▓████▓▓▓▓▓▓░░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒░░░░▒▒▓▓▓▓████▓▓▒▒░░  ▓▓██
████░░▒▒▓▓██████▓▓▓▓▓▓▓▓██▒▒░░░░░░░░▓▓▓▓░░░░░░░░██▓▓▓▓▒▒▒▒████▓▓▒▒░░████
████▓▓▒▒▒▒▓▓████▓▓▓▓██▓▓████░░░░░░░░▒▒▒▒░░░░░░████▓▓▓▓▓▓░░▓▓██▓▓░░░░████
████▒▒▒▒▓▓▓▓████▓▓▓▓▓▓▓▓████▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒████▓▓▓▓▓▓▒▒████▓▓░░░░▓▓██
████▒▒▒▒▒▒▓▓▓▓██████▓▓██████░░▒▒▒▒▒▒▒▒▒▒░░░░░░████▓▓▓▓▓▓████▓▓▒▒░░░░▓▓██
████▓▓▓▓▓▓▒▒▓▓▓▓▓▓██████▓▓▒▒▒▒▒▒▒▒░░▒▒░░░░░░░░▒▒████████▓▓▓▓▒▒░░▒▒▒▒░░██
██▓▓░░░░▒▒▓▓██▒▒▒▒▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░░░░░░░░░▒▒▓▓▓▓▒▒▒▒▒▒▓▓▓▓░░▒▒██
██░░▓▓▓▓▒▒▒▒▒▒▓▓▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░░░░░░░    ░░░░░░░░▒▒░░▒▒▓▓▒▒░░░░░░▓▓
██░░░░▒▒▓▓▓▓▒▒▓▓▓▓▒▒▒▒▒▒░░▒▒░░░░░░░░░░░░      ░░░░░░░░▒▒▒▒▓▓▒▒▒▒▓▓▓▓▒▒▒▒
▓▓▒▒▒▒▒▒░░▓▓▓▓▒▒▓▓▒▒▒▒▒▒░░░░░░░░░░░░░░░░      ░░░░░░░░▒▒▓▓▓▓▒▒▓▓░░
▓▓▒▒▒▒▓▓▒▒▒▒▓▓▒▒▓▓▓▓▒▒▒▒░░░░░░░░░░░░░░░░      ░░░░░░▒▒▒▒██▒▒▓▓▓▓░░▒▒▒▒▒▒
▓▓▒▒░░░░▓▓░░▓▓▓▓▒▒▓▓▒▒▒▒░░░░░░░░░░░░░░░░        ░░▒▒▒▒▓▓▓▓▒▒▓▓▒▒▒▒░░  ░░
██▒▒▒▒░░▒▒▓▓▒▒▓▓▒▒▓▓▒▒▒▒░░░░░░░░░░░░░░░░        ░░░░▒▒▓▓▓▓▒▒▓▓░░▓▓  ▒▒
██▒▒▒▒▒▒▒▒▓▓░░▓▓▒▒▓▓▒▒▒▒▒▒░░░░░░░░░░░░░░      ░░░░▒▒▒▒▒▒▓▓░░▓▓░░▓▓░░░░▓▓
██▓▓▓▓▓▓▓▓▒▒▒▒▓▓▒▒▓▓▒▒▒▒▒▒▒▒░░░░░░░░░░░░    ░░▒▒▒▒▒▒▒▒▒▒▓▓▒▒▓▓░░▒▒▒▒░░██
████▓▓▒▒▒▒▓▓▓▓▒▒▓▓▒▒▒▒▓▓▒▒▒▒░░░░░░░░░░░░      ░░▓▓▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▒▒████
██████████▓▓▒▒▒▒▒▒▒▒██▓▓▓▓▒▒░░░░░░░░░░░░      ░░░░░░▒▒▒▒░░▒▒▒▒▓▓████████
██████████████░░░░░░▒▒██▓▓▓▓██▓▓░░░░░░░░    ▓▓▒▒▒▒▓▓▓▓▒▒░░  ▒▒██████████
████████████████░░░░░░▓▓▓▓▓▓▓▓▓▓▓▓▒▒░░░░▒▒▓▓▓▓▓▓▓▓▒▒▒▒      ████████████
████████████████░░░░░░▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒▒▒▒▒░░      ░░████████████
████████████████░░░░░░▒▒░░▒▒▒▒░░▒▒▒▒▒▒▒▒▒▒░░░░░░▒▒        ██████████████
████████████████▒▒░░░░▒▒░░░░░░░░░░░░▒▒▒▒░░░░░░░░▒▒░░    ▒▒██████████████
██████████████████░░░░▒▒░░░░░░░░░░▒▒▒▒▒▒▒▒░░░░  ▓▓░░    ████████████████
██████████████████░░░░▒▒░░░░░░░░░░▒▒▒▒▒▒▒▒░░░░  ▓▓░░  ▓▓████████████████
██████████████████░░░░▒▒░░░░░░    ▒▒▒▒▒▒░░░░░░  ▓▓░░░░██████████████████
██████████████████▓▓▒▒▒▒░░░░░░  ░░░░▒▒▒▒░░░░░░  ▓▓░░▒▒██████████████████
██████████████████████▓▓░░░░░░░░░░░░▒▒▒▒░░░░░░  ██▓▓████▓▓▓▓▓▓██████████
██████████████████████▓▓░░░░░░░░  ░░▒▒▒▒░░░░░░  ▓▓▓▓▓▓▓▓▓▓▒▒▓▓██████████
██████████████████████▓▓▒▒▒▒▒▒░░░░░░▒▒▒▒░░░░  ▒▒▓▓▓▓▓▓▓▓▓▓▒▒▓▓██████████
████████████████████▓▓▓▓▓▓▓▓▓▓▒▒▒▒▓▓▓▓▓▓▓▓▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▒▒████████████
████████████████████▓▓▓▓▓▓▓▓▓▓▒▒▓▓▓▓▓▓▓▓▓▓▓▓██▓▓▓▓▓▓▓▓▓▓▓▓▒▒████████████
████████████████████▓▓▓▓▓▓▓▓▓▓▒▒▓▓▓▓▓▓██████▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒████████████
████████████████████▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒████████████
████████████████████▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒░░░░░░░░░░██████████████████████████
████████████████████▓▓▒▒▒▒▓▓▓▓▓▓▒▒▒▒░░░░░░░░░░██████████████████████████
████████████████████▓▓▒▒▒▒▓▓▓▓▓▓▒▒░░░░░░░░░░▓▓██████████████████████████
████████████████████▓▓▓▓▓▓▓▓▓▓▓▓▒▒░░░░░░░░▒▒████████████████████████████
████████████████████▓▓██▓▓▓▓▓▓▓▓▒▒░░░░▒▒▓▓██████████████████████████████
██████████████████████████▓▓▒▒▒▒░░░░░░▒▒▒▒██████████████████████████████
██████████████████████████▓▓▓▓▒▒▒▒▒▒▒▒▒▒▓▓██████████████████████████████
██████████████████████████▓▓▓▓▒▒▒▒░░▒▒▓▓████████████████████████████████


******************************************************************************
*/

-- ___________________________________________________________________________

-- 1) Simple query: should be faster without JIT -----------------------------

-- JIT disabled
SET jit = off;

EXPLAIN (ANALYZE, VERBOSE, BUFFERS, TIMING, SUMMARY)
SELECT count(*) FROM tb_small WHERE id % 2 = 0;

/*
                                                     QUERY PLAN                                                      
---------------------------------------------------------------------------------------------------------------------
 Aggregate  (cost=234.12..234.13 rows=1 width=8) (actual time=4.830..4.836 rows=1 loops=1)
   Output: count(*)
   Buffers: shared read=84
   ->  Seq Scan on public.tb_small  (cost=0.00..234.00 rows=50 width=0) (actual time=0.344..4.574 rows=5000 loops=1)
         Output: id, data
         Filter: ((tb_small.id % 2) = 0)
         Rows Removed by Filter: 5000
         Buffers: shared read=84
 Planning:
   Buffers: shared hit=13 read=12
 Planning Time: 4.762 ms
 Execution Time: 4.878 ms
*/

/*
As expected, no jit...
*/

-- Testing with JIT enabled
SET jit = on;

/*
                                                     QUERY PLAN                                                      
---------------------------------------------------------------------------------------------------------------------
 Aggregate  (cost=234.12..234.13 rows=1 width=8) (actual time=1.810..1.810 rows=1 loops=1)
   Output: count(*)
   Buffers: shared hit=84
   ->  Seq Scan on public.tb_small  (cost=0.00..234.00 rows=50 width=0) (actual time=0.014..1.424 rows=5000 loops=1)
         Output: id, data
         Filter: ((tb_small.id % 2) = 0)
         Rows Removed by Filter: 5000
         Buffers: shared hit=84
 Planning Time: 0.060 ms
 Execution Time: 1.833 ms
*/


/*
Note that the total cost was 234.13, even enabling the jit it wasn't used.
*/


-- So lets set a very low value:
SET jit_above_cost = 100;


/*
                                                           QUERY PLAN                                                           
--------------------------------------------------------------------------------------------------------------------------------
 Aggregate  (cost=234.12..234.13 rows=1 width=8) (actual time=39.650..39.651 rows=1 loops=1)
   Output: count(*)
   Buffers: shared hit=84
   ->  Seq Scan on public.tb_small  (cost=0.00..234.00 rows=50 width=0) (actual time=38.815..39.429 rows=5000 loops=1)
         Output: id, data
         Filter: ((tb_small.id % 2) = 0)
         Rows Removed by Filter: 5000
         Buffers: shared hit=84
 Planning Time: 0.061 ms
 JIT:
   Functions: 4
   Options: Inlining false, Optimization false, Expressions true, Deforming true
   Timing: Generation 0.814 ms (Deform 0.048 ms), Inlining 0.000 ms, Optimization 4.828 ms, Emission 33.978 ms, Total 39.620 ms
 Execution Time: 310.791 ms
*/

/*
It can be seen that since the JIT was *forced* to lower the cost, it acted
accordingly.
And because it's a very simple query, in a table with few records, and with
very low cost, it's noticeable that there was a performance degradation.
In other words, in this case, it's not worth it.
*/


-- Reseting jit_above_cost parameter:
RESET jit_above_cost;

-- Show the current value:
SHOW jit_above_cost;

/*
jit_above_cost 
----------------
 100000
*/

-- ___________________________________________________________________________

-- 2) Analytical query with heavy aggreations --------------------------------

-- JIT enabled
SET jit = on;

EXPLAIN (ANALYZE, VERBOSE, BUFFERS, TIMING, SUMMARY)
SELECT
    group_id,
    sum(value),
    avg(value),
    stddev(value)
FROM tb_big
GROUP BY group_id;

/*
                                                                           QUERY PLAN                                                                            
-----------------------------------------------------------------------------------------------------------------------------------------------------------------
 Finalize GroupAggregate  (cost=1761159.63..1761435.48 rows=1000 width=100) (actual time=11395.890..11407.840 rows=1000 loops=1)
. . .
 Planning Time: 0.102 ms
 JIT:
   Functions: 21
   Options: Inlining true, Optimization true, Expressions true, Deforming true
   Timing: Generation 1.528 ms (Deform 0.516 ms), Inlining 141.393 ms, Optimization 90.930 ms, Emission 74.638 ms, Total 308.490 ms
 Execution Time: 11408.726 ms
*/

-- JIT disabled
SET jit = off;

/*
. . .
 Planning Time: 0.104 ms
 Execution Time: 12338.758 ms
*/

/*
Due to the volume and complexity of the query, using JIT was beneficial
*/

-- 3) Fine tuning of cost parameters -----------------------------------------
SET jit = on;
SET jit_above_cost = 100000000;

EXPLAIN (ANALYZE, VERBOSE, BUFFERS, TIMING, SUMMARY)
SELECT
    group_id,
    sum(value),
    avg(value),
    stddev(value)
FROM tb_big
GROUP BY group_id;

/*
. . .
 Execution Time: 12355.448 ms
*/

/*
Since the cost was increased significantly for the jit_above_cost parameter,
the JIT wasn't triggered
*/

-- Test: force use of JIT even in simple queries
SET jit_above_cost = 0;

EXPLAIN (ANALYZE, VERBOSE, BUFFERS, TIMING, SUMMARY)
SELECT count(*) FROM tb_small;

/*
. . .
 JIT:
   Functions: 2
   Options: Inlining false, Optimization false, Expressions true, Deforming true
   Timing: Generation 0.167 ms (Deform 0.000 ms), Inlining 0.000 ms, Optimization 0.146 ms, Emission 1.669 ms, Total 1.982 ms
 Execution Time: 3.688 ms
*/

-- Disabling jit again:
SET jit = off;

/*
. . .
 Execution Time: 1.775 ms
*/

/*
The performance difference is striking!
It's become quite clear that something so simple shouldn't use the JIT.
OK, that last one was just one query, but imagine several of them using the
JIT unnecessarily, compiling, and putting more stress on the CPU...
*/

-- ___________________________________________________________________________

-- 4) PL/pgSQL function ------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_complex(a int8, b int8, c int8)
RETURNS int AS $$
BEGIN
  RETURN (a * b + c) % 1000;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;

-- Enabling jit
SET jit = on;

-- Complex CTE with aggreations, UDF and window functions
EXPLAIN (ANALYZE, VERBOSE, BUFFERS, TIMING, SUMMARY)
WITH filtered_data AS (
  SELECT *
  FROM tb_big
  WHERE fn_complex(group_id, id_, value::int) BETWEEN 100 AND 200
),
agg_data AS (
  SELECT
    group_id,
    COUNT(*) AS total,
    AVG(value) AS avg_,
    SUM(fn_complex(group_id, id_, value::int)) AS sum_fn,
    MAX(length(data)) AS maior_hash
  FROM filtered_data
  GROUP BY group_id
),
window_ AS (
  SELECT *,
    RANK() OVER (ORDER BY sum_fn DESC) AS rank_fn,
    DENSE_RANK() OVER (ORDER BY avg_ DESC) AS rank_avg
  FROM agg_data
)
SELECT *
FROM window_
WHERE rank_fn <= 10 OR rank_avg <= 10
ORDER BY rank_fn, rank_avg;

/*
 Planning Time: 0.278 ms
 JIT:
   Functions: 17
   Options: Inlining true, Optimization true, Expressions true, Deforming true
   Timing: Generation 1.593 ms (Deform 0.516 ms), Inlining 22.360 ms, Optimization 98.847 ms, Emission 63.428 ms, Total 186.227 ms
 Execution Time: 106986.590 ms
*/


-- Desabling jit
SET jit = off;

/*
 Planning Time: 0.258 ms
 Execution Time: 121131.089 ms
*/

-- ___________________________________________________________________________

-- 5) Aggregation with CASE --------------------------------------------------

SET jit = on;

EXPLAIN (ANALYZE, BUFFERS)
SELECT
  CASE                             
    WHEN value < 10 THEN 'below 10'
    WHEN value < 20 THEN 'below 20'
    WHEN value < 30 THEN 'below 30'
    WHEN value < 40 THEN 'below 40'
    WHEN value < 50 THEN 'below 50'
    WHEN value < 60 THEN 'below 60'
    WHEN value < 70 THEN 'below 70'
    WHEN value < 80 THEN 'below 80'
    WHEN value < 90 THEN 'below 90'
    WHEN value < 100 THEN 'below 100'
    WHEN value < 200 THEN 'below 200'
    WHEN value < 300 THEN 'below 300'
    WHEN value < 400 THEN 'below 400'
    WHEN value < 500 THEN 'below 500'
    WHEN value < 600 THEN 'below 600'
    WHEN value < 700 THEN 'below 700'
    WHEN value < 800 THEN 'below 800'
    WHEN value < 900 THEN 'below 900'
    WHEN value < 1000 THEN 'below 1000' 
    WHEN value < 2000 THEN 'below 2000'
    WHEN value < 3000 THEN 'below 3000' 
    WHEN value < 4000 THEN 'below 4000' 
    WHEN value < 5000 THEN 'below 5000' 
    WHEN value < 6000 THEN 'below 6000'
    WHEN value < 7000 THEN 'below 7000' 
    WHEN value < 8000 THEN 'below 8000' 
    WHEN value < 9000 THEN 'below 9000' 
    WHEN value < 10000 THEN 'below 10000' 
    ELSE 'above 10000'
  END AS range_values,
  COUNT(*) AS total_lines,
  SUM(value) AS sum_values
FROM tb_big
GROUP BY range_values
ORDER BY range_values;


/*
 JIT:
   Functions: 9
   Options: Inlining true, Optimization true, Expressions true, Deforming true
   Timing: Generation 2.504 ms (Deform 0.281 ms), Inlining 140.600 ms, Optimization 93.168 ms, Emission 91.448 ms, Total 327.719 ms
 Execution Time: 69525.110 ms
*/

SET jit = off;

/*
Execution Time: 74517.337 ms
*/

-- Reset JIT values
RESET jit;
RESET jit_above_cost;
RESET jit_optimize_above_cost;
RESET jit_inline_above_cost;
