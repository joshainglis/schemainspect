SELECT p.polname                               AS name
     , n.nspname                               AS schema
     , c.relname                               AS table_name
     , p.polcmd                                AS commandtype
     , p.polpermissive                         AS permissive
     , (SELECT ARRAY_AGG(
                       CASE WHEN o = 0 THEN
                                'public'
                            ELSE
                                PG_GET_USERBYID(o)
                           END
               )
        FROM UNNEST(p.polroles) AS unn(o))
                                               AS roles
     , p.polqual                               AS qualtree
     , PG_GET_EXPR(p.polqual, p.polrelid)      AS qual
     , PG_GET_EXPR(p.polwithcheck, p.polrelid) AS withcheck
FROM pg_policy p
JOIN pg_class c ON c.oid = p.polrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
ORDER BY 2
       , 1
