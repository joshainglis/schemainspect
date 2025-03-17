WITH extension_oids AS (SELECT objid
                        FROM pg_depend d
                        WHERE d.refclassid = 'pg_extension'::REGCLASS
                          AND d.classid = 'pg_proc'::REGCLASS)
   , pg_proc_pre    AS (SELECT pp.*
                        -- 11_AND_LATER , pp.oid as p_oid
                        -- 10_AND_EARLIER , pp.oid as p_oid, case when pp.proisagg then 'a' else 'f' end as prokind
                        FROM pg_proc pp)
   , routines       AS (SELECT CURRENT_DATABASE()::information_schema.SQL_IDENTIFIER            AS specific_catalog
                             , n.nspname::information_schema.SQL_IDENTIFIER                     AS specific_schema
                            --nameconcatoid(p.proname, p.oid)::information_schema.sql_identifier AS specific_name,
                             , CURRENT_DATABASE()::information_schema.SQL_IDENTIFIER            AS routine_catalog
                             , n.nspname::information_schema.SQL_IDENTIFIER                     AS schema
                             , p.proname::information_schema.SQL_IDENTIFIER                     AS name
                             , CASE p.prokind
        WHEN 'f'::"char" THEN 'FUNCTION'::TEXT
        WHEN 'p'::"char" THEN 'PROCEDURE'::TEXT
        ELSE NULL::TEXT
        END::information_schema.CHARACTER_DATA                                                  AS routine_type
                             , CASE
        WHEN p.prokind = 'p'::"char"                          THEN NULL::TEXT
        WHEN t.typelem <> 0::OID AND t.typlen = '-1'::INTEGER THEN 'ARRAY'::TEXT
        WHEN nt.nspname = 'pg_catalog'::NAME                  THEN FORMAT_TYPE(t.oid, NULL::INTEGER)
        ELSE 'USER-DEFINED'::TEXT
        END::information_schema.CHARACTER_DATA                                                  AS data_type
                             , CASE
        WHEN nt.nspname IS NOT NULL THEN CURRENT_DATABASE()
        ELSE NULL::NAME
        END::information_schema.SQL_IDENTIFIER                                                  AS type_udt_catalog
                             , nt.nspname::information_schema.SQL_IDENTIFIER                    AS type_udt_schema
                             , t.typname::information_schema.SQL_IDENTIFIER                     AS type_udt_name
                             , CASE
        WHEN p.prokind <> 'p'::"char" THEN 0
        ELSE NULL::INTEGER
        END::information_schema.SQL_IDENTIFIER                                                  AS dtd_identifier
                             , CASE
        WHEN l.lanname = 'sql'::NAME THEN 'SQL'::TEXT
        ELSE 'EXTERNAL'::TEXT
        END::information_schema.CHARACTER_DATA                                                  AS routine_body
                             , CASE
        WHEN PG_HAS_ROLE(p.proowner, 'USAGE'::TEXT) THEN p.prosrc
        ELSE NULL::TEXT
        END::information_schema.CHARACTER_DATA                                                  AS definition
                             , CASE
        WHEN l.lanname = 'c'::NAME THEN p.prosrc
        ELSE NULL::TEXT
        END::information_schema.CHARACTER_DATA                                                  AS external_name
                             , UPPER(l.lanname::TEXT)::information_schema.CHARACTER_DATA        AS external_language
                             , 'GENERAL'::CHARACTER VARYING::information_schema.CHARACTER_DATA  AS parameter_style
                             , CASE
        WHEN p.provolatile = 'i'::"char" THEN 'YES'::TEXT
        ELSE 'NO'::TEXT
        END::information_schema.YES_OR_NO                                                       AS is_deterministic
                             , 'MODIFIES'::CHARACTER VARYING::information_schema.CHARACTER_DATA AS sql_data_access
                             , CASE
        WHEN p.prokind <> 'p'::"char" THEN
            CASE
                WHEN p.proisstrict THEN 'YES'::TEXT
                ELSE 'NO'::TEXT
                END
        ELSE NULL::TEXT
        END::information_schema.YES_OR_NO                                                       AS is_null_call
                             , 'YES'::CHARACTER VARYING::information_schema.YES_OR_NO           AS schema_level_routine
                             , 0::information_schema.CARDINAL_NUMBER                            AS max_dynamic_result_sets
                             , CASE
        WHEN p.prosecdef THEN 'DEFINER'::TEXT
        ELSE 'INVOKER'::TEXT
        END::information_schema.CHARACTER_DATA                                                  AS security_type
                             , 'NO'::CHARACTER VARYING::information_schema.YES_OR_NO            AS as_locator
                             , 'NO'::CHARACTER VARYING::information_schema.YES_OR_NO            AS is_udt_dependent
                             , p.p_oid                                                          AS oid
                             , p.proisstrict
                             , p.prosecdef
                             , p.provolatile
                             , p.proargtypes
                             , p.proallargtypes
                             , p.proargnames
                             , p.proargdefaults
                             , p.proargmodes
                             , p.proowner
                             , p.prokind                                                        AS kind
                        FROM pg_namespace n
                        JOIN      pg_proc_pre p ON n.oid = p.pronamespace
                        JOIN      pg_language l ON p.prolang = l.oid
                        LEFT JOIN (pg_type t
                                JOIN pg_namespace nt ON t.typnamespace = nt.oid) ON p.prorettype = t.oid AND p.prokind <> 'p'::"char"
                        WHERE PG_HAS_ROLE(p.proowner, 'USAGE'::TEXT) OR HAS_FUNCTION_PRIVILEGE(p.p_oid, 'EXECUTE'::TEXT))
   , pgproc         AS (SELECT schema
                             , name
                             , p.oid                                            AS oid
                             , e.objid                                          AS extension_oid
                             , CASE proisstrict WHEN TRUE THEN
                                                    'RETURNS NULL ON NULL INPUT'
                                                ELSE
                                                    'CALLED ON NULL INPUT'
        END                                                                     AS strictness
                             , CASE prosecdef WHEN TRUE THEN
                                                  'SECURITY DEFINER'
                                              ELSE
                                                  'SECURITY INVOKER'
        END                                                                     AS security_type
                             , CASE provolatile
        WHEN 'i' THEN
            'IMMUTABLE'
        WHEN 's' THEN
            'STABLE'
        WHEN 'v' THEN
            'VOLATILE'
        ELSE
            NULL
        END                                                                     AS volatility
                             , p.proargtypes
                             , p.proallargtypes
                             , p.proargnames
                             , p.proargdefaults
                             , p.proargmodes
                             , p.proowner
                             , COALESCE(p.proallargtypes, p.proargtypes::OID[]) AS procombinedargtypes
                             , p.kind
                             , p.type_udt_schema
                             , p.type_udt_name
                             , p.definition
                             , p.external_language

                        FROM routines p
                        LEFT OUTER JOIN extension_oids e
                                            ON p.oid = e.objid
                        WHERE TRUE
    -- 11_AND_LATER and p.kind != 'a'
    -- SKIP_INTERNAL and schema not in ('pg_internal', 'pg_catalog', 'information_schema', 'pg_toast')
    -- SKIP_INTERNAL and schema not like 'pg_temp_%' and schema not like 'pg_toast_temp_%'
    -- SKIP_INTERNAL and e.objid is null
    -- SKIP_INTERNAL and p.external_language not in ('C', 'INTERNAL')
)
   , unnested       AS (SELECT p.*
                             , pname           AS parameter_name
                             , pnum            AS position_number
                             , CASE
        WHEN pargmode IS NULL       THEN NULL
        WHEN pargmode = 'i'::"char" THEN 'IN'::TEXT
        WHEN pargmode = 'o'::"char" THEN 'OUT'::TEXT
        WHEN pargmode = 'b'::"char" THEN 'INOUT'::TEXT
        WHEN pargmode = 'v'::"char" THEN 'IN'::TEXT
        WHEN pargmode = 't'::"char" THEN 'OUT'::TEXT
        ELSE NULL::TEXT
        END::information_schema.CHARACTER_DATA AS parameter_mode
                             , CASE
        WHEN t.typelem <> 0::OID AND t.typlen = '-1'::INTEGER THEN 'ARRAY'::TEXT
        ELSE FORMAT_TYPE(t.oid, NULL::INTEGER)
        END::information_schema.CHARACTER_DATA AS data_type
                             , CASE
        WHEN PG_HAS_ROLE(p.proowner, 'USAGE'::TEXT) THEN pg_get_function_arg_default(p.oid, pnum::INT)
        ELSE NULL::TEXT
        END::VARCHAR                           AS parameter_default
                        FROM pgproc p
                        LEFT JOIN LATERAL
                                      UNNEST(
                                              p.proargnames,
                                              p.proallargtypes,
                                              p.procombinedargtypes,
                                              p.proargmodes)
                                      WITH ORDINALITY AS uu(pname, pdatatype, pargtype, pargmode, pnum) ON TRUE
                        LEFT JOIN pg_type t
                                      ON t.oid = uu.pargtype)
   , pre            AS (SELECT p.schema                                  AS schema
                             , p.name                                    AS name
                             , CASE WHEN p.data_type = 'USER-DEFINED' THEN
                                        '"' || p.type_udt_schema || '"."' || p.type_udt_name || '"'
                                    ELSE
                                        p.data_type
        END                                                              AS returntype
                             , p.data_type = 'USER-DEFINED'              AS has_user_defined_returntype
                             , p.parameter_name                          AS parameter_name
                             , p.data_type                               AS data_type
                             , p.parameter_mode                          AS parameter_mode
                             , p.parameter_default                       AS parameter_default
                             , p.position_number                         AS position_number
                             , p.definition                              AS definition
                             , PG_GET_FUNCTIONDEF(p.oid)                 AS full_definition
                             , p.external_language                       AS language
                             , p.strictness                              AS strictness
                             , p.security_type                           AS security_type
                             , p.volatility                              AS volatility
                             , p.kind                                    AS kind
                             , p.oid                                     AS oid
                             , p.extension_oid                           AS extension_oid
                             , PG_GET_FUNCTION_RESULT(p.oid)             AS result_string
                             , PG_GET_FUNCTION_IDENTITY_ARGUMENTS(p.oid) AS identity_arguments
                             , PG_GET_FUNCTION_ARGUMENTS(p.oid)          AS function_arguments
                             , pg_catalog.obj_description(p.oid)         AS comment
                        FROM unnested p)
SELECT *
FROM pre
ORDER BY schema
       , name
       , parameter_mode
       , position_number
       , parameter_name;
