WITH partition_child_tables AS (SELECT inhrelid
                                FROM pg_inherits)
SELECT n.nspname                    AS schema
     , c.relname                    AS name
     , CASE
    WHEN c.relkind IN ('r', 'v', 'm', 'f', 'p') THEN 'table'
    WHEN c.relkind = 'S'                        THEN 'sequence'
    ELSE NULL END                   AS object_type
     , PG_GET_USERBYID(acl.grantee) AS "user"
     , acl.privilege
     , NULL                         AS postfix
FROM pg_catalog.pg_class c
     JOIN pg_catalog.pg_namespace n
              ON n.oid = c.relnamespace
   , LATERAL (SELECT aclx.*, privilege_type AS privilege
              FROM aclexplode(c.relacl) aclx
              UNION
              SELECT aclx.*, privilege_type || '(' || a.attname || ')' AS privilege
              FROM pg_catalog.pg_attribute a
              CROSS JOIN aclexplode(a.attacl) aclx
              WHERE attrelid = c.oid AND NOT attisdropped AND attacl IS NOT NULL ) acl
WHERE acl.grantee != acl.grantor
  AND acl.grantee != 0
  AND c.relkind IN ('r', 'v', 'm', 'S', 'f', 'p')
  -- and table is not a partition child table
  AND c.oid NOT IN (SELECT inhrelid FROM partition_child_tables)
-- SKIP_INTERNAL    and nspname not in ('pg_internal', 'pg_catalog', 'information_schema', 'pg_toast')
-- SKIP_INTERNAL    and nspname not like 'pg_temp_%' and nspname not like 'pg_toast_temp_%'
UNION
SELECT routine_schema                                          AS schema
     , routine_name                                            AS name
     , 'function'                                              AS object_type
     , grantee                                                 AS "user"
     , privilege_type                                          AS privilege
     , FORMAT('(%s)', PG_GET_FUNCTION_IDENTITY_ARGUMENTS(oid)) AS postfix
FROM information_schema.role_routine_grants g
JOIN pg_catalog.pg_proc p ON g.specific_schema::REGNAMESPACE = p.pronamespace::REGNAMESPACE AND g.specific_name = FORMAT('%s_%s', p.proname, p.oid)
WHERE grantor != grantee
  AND grantee != 'PUBLIC'
-- SKIP_INTERNAL    and routine_schema not in ('pg_internal', 'pg_catalog', 'information_schema', 'pg_toast')
-- SKIP_INTERNAL    and routine_schema not like 'pg_temp_%' and routine_schema not like 'pg_toast_temp_%'
UNION
SELECT ''                           AS schema
     , n.nspname                    AS name
     , 'schema'                     AS object_type
     , PG_GET_USERBYID(acl.grantee) AS "user"
     , privilege
     , NULL                         AS postfix
FROM pg_catalog.pg_namespace n
   , LATERAL (SELECT aclx.*, privilege_type AS privilege
              FROM aclexplode(n.nspacl) aclx
              UNION
              SELECT aclx.*, privilege_type || '(' || a.attname || ')' AS privilege
              FROM pg_catalog.pg_attribute a
              CROSS JOIN aclexplode(a.attacl) aclx
              WHERE attrelid = n.oid AND NOT attisdropped AND attacl IS NOT NULL ) acl
WHERE privilege != 'CREATE'
  AND acl.grantor != acl.grantee
  AND acl.grantee != 0
-- SKIP_INTERNAL    and n.nspname not in ('pg_internal', 'pg_catalog', 'information_schema', 'pg_toast')
-- SKIP_INTERNAL    and n.nspname not like 'pg_temp_%' and n.nspname not like 'pg_toast_temp_%'
ORDER BY schema, name, "user";
