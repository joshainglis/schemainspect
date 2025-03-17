WITH extension_objids AS (SELECT objid AS extension_objid
                          FROM pg_depend d
                          WHERE d.refclassid = 'pg_extension'::REGCLASS
                            AND d.classid = 'pg_class'::REGCLASS)
   , pre              AS (SELECT n.nspname                       AS schema
                               , c.relname                       AS name
                               , c_ref.relname                   AS table_name
                               , a.attname                       AS column_name
                               ,
                              --a.attname is not null as has_table_owner,
                              --a.attidentity is distinct from '' as is_identity,
                              d.deptype IS NOT DISTINCT FROM 'i' AS is_identity
                          --a.attidentity = 'a' as is_identity_always
                          FROM
                              --pg_sequence s

                              --inner join pg_class c
                              --    on s.seqrelid = c.oid

                              pg_class c

                              INNER JOIN pg_catalog.pg_namespace n
                                             ON n.oid = c.relnamespace

                              LEFT JOIN  extension_objids
                                             ON c.oid = extension_objids.extension_objid

                              LEFT JOIN  pg_depend d
                                             ON c.oid = d.objid AND d.deptype IN ('i', 'a')

                              LEFT JOIN  pg_class c_ref
                                             ON d.refobjid = c_ref.oid

                              LEFT JOIN  pg_attribute a
                                             ON (a.attnum = d.refobjsubid
                                             AND a.attrelid = d.refobjid)

                          WHERE c.relkind = 'S'
                            -- SKIP_INTERNAL and n.nspname not in ('pg_internal', 'pg_catalog', 'information_schema', 'pg_toast')
                            -- SKIP_INTERNAL and n.nspname not like 'pg_temp_%' and n.nspname not like 'pg_toast_temp_%'
                            AND extension_objids.extension_objid IS NULL)
SELECT *
FROM pre
WHERE NOT is_identity
ORDER BY 1
       , 2;
