---
name: dv-performance
description: Diagnose- und Optimierungs-Checkliste für dbt-/datenbankseitige Performance-Probleme auf SQL Server/Azure SQL — Indizes, Materialisierung, Row-Level Security, Statistiken/Fragmentierung, Columnstore/Partitionierung, Data-Vault-PIT/Bridge, Power-BI-DirectQuery. Immer verwenden bei "Performance-Problem", "das dauert zu lange", "DirectQuery ist langsam", Index-/RLS-/Materialisierungs-Fragen, oder wenn ein Vorher-Nachher-Vergleich für eine DB-Änderung nötig ist.
---

# Performance-Diagnose auf dbt-/DB-Seite (SQL Server / Azure SQL)

Grundprinzip: **erst messen, dann ändern, dann erneut messen.** Nie aus Intuition heraus einen Index anlegen oder eine Materialisierung wechseln — jede Kategorie unten hat ihre eigene Messmethode.

## 0. Bottleneck finden, bevor eine Kategorie gewählt wird

- **Query Store** (auf Azure SQL standardmäßig aktiv) für dauerhafte Regressions-Erkennung — überlebt Neustarts/Failover, `sys.dm_exec_query_stats` (Plan-Cache) nicht.
- Ad-hoc-Messung über `dbt run-operation run_sql` (siehe Agent/Skill von `db-monitor`) — niemals SSMS-Ad-hoc-Schreibzugriffe ohne dbt-Bezug.
- Ausführungsplan-Warnsignale: Implicit Conversion, Key Lookup, Scan statt Seek, Cardinality-Abweichung >10x (geschätzt vs. tatsächlich), Spill to tempdb, fehlender Parallelismus.

Volle DMV-Abfragen für alle Abschnitte: `references/diagnostics.md`.

## 1. Fehlende/falsche Indizes

`sys.dm_db_missing_index_*` liefert **Hypothesen, keine fertigen Empfehlungen**:
- Spaltenreihenfolge in den Vorschlägen ist nicht verlässlich nach Selektivität sortiert — selbst bestimmen.
- Gegen `sys.indexes`/`sys.index_columns` prüfen, ob ein bestehender Index nur um eine INCLUDE-Spalte erweitert werden könnte, statt einen neuen anzulegen.
- Zähler sind kumulativ seit letztem Neustart/Failover/Index-Rebuild — niedrige Werte heißen nicht automatisch "unwichtig"; gegen Query-Store-Daten querchecken.
- Schreibkosten jedes neuen Index gegen den Lesegewinn abwägen (Faustregel: nicht mehr als ~5 Indizes/Tabelle ohne Begründung).

Projekt-Makros: `create_hash_index(hash_key_column)` (Hub/Sat/Link-Hashkeys), `create_composite_index(columns)` (Mehrspalten, z. B. FK-Spalten in Faktentabellen) — als `post_hook` einsetzen, beide idempotent (`IF NOT EXISTS`).

## 2. Materialisierungsstrategie (dbt)

Heuristik (dbt Labs): **View → Table → Incremental**, jede Stufe nur bei tatsächlichem, gemessenem Bedarf:
- **View**: Staging/Intermediate-Modelle, nicht direkt von Power BI konsumiert.
- **Table**: von DirectQuery/BI wiederholt abgefragte mart-Objekte. Standardmuster in diesem Projekt: Logik in `<name>.sql` mit `materialized='table'`, bisherige View wird dünner Wrapper `SELECT * FROM {{ ref('<name>') }}` (siehe `dim_konto`/`dim_konto_v`, `fakt_buchungen`/`fakt_buchungen_v`).
- **Incremental**: erst wenn der *Build* selbst (nicht die Abfrage) zu lange dauert.
- **Ephemeral: auf diesem Stack nicht verwenden** — T-SQL erlaubt keine genesteten CTEs, mehrstufige Ephemeral-Ketten kompilieren beim mssql-Adapter nicht zuverlässig.
- Bei `incremental`: Strategie `append`/`delete+insert` bevorzugen — `merge` kompiliert beim mssql-Adapter teils zu `DELETE`+`INSERT` statt echtem `MERGE`. Immer `dbt compile`/`dbt show --inline` gegenchecken, nicht die Doku-Beschreibung der Strategie vertrauen. Die HWM-Spalte (`dss_load_date`) für den `is_incremental()`-Filter muss indiziert sein.

## 3. Row-Level Security Overhead

