WITH extension_oids AS (SELECT objid
                        FROM pg_depend d
                        WHERE d.refclassid = 'pg_extension'::REGCLASS
                          AND d.classid = 'pg_type'::REGCLASS)
SELECT n.nspname AS "schema"
     , t.typname AS "name"
     , ARRAY(
        SELECT e.enumlabel
        FROM pg_catalog.pg_enum e
        WHERE e.enumtypid = t.oid
        ORDER BY e.enumsortorder
       )         AS elements
FROM pg_catalog.pg_type t
LEFT JOIN       pg_catalog.pg_namespace n ON n.oid = t.typnamespace
LEFT OUTER JOIN extension_oids e
                    ON t.oid = e.objid
WHERE t.typcategory = 'E'
  AND e.objid IS NULL
-- SKIP_INTERNAL and n.nspname not in ('pg_internal', 'pg_catalog', 'information_schema', 'pg_toast')
-- SKIP_INTERNAL and n.nspname not like 'pg_temp_%' and n.nspname not like 'pg_toast_temp_%'
ORDER BY 1, 2;
