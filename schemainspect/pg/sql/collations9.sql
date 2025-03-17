SELECT collname     AS name
     , n.nspname    AS schema
     , 'd'          AS provider
     , collencoding AS encoding
     , collcollate  AS lc_collate
     , collctype    AS lc_ctype
     , NULL         AS version
FROM pg_collation c
INNER JOIN pg_namespace n
               ON n.oid = c.collnamespace
-- SKIP_INTERNAL where nspname not in ('pg_internal', 'pg_catalog', 'information_schema', 'pg_toast')
-- SKIP_INTERNAL and nspname not like 'pg_temp_%' and nspname not like 'pg_toast_temp_%'
ORDER BY 2, 1
