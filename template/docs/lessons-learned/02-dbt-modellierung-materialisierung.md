---
title: "dbt-Modellierung / Materialisierung"
tags:
  - lessons-learned
---
[Dokumentation](../README.md) › [Lessons Learned](00-lessons-learned.md)

# 1. dbt-Modellierung / Materialisierung

### Nicht-materialisierte View-Ketten sind ein Performance- UND Stabilitätsrisiko

`dim_konto_v` war eine VIEW mit 3× UNION ALL + TRY_CAST/HASHBYTES — wurde bei **jedem** Power-BI-DirectQuery-Aufruf komplett neu berechnet (~2.3–2.6s Zusatzkosten bei nur 449 Zeilen). Fix: Logik nach `dim_konto` (TABLE) auslagern, `dim_konto_v` wird dünner Wrapper (`SELECT * FROM {{ ref('dim_konto') }}`) — analog zum Muster `fakt_buchungen`/`fakt_buchungen_v`. **Diese Aufteilung (Tabelle + Wrapper-View) ist das Standardmuster hier, wende es proaktiv an, sobald eine mart-View mehr als triviale Joins/Berechnungen enthält und von Power BI DirectQuery konsumiert wird.**

### Noch fragiler: View-Ketten, die bis zu einer External Table (Parquet) reichen

`dim_person_v` → `<quelle>_person` (Staging-VIEW) → `stg.ext_<quelle>_person` (External Table auf rohe ADLS-Parquet-Datei) — alle drei Ebenen nicht materialisiert. Jede Power-BI-Abfrage liest dadurch live die Parquet-Datei, was bei gleichzeitigem Synapse-Ladejob transient fehlschlagen kann ("location does not exist or is used by another process"). **Bei jeder Kette, die auf eine External Table zurückführt: prüfen, ob mindestens die Staging-Ebene materialisiert werden sollte.**

### Fehlende Vault-Attribute führen zu Mart-Layer-Workarounds, die die Vault umgehen

`dim_person_v` liest für den "aktive Mitarbeiter"-Filter (`LOHNJN`, `GESPERRT`) direkt aus der rohen Staging-View statt aus einer Satellite — weil `sat_person_adresse__<quelle>` diese Spalten nie im Payload hatte (dokumentierte Lücke im Validierungsbericht). **Wenn ein Mart-Modell `{{ ref('<staging_model>') }}` statt eines Hub/Sat/Link referenziert, ist das ein Signal für eine unvollständige Raw-Vault-Modellierung — nicht nur ein Stilproblem, sondern ein Performance-/Stabilitätsrisiko (reicht bis zur Quelle durch).**

### CTEs können nicht in einer anderen CTE oder einer Subquery genestet werden (T-SQL)

`automate_dv.ref_table()` erzeugt selbst ein `WITH source_data AS (...) SELECT ...`. Eigenes `WITH base AS ({{ automate_dv.ref_table(...) }})` scheitert mit *"Incorrect syntax near 'with'"* — T-SQL erlaubt keine CTE-Definition, deren Körper mit `WITH` beginnt, auch nicht in einer Subquery/Derived Table. **Wenn eine zusätzliche Spalte auf ein `ref_table()`-Ergebnis nötig ist: Macro nicht wrappen, sondern die äquivalente Logik direkt inline schreiben** (siehe `ref_actual_forecast_v.sql`).

### Quellformat-Annahmen empirisch prüfen, nicht dem Kommentar vertrauen

`ref_actual_forecast_v` dokumentierte `Y_Month` als Format `'YYYY-MM'` — real lieferte Sharepoint `'YYYYMMM'` (z.B. `'2022M05'`). Der Join `dim_date.year_month = Y_Month` matchte dadurch **strukturell nie** (0 Zeilen) — vermutlich seit Einführung wirkungslos, ohne dass es auffiel (kein Fehler, nur leere Ergebnisse). **Bei Join-Keys zwischen Quellen: immer `SELECT DISTINCT <spalte>` gegenchecken, nicht nur den Header-Kommentar lesen.**

---

[Übersicht](00-lessons-learned.md) · [Row-Level Security](03-row-level-security-native-security-policy.md) ▶
