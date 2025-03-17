SELECT nspname    AS schema
     , extname    AS name
     , extversion AS version
     , e.oid      AS oid
FROM pg_extension e
INNER JOIN pg_namespace
               ON pg_namespace.oid = e.extnamespace
ORDER BY schema, name;
