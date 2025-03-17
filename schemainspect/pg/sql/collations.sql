SELECT collname     AS name
     , n.nspname    AS schema
     , CASE collprovider
    WHEN 'd' THEN 'database default'
    WHEN 'i' THEN 'icu'
    WHEN 'c' THEN 'libc'
    END
                    AS provider
     , collencoding AS encoding
     ,
    -- 17_OR_LATER coalesce(collcollate, colllocale) as lc_collate,
    -- 17_OR_LATER coalesce(collctype, colllocale) as lc_ctype,
    -- 15_OR_16 coalesce(collcollate, colliculocale) as lc_collate,
    -- 15_OR_16 coalesce(collctype, colliculocale) as lc_ctype,
    -- 14_OR_BELOW collcollate as lc_collate,
    -- 14_OR_BELOW collctype as lc_ctype,
    collversion     AS version
FROM pg_collation c
INNER JOIN pg_namespace n
               ON n.oid = c.collnamespace
-- SKIP_INTERNAL where nspname not in ('pg_internal', 'pg_catalog', 'information_schema', 'pg_toast')
-- SKIP_INTERNAL and nspname not like 'pg_temp_%' and nspname not like 'pg_toast_temp_%'
ORDER BY 2, 1