**Der mit Abstand grösste Hebel ist nicht das Prädikat, sondern die Kardinalität der Menge,
auf der es läuft.** Die Prüffunktion wird pro Zeile ausgewertet — liegt der Filter auf einem
Fakt mit Millionen Zeilen, dominiert er alles; liegt er auf der zugehörigen Dimension mit
ein paar hundert Zeilen, ist er praktisch gratis. Die Fakten erben den Filter über den
`INNER JOIN` auf den Dimensionsschlüssel.

Gemessen (915.841 Faktzeilen, Aggregation `COUNT + SUM`):

| Variante | ms | logische Reads |
|---|---|---|
| Policy auf der Fakttabelle + Filter in der View | 2.201 | 3.697.737 |
| Filter nur auf der Dimension, Fakt erbt per Join | 273 | 31.069 |
| Referenz: derselbe Scan ohne Security | 221 | 30.744 |

Vor der Umstellung prüfen, ob die Dimension **jede** im Fakt vorkommende Ausprägung enthält —
sonst unterschlägt der `INNER JOIN` Zeilen, still und auch für Vollzugriffs-User. Details
und Umsetzung: Skill `dv-security`.

Liegt die absichernde Dimension danach auf dem kritischen Pfad jeder Fakt-Abfrage, gehört
sie materialisiert (Tabelle + gefilterter Wrapper-View) — als View kann sie pro Abfrage
teure Quellen erneut lesen.

Die weiteren Punkte betreffen das Prädikat selbst:

- RLS-Prädikate sind Inline-TVFs, die vor der Optimierung vollständig in die äußere Query eingebettet ("entfaltet") werden — **eine CTE innerhalb der Prädikatsfunktion ändert daran nichts** (in diesem Projekt bereits empirisch bestätigt: identisches Read-Verhältnis vor/nach CTE-Isolation, siehe `docs/lessons-learned/03-row-level-security-native-security-policy.md`).
- Häufigster stiller Kostentreiber: **`OR`-Disjunktionen** im Prädikat (z. B. Admin-Bypass) — kippen Index Seeks in Full Scans, ohne dass es im Plan sofort auffällt. Fix: Disjunktion in einen seekbaren Bereich umformulieren (`BETWEEN`) statt `x = @v OR bypass = 1`.
- Skalare Rollen-Checks (`IS_ROLEMEMBER()`, `IS_SRVROLEMEMBER()`) im Prädikat erzwingen einen seriellen Plan (kein Parallelismus) — bei Bedarf durch eine indizierte Session-/Lookup-Tabelle (`SESSION_CONTEXT()`, keyed on `@@SPID`) ersetzen.
- Messmethode: `ALTER SECURITY POLICY ... WITH (STATE = OFF/ON)` als A/B-Hebel, logische Reads (nicht nur Dauer) vergleichen, gezielt auf Seek→Scan-Wechsel und `NonParallelPlanReason` im Plan achten. Für View-Filter statt Policies: `measure_rls_overhead` (Skill `dv-security`, `references/macros.md`) misst sitzungsisoliert über `sys.dm_exec_sessions.logical_reads` — `sys.dm_exec_query_stats` ist durch dbt-Wrapping und Fremdtraffic verrauscht.
- Security-DDL wird in diesem Projekt bewusst nicht über dbt deployed (`security/DEPLOYMENT.md`) — Änderungen an `fn_check_rls`/Policies immer nur vorschlagen, der User deployed manuell dev→test→prod.

## 4. Statistiken & Fragmentierung

- Auto-Update greift bei großen Tabellen (>~10 Mio. Zeilen) oft zu spät (klassischer 20%-Schwellwert) — nach großen Loads manuell `UPDATE STATISTICS ... WITH FULLSCAN` erwägen.
- Symptom veralteter Statistiken: geschätzte vs. tatsächliche Zeilenzahl im Plan weit auseinander, Plan kippt nach Bulk-Load/Delete um.
- Fragmentierung nur ab `page_count > 1000` relevant: 5–30 % → REORGANIZE, >30 % → REBUILD (`ONLINE=ON` auf den meisten Azure-SQL-Tiers möglich).

## 5. Columnstore & Partitionierung

