/* Ver qué hace el SP mientras corre (ejecutar en otra sesión). */
SELECT r.session_id,
       r.status,
       r.wait_type,
       r.wait_time,
       r.cpu_time,
       r.total_elapsed_time,
       r.reads,
       r.logical_reads,
       SUBSTRING(t.text, (r.statement_start_offset / 2) + 1,
           CASE WHEN r.statement_end_offset = -1 THEN LEN(CONVERT(NVARCHAR(MAX), t.text))
                ELSE (r.statement_end_offset - r.statement_start_offset) / 2 + 1 END) AS statement_text
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE t.text LIKE '%csp_Ad_SugerenciaPedimentos_v2%'
  AND r.session_id <> @@SPID;
GO
