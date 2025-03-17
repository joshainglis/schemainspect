WITH extension_oids      AS (SELECT objid
                                  , classid::REGCLASS::TEXT AS classid
                             FROM pg_depend d
                             WHERE d.refclassid = 'pg_extension'::REGCLASS
                               AND d.classid = 'pg_index'::REGCLASS)
   , extension_relations AS (SELECT objid
                             FROM pg_depend d
                             WHERE d.refclassid = 'pg_extension'::REGCLASS
                               AND d.classid = 'pg_class'::REGCLASS)
   , pre                 AS (SELECT n.nspname                       AS schema
                                  , c.relname                       AS table_name
                                  , i.relname                       AS name
                                  , i.oid                           AS oid
                                  , e.objid                         AS extension_oid
                                  , PG_GET_INDEXDEF(i.oid)          AS definition
                                  , (SELECT ARRAY_AGG(attname ORDER BY ik.n)
                                     FROM UNNEST(x.indkey) WITH ORDINALITY ik(i, n)
                                     JOIN pg_attribute aa
                                              ON
                                              aa.attrelid = x.indrelid
                                                  AND ik.i = aa.attnum)
                                                                    AS index_columns
                                  , indoption                       AS key_options
                                  , indnatts                        AS total_column_count
                                  ,
                                 -- 11_AND_LATER indnkeyatts key_column_count,
                                 -- 10_AND_EARLIER indnatts key_column_count,
                                 indnatts                           AS num_att
                                  ,
                                 -- 11_AND_LATER indnatts - indnkeyatts included_column_count,
                                 -- 10_AND_EARLIER 0 included_column_count,
                                 indisunique                        AS is_unique
                                  , indisprimary                    AS is_pk
                                  , indisexclusion                  AS is_exclusion
                                  , indimmediate                    AS is_immediate
                                  , indisclustered                  AS is_clustered
                                  , indcollation                    AS key_collations
                                  , PG_GET_EXPR(indexprs, indrelid) AS key_expressions
                                  , PG_GET_EXPR(indpred, indrelid)  AS partial_predicate
                                  , amname                          AS algorithm
                             FROM pg_index x
                             JOIN      pg_class c ON c.oid = x.indrelid
                             JOIN      pg_class i ON i.oid = x.indexrelid
                             JOIN      pg_am am ON i.relam = am.oid
                             LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
                             LEFT JOIN extension_oids e
                                           ON i.oid = e.objid
                             LEFT JOIN extension_relations er
                                           ON c.oid = er.objid
                             WHERE x.indislive
                               AND c.relkind IN ('r', 'm', 'p')
                               AND i.relkind IN ('i', 'I')
    -- SKIP_INTERNAL and nspname not in ('pg_catalog', 'information_schema', 'pg_toast')
    -- SKIP_INTERNAL and nspname not like 'pg_temp_%' and nspname not like 'pg_toast_temp_%'
    -- SKIP_INTERNAL and e.objid is null and er.objid is null
)
SELECT *
     , index_columns[1\:key_column_count]                                  AS key_columns
     , index_columns[key_column_count + 1\:array_length(index_columns, 1)] AS included_columns
FROM pre
ORDER BY 1, 2, 3;
