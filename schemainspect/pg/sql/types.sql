WITH extension_oids AS (SELECT objid
                        FROM pg_depend d
                        WHERE d.refclassid = 'pg_extension'::REGCLASS
                          AND d.classid = 'pg_type'::REGCLASS)

SELECT n.nspname                                 AS schema
     , pg_catalog.format_type(t.oid, NULL)       AS name
     , t.typname                                 AS internal_name
     , CASE
    WHEN t.typrelid != 0
        THEN CAST('tuple' AS pg_catalog.TEXT)
    WHEN t.typlen < 0
        THEN CAST('var' AS pg_catalog.TEXT)
    ELSE CAST(t.typlen AS pg_catalog.TEXT)
    END                                          AS size
     ,
    -- pg_catalog.array_to_string (
    --   ARRAY(
    --     SELECT e.enumlabel
    --       FROM pg_catalog.pg_enum e
    --       WHERE e.enumtypid = t.oid
    --       ORDER BY e.oid ), E'\n'
    --   ) AS columns,
    pg_catalog.obj_description(t.oid, 'pg_type') AS description
     , (ARRAY_TO_JSON(ARRAY(
        SELECT JSONB_BUILD_OBJECT('attribute', attname, 'type', a.typname)
        FROM pg_class
        JOIN pg_attribute ON (attrelid = pg_class.oid)
        JOIN pg_type a ON (atttypid = a.oid)
        WHERE (pg_class.reltype = t.oid)
                      )))                        AS columns
FROM pg_catalog.pg_type t
LEFT JOIN pg_catalog.pg_namespace n
              ON n.oid = t.typnamespace
WHERE (
    t.typrelid = 0
        OR (SELECT c.relkind = 'c'
            FROM pg_catalog.pg_class c
            WHERE c.oid = t.typrelid)
    )
  AND NOT EXISTS (SELECT 1
                  FROM pg_catalog.pg_type el
                  WHERE el.oid = t.typelem
                    AND el.typarray = t.oid)
  AND n.nspname <> 'pg_catalog'
  AND n.nspname <> 'information_schema'
  AND pg_catalog.pg_type_is_visible(t.oid)
  AND t.typcategory = 'C'
  AND t.oid NOT IN (SELECT * FROM extension_oids)
ORDER BY 1, 2;
