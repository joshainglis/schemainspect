WITH extension_oids AS (SELECT objid
                        FROM pg_depend d
                        WHERE d.refclassid = 'pg_extension'::REGCLASS)
   , enums          AS (SELECT t.oid                               AS enum_oid
                             , n.nspname                           AS "schema"
                             , pg_catalog.format_type(t.oid, NULL) AS "name"
                        FROM pg_catalog.pg_type t
                        LEFT JOIN       pg_catalog.pg_namespace n ON n.oid = t.typnamespace
                        LEFT OUTER JOIN extension_oids e
                                            ON t.oid = e.objid
                        WHERE t.typcategory = 'E'
                          AND e.objid IS NULL
                          -- SKIP_INTERNAL and n.nspname not in ('pg_catalog', 'information_schema', 'pg_toast')
                          -- SKIP_INTERNAL and n.nspname not like 'pg_temp_%' and n.nspname not like 'pg_toast_temp_%'
                          AND pg_catalog.pg_type_is_visible(t.oid)
                        ORDER BY 1, 2)
   , r              AS (SELECT c.relname                      AS name
                             , n.nspname                      AS schema
                             , c.relkind                      AS relationtype
                             , c.oid                          AS oid
                             , CASE WHEN c.relkind IN ('m', 'v') THEN
                                        PG_GET_VIEWDEF(c.oid)
                                    ELSE NULL END
                                                              AS definition
                             , NULL
                                                              AS parent_table
                             , NULL                           AS partition_def
                             , c.relrowsecurity::BOOLEAN      AS rowsecurity
                             , c.relforcerowsecurity::BOOLEAN AS forcerowsecurity
                             , c.relpersistence               AS persistence
                             , c.relpages                     AS page_size_estimate
                             , c.reltuples                    AS row_count_estimate
                        FROM pg_catalog.pg_class c
                        INNER JOIN      pg_catalog.pg_namespace n
                                            ON n.oid = c.relnamespace
                        LEFT OUTER JOIN extension_oids e
                                            ON c.oid = e.objid
                        WHERE c.relkind IN ('r', 'v', 'm', 'c', 'p')
    -- SKIP_INTERNAL and e.objid is null
    -- SKIP_INTERNAL and n.nspname not in ('pg_catalog', 'information_schema', 'pg_toast')
    -- SKIP_INTERNAL and n.nspname not like 'pg_temp_%' and n.nspname not like 'pg_toast_temp_%'
)
SELECT r.relationtype
     , r.schema
     , r.name
     , r.definition                                                                               AS definition
     , a.attnum                                                                                   AS position_number
     , a.attname                                                                                  AS attname
     , a.attnotnull                                                                               AS not_null
     , a.atttypid::REGTYPE                                                                        AS datatype
     , FALSE                                                                                      AS is_identity
     , FALSE                                                                                      AS is_identity_always
     , FALSE                                                                                      AS is_generated
     , (SELECT c.collname
        FROM pg_catalog.pg_collation c, pg_catalog.pg_type t
        WHERE c.oid = a.attcollation AND t.oid = a.atttypid AND a.attcollation <> t.typcollation) AS collation
     , PG_GET_EXPR(ad.adbin, ad.adrelid)                                                          AS defaultdef
     , r.oid                                                                                      AS oid
     , FORMAT_TYPE(atttypid, atttypmod)                                                           AS datatypestring
     , e.enum_oid IS NOT NULL                                                                     AS is_enum
     , e.name                                                                                     AS enum_name
     , e.schema                                                                                   AS enum_schema
     , pg_catalog.obj_description(r.oid)                                                          AS comment
     , r.parent_table
     , r.partition_def
     , r.rowsecurity
     , r.forcerowsecurity
     , r.persistence
     , r.page_size_estimate
     , r.row_count_estimate
FROM r
LEFT JOIN pg_catalog.pg_attribute a
              ON r.oid = a.attrelid AND a.attnum > 0
LEFT JOIN pg_catalog.pg_attrdef ad
              ON a.attrelid = ad.adrelid
              AND a.attnum = ad.adnum
LEFT JOIN enums e
              ON a.atttypid = e.enum_oid
WHERE a.attisdropped IS NOT TRUE
-- SKIP_INTERNAL and r.schema not in ('pg_catalog', 'information_schema', 'pg_toast')
-- SKIP_INTERNAL and r.schema not like 'pg_temp_%' and r.schema not like 'pg_toast_temp_%'
ORDER BY relationtype, r.schema, r.name, position_number;
