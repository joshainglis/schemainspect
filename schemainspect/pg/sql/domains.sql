WITH extension_oids AS (SELECT objid
                        FROM pg_depend d
                        WHERE d.refclassid = 'pg_extension'::REGCLASS
                          AND d.classid = 'pg_type'::REGCLASS)
SELECT n.nspname                                                                                       AS "schema"
     , t.typname                                                                                       AS "name"
     , pg_catalog.format_type(t.typbasetype, t.typtypmod)                                              AS "data_type"
     , (SELECT c.collname
        FROM pg_catalog.pg_collation c, pg_catalog.pg_type bt
        WHERE c.oid = t.typcollation AND bt.oid = t.typbasetype AND t.typcollation <> bt.typcollation) AS "collation"
     , rr.conname                                                                                      AS "constraint_name"
     , t.typnotnull                                                                                    AS "not_null"
     , t.typdefault                                                                                    AS "default"
     , pg_catalog.array_to_string(ARRAY(
                                          SELECT pg_catalog.pg_get_constraintdef(r.oid, TRUE) FROM pg_catalog.pg_constraint r WHERE t.oid = r.contypid
                                  ), ' ')                                                              AS "check"
FROM pg_catalog.pg_type t
LEFT JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
LEFT JOIN pg_catalog.pg_constraint rr ON t.oid = rr.contypid
WHERE t.typtype = 'd'
  AND n.nspname <> 'pg_catalog'
  AND n.nspname <> 'information_schema'
  AND pg_catalog.pg_type_is_visible(t.oid)
  AND t.oid NOT IN (SELECT * FROM extension_oids)
ORDER BY 1, 2;
