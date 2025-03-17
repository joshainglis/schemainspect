WITH extension_oids AS (SELECT objid
                        FROM pg_depend d
                        WHERE d.refclassid = 'pg_extension'::REGCLASS
                          AND d.classid = 'pg_namespace'::REGCLASS)
SELECT nspname AS schema
FROM pg_catalog.pg_namespace
LEFT OUTER JOIN extension_oids e
                    ON e.objid = oid
-- SKIP_INTERNAL where nspname not in ('pg_internal', 'pg_catalog', 'information_schema', 'pg_toast')
-- SKIP_INTERNAL and nspname not like 'pg_temp_%' and nspname not like 'pg_toast_temp_%'
-- SKIP_INTERNAL and e.objid is null
ORDER BY 1;
