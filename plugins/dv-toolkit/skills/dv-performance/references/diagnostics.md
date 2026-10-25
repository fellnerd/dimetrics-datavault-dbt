# Diagnostics Reference — DMV-Queries & Quellen

Volle Abfragen und Quellenbelege zu den Kategorien in `../SKILL.md`. Alle Queries per `dbt run-operation run_sql --args '{"sql": "..."}' --target <target>` ausführen (siehe Skill `db-monitor`), nicht über einen separaten DB-Client ohne dbt-Bezug.

## 1. Bottleneck finden

**Query Store aktiv/gesund?**
```sql
SELECT actual_state_desc, desired_state_desc, current_storage_size_mb,
       max_storage_size_mb, query_capture_mode_desc, stale_query_threshold_days
FROM sys.database_query_store_options;
```

**Regressierte Queries (letzte 6h vs. vorherige 7 Tage):**
```sql
WITH recent AS (
    SELECT rs.query_id, AVG(rs.avg_duration) AS recent_avg_ms
    FROM sys.query_store_runtime_stats rs
    WHERE rs.last_execution_time > DATEADD(HOUR, -6, SYSUTCDATETIME())
    GROUP BY rs.query_id
),
prior AS (
    SELECT rs.query_id, AVG(rs.avg_duration) AS prior_avg_ms
    FROM sys.query_store_runtime_stats rs
    WHERE rs.last_execution_time BETWEEN DATEADD(DAY,-7,SYSUTCDATETIME()) AND DATEADD(HOUR,-6,SYSUTCDATETIME())
    GROUP BY rs.query_id
)
SELECT qt.query_sql_text, r.recent_avg_ms, pr.prior_avg_ms,
       r.recent_avg_ms / NULLIF(pr.prior_avg_ms,0) AS regression_ratio
FROM recent r
JOIN prior pr ON pr.query_id = r.query_id
JOIN sys.query_store_query q ON q.query_id = r.query_id
JOIN sys.query_store_query_text qt ON qt.query_text_id = q.query_text_id
WHERE r.recent_avg_ms > pr.prior_avg_ms * 2
ORDER BY regression_ratio DESC;
```

**Teuerste Statements im Plan-Cache (CPU und Reads getrennt ranken — der Spitzenreiter unterscheidet sich meist):**
```sql
SELECT TOP 25
    qs.execution_count,
    qs.total_worker_time / 1000.0 / qs.execution_count AS avg_cpu_ms,
    qs.total_elapsed_time / 1000.0 / qs.execution_count AS avg_duration_ms,
    qs.total_logical_reads / qs.execution_count AS avg_logical_reads,
    SUBSTRING(st.text, (qs.statement_start_offset/2)+1,
        ((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(st.text)
          ELSE qs.statement_end_offset END - qs.statement_start_offset)/2)+1) AS statement_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY qs.total_worker_time DESC;   -- Variante: ORDER BY qs.total_logical_reads DESC
```

**Live Memory-Grants / Spills:**
```sql
SELECT r.session_id, r.command, mg.requested_memory_kb, mg.granted_memory_kb,
       mg.used_memory_kb, mg.ideal_memory_kb, r.wait_type
FROM sys.dm_exec_query_memory_grants mg
JOIN sys.dm_exec_requests r ON r.session_id = mg.session_id;
```

**Ausführungsplan-Warnsignale (im tatsächlichen, nicht nur geschätzten Plan prüfen):**

| Signal | Wo zu sehen | Bedeutung |
|---|---|---|
| Implicit Conversion | Gelbes Warnsymbol am Scan/Seek, `CONVERT_IMPLICIT` im Prädikat | Killt Seeks — meist Typ-/Collation-Mismatch zwischen Parameter und Spalte |
| Key Lookup | Nested Loop mit Seek + Lookup-Paar | Zufalls-I/O je Zeile — bei hoher Zeilenzahl fehlende INCLUDE-Spalten ergänzen |
| Scan statt erwartetem Seek | Operatortyp + hohe "Number of Rows Read" vs. "Actual Rows" | Fehlender/unbrauchbarer Index, non-SARGable Prädikat (Funktion auf Spalte, `LIKE '%x'`, `OR`) |
| Cardinality-Abweichung >10x | Estimated vs. Actual Rows je Operator | Veraltete Statistiken, Parameter Sniffing, Table Variables |
| Spill to tempdb | Gelbes Warnsymbol an Sort/Hash, "Spill Level" | Memory Grant zu klein — meist Folge falscher Kardinalitätsschätzung |
| Fehlender Parallelismus | `NonParallelPlanReason = CouldNotGenerateValidParallelPlan` | Oft skalare Funktion (z. B. `IS_SRVROLEMEMBER()`) im Prädikat |

