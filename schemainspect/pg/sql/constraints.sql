WITH extension_oids AS (SELECT objid
                        FROM pg_depend d
                        WHERE d.refclassid = 'pg_extension'::REGCLASS
                          AND d.classid = 'pg_constraint'::REGCLASS)
   , extension_rels AS (SELECT objid
                        FROM pg_depend d
                        WHERE d.refclassid = 'pg_extension'::REGCLASS
                          AND d.classid = 'pg_class'::REGCLASS)
   , indexes        AS (SELECT schemaname AS schema
                             , tablename  AS table_name
                             , indexname  AS name
                             , indexdef   AS definition
                             , indexdef   AS create_statement
                        FROM pg_indexes
                        -- SKIP_INTERNAL where schemaname not in ('pg_catalog', 'information_schema', 'pg_toast')
                        -- SKIP_INTERNAL and schemaname not like 'pg_temp_%' and schemaname not like 'pg_toast_temp_%'
                        ORDER BY schemaname
                               , tablename
                               , indexname)
SELECT nspname                                 AS schema
     , conname                                 AS name
     , relname                                 AS table_name
     , PG_GET_CONSTRAINTDEF(pg_constraint.oid) AS definition
     , CASE contype
    WHEN 'c' THEN 'CHECK'
    WHEN 'f' THEN 'FOREIGN KEY'
    WHEN 'p' THEN 'PRIMARY KEY'
    WHEN 'u' THEN 'UNIQUE'
    WHEN 'x' THEN 'EXCLUDE'
    END                                        AS constraint_type
     , i.name                                  AS index
     , e.objid                                 AS extension_oid
     , CASE WHEN contype = 'f' THEN
                (SELECT nspname
                 FROM pg_catalog.pg_class AS c
                 JOIN pg_catalog.pg_namespace AS ns
                          ON c.relnamespace = ns.oid
                 WHERE c.oid = confrelid::REGCLASS)
    END                                        AS foreign_table_schema
     , CASE WHEN contype = 'f' THEN
                (SELECT relname
                 FROM pg_catalog.pg_class c
                 WHERE c.oid = confrelid::REGCLASS)
    END                                        AS foreign_table_name
     , CASE WHEN contype = 'f' THEN
                (SELECT ARRAY_AGG(ta.attname ORDER BY c.rn)
                 FROM pg_attribute ta
                 JOIN UNNEST(conkey) WITH ORDINALITY c(cn, rn)
                          ON
                          ta.attrelid = conrelid AND ta.attnum = c.cn)
    END                                        AS fk_columns_local
     , CASE WHEN contype = 'f' THEN
                (SELECT ARRAY_AGG(ta.attname ORDER BY c.rn)
                 FROM pg_attribute ta
                 JOIN UNNEST(confkey) WITH ORDINALITY c(cn, rn)
                          ON
                          ta.attrelid = confrelid AND ta.attnum = c.cn)
    END                                        AS fk_columns_foreign
     , contype = 'f'                           AS is_fk
     , condeferrable                           AS is_deferrable
     , condeferred                             AS initially_deferred
     , pg_class.relkind                        AS table_relkind
     , pg_class.relispartition                 AS is_partition
FROM pg_constraint
INNER JOIN      pg_class
                    ON conrelid = pg_class.oid
INNER JOIN      pg_namespace
                    ON pg_namespace.oid = pg_class.relnamespace
LEFT OUTER JOIN indexes i
                    ON nspname = i.schema
                    AND conname = i.name
                    AND relname = i.table_name
LEFT OUTER JOIN extension_oids e
                    ON pg_class.oid = e.objid
LEFT OUTER JOIN extension_rels er
                    ON er.objid = conrelid
LEFT OUTER JOIN extension_rels cr
                    ON cr.objid = confrelid
WHERE contype IN ('c', 'f', 'p', 'u', 'x')
-- SKIP_INTERNAL and nspname not in ('pg_internal', 'pg_catalog', 'information_schema', 'pg_toast', 'pg_temp_1', 'pg_toast_temp_1')
-- SKIP_INTERNAL and e.objid is null and er.objid is null and cr.objid is null
ORDER BY 1, 3, 2;