- Clustered Columnstore lohnt ab Faktentabellen mit **Millionen Zeilen** und lesend/aggregierend abgefragten (nicht Punkt-Lookup-) Workloads; Dimensionstabellen bleiben Rowstore.
- Azure-SQL-DTU-Tier: Columnstore braucht **mind. Standard S3** (darunter wird ein vorhandener Columnstore-Index vom Optimizer ignoriert, aber weiter gepflegt — kein Datenverlust, nur kein Nutzen). vCore-Tiers (inkl. Serverless): keine Mindeststufe, aber kleine vCore-Zahlen limitieren den Rowgroup-Aufbau.
- Partitionierung erst ab ca. 50–100 GB/mehreren Mio. Zeilen sinnvoll — **nur wenn jede relevante Abfrage tatsächlich auf die Partitionsspalte filtert** (gegen echtes DirectQuery-generiertes SQL prüfen, nicht nur Hand-Queries), sonst kein Elimination-Gewinn.
- Serverless-Tier: Cold-Start nach Auto-Pause (~Sekunden bis ~1 Minute, SQL-Fehler 40613 bis bereit), Cache nach Resume kalt — erste Abfragen nach Pause sind langsamer, unabhängig vom Columnstore-Zustand. Vor "Serverless Cold-Start ist Schuld" immer `sys.dm_db_resource_stats`/`sys.dm_os_sys_info.sqlserver_start_time` gegenchecken (siehe `docs/lessons-learned/` — CPU lag in diesem Projekt durchgehend unter 27 %, Cold-Start war nicht die Ursache).

## 6. Data-Vault-spezifische Muster

- Standard-Index je Satellite: zusammengesetzt auf `(hash_key, dss_load_date)` — deckt sowohl "Historie zu diesem Business Key" als auch "aktuelle Zeile" ab. Bei physischem `dss_is_current`-Flag zusätzlich darauf filtern/indizieren (ggf. gefilterter Index `WHERE dss_is_current = 'Y'`).
- **PIT-Tabelle** einführen, sobald ein Hub/Link von mehreren, unterschiedlich getakteten Satellites umgeben ist und Marts wiederholt dieselben Multi-Satellite-Joins bauen — nicht präventiv.
- **Bridge-Tabelle** bei teuren M:N-Auflösungen/Mehrfach-Link-Traversierungen (z. B. Beleg → Position → Produkthierarchie) — Grain-Wechsel gehört in den Bridge-Load, nicht in die Mart-View.
- Virtualisierte "aktuelle Zeile" (Window-Funktion `LEAD()`/`LAG()` in einer View) statt physischem Flag: Der Optimizer kann die Bedingung oft nicht in einen Index-Seek übersetzen — für BI-nahe, latenzkritische Objekte physisches Flag bevorzugen.
- Fehlt eine Vault-Satellite-Spalte, die ein Mart-Modell braucht (Symptom: Mart referenziert eine Staging-View statt Hub/Sat/Link): das ist ein Vault-Modellierungs-Gap, kein Mart-Performance-Problem — an `vault-architect`/`staging-engineer` zurückmelden, nicht im Mart workarounden.

## 7. Power-BI-DirectQuery-Seite (Empfehlung, nicht selbst umsetzen)

- mart-Objekte, die von DirectQuery wiederholt abgefragt werden, als Tabelle materialisieren (Abschnitt 2) — das ist der größte dbt-seitig kontrollierbare Hebel.
- Bekannte DAX-Fallstricke, die zu teurem generiertem SQL führen (siehe `docs/lessons-learned/`): bare Column-Prädikate in `CALCULATE()` verhalten sich anders als `FILTER()`; sobald eine Calculation Group im Modell existiert, werden implizite Measures modellweit deaktiviert.
- Aggregations-Tabellen (Import-Mode, Faustregel ≥10x kleiner als die Detailtabelle) und Zeitintelligenz über materialisierte Ganzzahl-Offsets in `dim_date` statt `SAMEPERIODLASTYEAR()`/`DATESYTD()` sind Empfehlungen an den Report-Ersteller, nicht dbt-seitig umsetzbar — als Empfehlung zurückmelden, nicht selbst im Power-BI-Modell ändern.

## Vorgehens-Prinzip

Gemessene Zahl schlägt Spekulation — jede Kategorie oben braucht eine eigene Vorher/Nachher-Messung (logische Reads, ms, `STATISTICS IO`). Bringt eine Änderung keinen Unterschied: zurückbauen und den negativen Befund dokumentieren (siehe `docs/lessons-learned/`, Abschnitt RLS für ein reales Beispiel), damit dieselbe Hypothese nicht erneut verfolgt wird.

## Referenzen

Volle DMV-Abfragen und Quellenliste je Kategorie: `references/diagnostics.md`.
