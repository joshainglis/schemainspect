WITH things1            AS (SELECT oid                                     AS objid
                                 , pronamespace                            AS namespace
                                 , proname                                 AS name
                                 , PG_GET_FUNCTION_IDENTITY_ARGUMENTS(oid) AS identity_arguments
                                 , PG_GET_FUNCTION_RESULT(oid)             AS result
                                 , 'f'                                     AS kind
                                 , NULL::OID                               AS composite_type_oid
                            FROM pg_proc
                            -- 11_AND_LATER where pg_proc.prokind != 'a'
                            -- 10_AND_EARLIER where pg_proc.proisagg is False
                            UNION
                            SELECT oid
                                 , relnamespace AS namespace
                                 , relname      AS name
                                 , NULL         AS identity_arguments
                                 , NULL         AS result
                                 , relkind      AS kind
                                 , NULL::OID    AS composite_type_oid
                            FROM pg_class
                            WHERE oid NOT IN (SELECT ftrelid
                                              FROM pg_foreign_table)
                            UNION
                            SELECT oid
                                 , typnamespace  AS namespace
                                 , typname       AS name
                                 , NULL          AS identity_arguments
                                 , NULL          AS result
                                 , 'c'           AS kind
                                 , typrelid::OID AS composite_type_oid
                            FROM pg_type
                            WHERE typrelid != 0)
   , extension_objids   AS (SELECT objid AS extension_objid
                            FROM pg_depend d
                            WHERE d.refclassid = 'pg_extension'::REGCLASS
                            UNION
                            SELECT t.typrelid AS extension_objid
                            FROM pg_depend d
                            JOIN pg_type t ON t.oid = d.objid
                            WHERE d.refclassid = 'pg_extension'::REGCLASS)
   , things             AS (SELECT objid
                                 , kind
                                 , n.nspname AS schema
                                 , name
                                 , identity_arguments
                                 , result
                                 , t.composite_type_oid
                            FROM things1 t
                            INNER JOIN      pg_namespace n
                                                ON t.namespace = n.oid
                            LEFT OUTER JOIN extension_objids
                                                ON t.objid = extension_objids.extension_objid
                            WHERE kind IN ('r', 'v', 'm', 'c', 'f')
                              AND nspname NOT IN ('pg_internal', 'pg_catalog', 'information_schema', 'pg_toast')
                              AND nspname NOT LIKE 'pg_temp_%'
                              AND nspname NOT LIKE 'pg_toast_temp_%'
                              AND extension_objids.extension_objid IS NULL)
   , array_dependencies AS (SELECT att.attrelid      AS objid
                                 , att.attname       AS column_name
                                 , tbl.typelem       AS composite_type_oid
                                 , comp_tbl.typrelid AS objid_dependent_on
                            FROM pg_attribute att
                            JOIN pg_type tbl ON tbl.oid = att.atttypid
                            JOIN pg_type comp_tbl ON tbl.typelem = comp_tbl.oid
                            WHERE tbl.typcategory = 'A')
   , combined           AS (SELECT DISTINCT
                                   COALESCE(t.composite_type_oid, t.objid)
                                ,  t.schema
                                ,  t.name
                                ,  t.identity_arguments
                                ,  t.result
                                ,  CASE WHEN t.composite_type_oid IS NOT NULL THEN 'r' ELSE t.kind END
                                ,  things_dependent_on.objid              AS objid_dependent_on
                                ,  things_dependent_on.schema             AS schema_dependent_on
                                ,  things_dependent_on.name               AS name_dependent_on
                                ,  things_dependent_on.identity_arguments AS identity_arguments_dependent_on
                                ,  things_dependent_on.result             AS result_dependent_on
                                ,  things_dependent_on.kind               AS kind_dependent_on
                            FROM pg_depend d
                            INNER JOIN things things_dependent_on
                                           ON d.refobjid = things_dependent_on.objid
                            INNER JOIN pg_rewrite rw
                                           ON d.objid = rw.oid
                                           AND things_dependent_on.objid != rw.ev_class
                            INNER JOIN things t
                                           ON rw.ev_class = t.objid
                            WHERE d.deptype IN ('n')
                              AND rw.rulename = '_RETURN'
                            UNION ALL
                            SELECT DISTINCT
                                   COALESCE(t.composite_type_oid, t.objid)
                                ,  t.schema
                                ,  t.name
                                ,  t.identity_arguments
                                ,  t.result
                                ,  CASE WHEN t.composite_type_oid IS NOT NULL THEN 'r' ELSE t.kind END
                                ,  things_dependent_on.objid              AS objid_dependent_on
                                ,  things_dependent_on.schema             AS schema_dependent_on
                                ,  things_dependent_on.name               AS name_dependent_on
                                ,  things_dependent_on.identity_arguments AS identity_arguments_dependent_on
                                ,  things_dependent_on.result             AS result_dependent_on
                                ,  things_dependent_on.kind               AS kind_dependent_on
                            FROM pg_depend d
                            INNER JOIN things things_dependent_on
                                           ON d.refobjid = things_dependent_on.objid
                            INNER JOIN things t
                                           ON d.objid = t.objid
                            WHERE d.deptype IN ('n')
                            UNION ALL
                            SELECT COALESCE(t.composite_type_oid, t.objid)
                                 , t.schema
                                 , t.name
                                 , t.identity_arguments
                                 , t.result
                                 , CASE WHEN t.composite_type_oid IS NOT NULL THEN 'r' ELSE t.kind END
                                 , things_dependent_on.objid              AS objid_dependent_on
                                 , things_dependent_on.schema             AS schema_dependent_on
                                 , things_dependent_on.name               AS name_dependent_on
                                 , things_dependent_on.identity_arguments AS identity_arguments_dependent_on
                                 , things_dependent_on.result             AS result_dependent_on
                                 , things_dependent_on.kind               AS kind_dependent_on
                            FROM array_dependencies ad
                            INNER JOIN things things_dependent_on
                                           ON ad.objid_dependent_on = things_dependent_on.objid
                            INNER JOIN things t
                                           ON ad.objid = t.objid)
SELECT *
FROM combined
ORDER BY schema
       , name
       , identity_arguments
       , result
       , kind_dependent_on
       , schema_dependent_on
       , name_dependent_on
       , identity_arguments_dependent_on
       , result_dependent_on