Reihenfolge der Diagnose: Query Store/`dm_exec_query_stats` → Plan holen → Warnsignal-Tabelle durchgehen → erst dann Index-/Statistik-Kategorie unten prüfen.

## 2. Fehlende Indizes

```sql
SELECT TOP 25
    mid.statement AS table_name,
    migs.avg_total_user_cost * migs.avg_user_impact
        * (migs.user_seeks + migs.user_scans) AS estimated_impact,
    migs.avg_user_impact, migs.user_seeks, migs.user_scans,
    mid.equality_columns, mid.inequality_columns, mid.included_columns
FROM sys.dm_db_missing_index_groups mig
JOIN sys.dm_db_missing_index_group_stats migs ON migs.group_handle = mig.index_group_handle
JOIN sys.dm_db_missing_index_details mid ON mig.index_handle = mid.index_handle
WHERE mid.database_id = DB_ID()
ORDER BY estimated_impact DESC;
```

Vor dem Anlegen: gegen bestehende Indizes abgleichen.
```sql
SELECT i.name, i.type_desc, STRING_AGG(c.name, ', ') AS columns
FROM sys.indexes i
JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
WHERE i.object_id = OBJECT_ID('<schema.table>')
GROUP BY i.name, i.type_desc;
```

Projekt-Makros (siehe `macros/create_hash_index.sql`): `create_hash_index(hash_key_column)`, `create_composite_index(columns)` — beide idempotent, als `post_hook` einsetzen.

## 3. Statistiken

```sql
SELECT OBJECT_NAME(s.object_id) AS table_name, s.name AS stat_name,
    sp.last_updated, sp.rows, sp.modification_counter,
    CAST(sp.modification_counter AS float) / NULLIF(sp.rows,0) AS pct_modified
FROM sys.stats s
CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
WHERE sp.modification_counter > 0
ORDER BY pct_modified DESC;
```
Manuelles Update: `UPDATE STATISTICS dbo.Table (StatName) WITH FULLSCAN;` (oder `WITH SAMPLE 30 PERCENT` bei sehr großen Tabellen).

## 4. Fragmentierung

```sql
SELECT OBJECT_NAME(ips.object_id) AS table_name, i.name AS index_name,
    ips.avg_fragmentation_in_percent, ips.page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
JOIN sys.indexes i ON i.object_id = ips.object_id AND i.index_id = ips.index_id
WHERE ips.page_count > 1000
ORDER BY ips.avg_fragmentation_in_percent DESC;
```
5–30 % → `ALTER INDEX ... REORGANIZE`; >30 % → `ALTER INDEX ... REBUILD WITH (ONLINE = ON, MAXDOP = n)`.

## 5. RLS-Overhead messen

```sql
-- A/B-Vergleich: Policy aus-/einschalten, STATISTICS IO/TIME jeweils vergleichen
ALTER SECURITY POLICY <schema>.<policy_name> WITH (STATE = OFF);
-- Query mit SET STATISTICS IO ON ausführen, Logical Reads notieren
ALTER SECURITY POLICY <schema>.<policy_name> WITH (STATE = ON);
-- dieselbe Query erneut, Logical Reads vergleichen
```
Kennzahl: **logische Reads pro Zeile** (Total Logical Reads ÷ Zeilenanzahl) — cache-unabhängig, verlässlicher als Dauer. Zusätzlich im Plan prüfen: Seek→Scan-Wechsel am RLS-geschützten Objekt, `NonParallelPlanReason`.

Bereits in diesem Projekt widerlegt: CTE-Isolation von Bypass-Branches innerhalb der Prädikatsfunktion (`fn_check_rls`) — identisches Read-Verhältnis vor/nach, weil Inline-TVFs vor der Optimierung vollständig in die äußere Query eingebettet werden (eine CTE ist keine Materialisierungs-/Optimierungsgrenze). Nicht wiederholen; siehe `docs/lessons-learned/`.

## Quellen

