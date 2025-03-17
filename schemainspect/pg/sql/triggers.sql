WITH extension_oids         AS (SELECT objid
                                FROM pg_depend d
                                WHERE d.refclassid = 'pg_extension'::REGCLASS
                                  AND d.classid = 'pg_trigger'::REGCLASS)
   , partition_child_tables AS (SELECT inhrelid
                                FROM pg_inherits)
SELECT tg.tgname                                AS "name"
     , nsp.nspname                              AS "schema"
     , cls.relname                              AS table_name
     , PG_GET_TRIGGERDEF(tg.oid)                AS full_definition
     , proc.proname                             AS proc_name
     , nspp.nspname                             AS proc_schema
     , tg.tgenabled                             AS enabled
     , tg.oid IN (SELECT * FROM extension_oids) AS extension_owned
FROM pg_trigger tg
JOIN pg_class cls ON cls.oid = tg.tgrelid
JOIN pg_namespace nsp ON nsp.oid = cls.relnamespace
JOIN pg_proc proc ON proc.oid = tg.tgfoid
JOIN pg_namespace nspp ON nspp.oid = proc.pronamespace
WHERE NOT tg.tgisinternal
  AND cls.oid NOT IN (SELECT * FROM partition_child_tables) -- Exclude partition child tables
-- SKIP_INTERNAL and not tg.oid in (select * from extension_oids)
ORDER BY schema, table_name, name;