**SQL Server / Azure SQL Core:**
- [sys.dm_db_missing_index_details — Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-db-missing-index-details-transact-sql)
- [Don't just blindly create that missing index! — SQLPerformance.com](https://sqlperformance.com/2013/06/t-sql-queries/missing-index)
- [Tune performance with the Query Store — Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/performance/tune-performance-with-the-query-store)
- [Understand Your Plan: Query Plan Warnings — Erik Darling](https://erikdarling.com/understand-your-plan-query-plan-warnings/)
- [We Need to Talk About the Warnings In Your Query Plans — Brent Ozar Unlimited](https://www.brentozar.com/archive/2018/10/we-need-to-talk-about-the-warnings-in-your-query-plans/)
- [Statistics — SQL Server | Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/statistics/statistics)
- [Reorganize and Rebuild Indexes — Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/reorganize-and-rebuild-indexes)
- [SQL Server Index and Statistics Maintenance — Ola Hallengren](https://ola.hallengren.com/sql-server-index-and-statistics-maintenance.html)

**dbt:**
- [dbt Labs — Best practices for materializations](https://docs.getdbt.com/best-practices/materializations/1-guide-overview)
- [dbt Labs — Incremental models in-depth](https://docs.getdbt.com/best-practices/materializations/4-incremental-models)
- [dbt Labs — About incremental strategy](https://docs.getdbt.com/docs/build/incremental-strategy)
- [dbt Labs — Microsoft SQL Server configurations (Ephemeral/T-SQL-Limitation)](https://docs.getdbt.com/reference/resource-configs/mssql-configs)
- [dbt-msft/dbt-sqlserver — merge→delete+insert Issue #246](https://github.com/dbt-msft/dbt-sqlserver/issues/246)
- [dbt-msft — Nested CTEs](https://dbt-msft.github.io/dbt-msft-docs/docs/nested_CTES/)

**Data Vault:**
- [PIT Table Structure in Data Vault — Scalefree](https://www.scalefree.com/knowledge/webinars/data-vault-friday/pit-table-structure-in-data-vault/)
- [Bridge Tables 101 — Scalefree](https://www.scalefree.com/blog/data-vault/bridge-tables-101/)
- [Data Vault Virtualized Load End Date and the SQL Optimizer — Scalefree](https://www.scalefree.com/knowledge/webinars/data-vault-friday/virtualized-load-end-date-and-the-sql-optimizer/)
- [Multi-Active Satellites & Dependent Child Keys — Scalefree](https://www.scalefree.com/knowledge/webinars/data-vault-friday/multi-active-satellites-dependent-child-keys/)
- [How AutomateDV Uses PITs and Bridges — AutomateDV](https://automate-dv.com/2023/06/05/how-automatedv-uses-pits-and-bridges-to-enhance-your-data-vault/)

**Row-Level Security:**
- [Row-Level Security — Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/security/row-level-security)
- [RLS Performance and common patterns — Microsoft (archived blog)](https://learn.microsoft.com/en-us/archive/blogs/sqlsecurity/row-level-security-performance-and-common-patterns)
- [RLS for Middle-Tier Apps — Using Disjunctions in the Predicate — Microsoft (archived blog)](https://learn.microsoft.com/en-us/archive/blogs/sqlsecurity/row-level-security-for-middle-tier-apps-using-disjunctions-in-the-predicate)
- [Fundamentals of Table Expressions, Part 12/13 — Inline TVFs — SQLPerformance.com](https://sqlperformance.com/2021/10/t-sql-queries/table-expressions-part-12)
- [Row-level security supported by session detail table — Dan Loth](https://www.danloth.com/blog/row-level-security-supported-by-session-detail-table/)
- [Be Careful Where You Call Inline Table Valued Functions — Erik Darling](https://erikdarling.com/be-careful-where-you-call-inline-table-valued-functions/)

**Power BI DirectQuery:**
- [DirectQuery model guidance — Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/guidance/directquery-model-guidance)
- [Composite model guidance — Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/guidance/composite-model-guidance)
- [Understand star schema — Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/guidance/star-schema)
- [User-defined aggregations — Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/transform-model/aggregations-advanced)
- [Optimizing time intelligence in DirectQuery — SQLBI](https://www.sqlbi.com/articles/optimizing-time-intelligence-in-directquery/)

**Columnstore & Partitionierung:**
- [Columnstore indexes — Design guidance — Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-design-guidance)
- [Columnstore support in Standard tier Azure SQL Databases — Microsoft Azure Blog](https://azure.microsoft.com/en-us/blog/columnstore-support-in-standard-tier-azure-sql-databases/)
- [Serverless compute tier — Azure SQL Database — Microsoft Learn](https://learn.microsoft.com/en-us/azure/azure-sql/database/serverless-tier-overview)
