---
title: "Daten prüfen"
tags:
  - benutzer
  - typ/nachschlagen
---
[Dokumentation](../README.md) › [Data Vault 2.1 – Benutzer-Dokumentation](00-benutzerhandbuch.md)

# Daten prüfen

Prüfabfragen für neue oder geänderte Objekte und für die Fehlersuche. Jede Abfrage liefert im Sollfall **0 Zeilen** bzw. gleiche Zahlen — sonst steht der Befund in der Ergebnismenge. Platzhalter ersetzen; Satellites heißen `sat_<entity>__<quelle>`.

## Abfragen absetzen

| Werkzeug | Aufruf |
|----------|--------|
| dbt (ohne Client) | `dbt show --inline "SELECT COUNT(*) FROM vault.hub_<entity>"` |
| dbt-Macro | `dbt run-operation run_sql --args '{"sql": "SELECT …"}'` |
| sqlcmd (Entra ID) | `sqlcmd -S <sql-server>.database.windows.net -d <datenbank>-dev -G -Q "SELECT …"` |
| SSMS / Azure Data Studio / VS Code mssql | Anmeldung „Microsoft Entra – Universal with MFA“ |

## 1. Zeilenzahlen entlang der Kette

```sql
SELECT 'ext'  AS stufe, COUNT(*) AS zeilen FROM stg.ext_<concept>_<entity>
UNION ALL SELECT 'stg',  COUNT(*) FROM stg.<concept>_<entity>
UNION ALL SELECT 'hub',  COUNT(*) FROM vault.hub_<entity>
UNION ALL SELECT 'sat',  COUNT(*) FROM vault.sat_<entity>__<quelle>
UNION ALL SELECT 'sat aktuell', COUNT(*) FROM vault.sat_<entity>__<quelle> WHERE dss_is_current = 'Y';
```

Erwartung: `ext` = `stg`; `hub` = Anzahl **verschiedener** Business Keys der Quelle (bei mehreren Quellen: aller Quellen); `sat aktuell` = `hub` (sofern jede Quelle jeden Schlüssel liefert); `sat` ≥ `sat aktuell` (Historie). Alle Objekte auf einmal: `dbt run-operation log_row_counts`.

## 2. Eindeutigkeit der Business Keys

**Quelle — ist der gewählte Business Key wirklich eindeutig?** Vor dem Bau des Hubs prüfen; Treffer bedeuten, dass der Schlüssel unvollständig ist (Spalte fehlt) oder die Quelle Dubletten liefert.

```sql
SELECT <bk_1>, <bk_2>, COUNT(*) AS anzahl
FROM stg.<concept>_<entity>
GROUP BY <bk_1>, <bk_2>
HAVING COUNT(*) > 1
ORDER BY anzahl DESC;
```

**Hub — ein Hash Key je Business Key, ein Business Key je Hash Key:**

```sql
-- doppelte Hash Keys (darf nie vorkommen)
SELECT hk_<entity>, COUNT(*) FROM vault.hub_<entity>
GROUP BY hk_<entity> HAVING COUNT(*) > 1;

-- derselbe Business Key unter verschiedenen Hashes (Typ/Format uneinheitlich, z. B. '4711' vs. '4711.00')
SELECT dss_business_key, COUNT(DISTINCT hk_<entity>) AS hashes FROM vault.hub_<entity>
GROUP BY dss_business_key HAVING COUNT(DISTINCT hk_<entity>) > 1;

-- Klartext passt nicht zum Business Key (FK-Hub liest aus dem falschen Staging)
SELECT TOP 20 hk_<entity>, <bk>, dss_business_key FROM vault.hub_<entity>
WHERE dss_business_key <> CONCAT_WS('||', 'default', 'default', ISNULL(LTRIM(RTRIM(CAST(<bk> AS NVARCHAR(MAX)))), '-1'));
```

**Satellite — je Schlüssel und Ladezeitpunkt genau eine Version, genau eine aktuelle:**

```sql
-- Grain verletzt (doppelte Version)
SELECT hk_<entity>, dss_load_date, COUNT(*) FROM vault.sat_<entity>__<quelle>
GROUP BY hk_<entity>, dss_load_date HAVING COUNT(*) > 1;

-- mehr als eine aktuelle Version bzw. keine
SELECT hk_<entity>, SUM(CASE WHEN dss_is_current = 'Y' THEN 1 ELSE 0 END) AS aktuelle
FROM vault.sat_<entity>__<quelle>
GROUP BY hk_<entity> HAVING SUM(CASE WHEN dss_is_current = 'Y' THEN 1 ELSE 0 END) <> 1;

-- aufeinanderfolgende Versionen mit identischem Inhalt (Dauer-Deltas: Payload ≠ Hashdiff)
SELECT COUNT(*) FROM (
    SELECT hashdiff, LAG(hashdiff) OVER (PARTITION BY hk_<entity> ORDER BY dss_load_date) AS vorher
    FROM vault.sat_<entity>__<quelle>) x
WHERE hashdiff = vorher;
```

Bei **Multi-Active Satellites** gehört der Unterscheidungsschlüssel (`<child_key>`) mit in den Grain: `GROUP BY hk_<entity>, <child_key>, dss_load_date`.

**Link — eine Zeile je Schlüsselkombination, Grain passend zur Beziehung:**

```sql
-- doppelte Link-Hashes
SELECT hk_link_<e1>_<e2>, COUNT(*) FROM vault.link_<e1>_<e2>
GROUP BY hk_link_<e1>_<e2> HAVING COUNT(*) > 1;

-- dieselbe Kombination unter mehreren Link-Hashes (Link-Hash ≠ Verkettung der Hub-Keys)
SELECT hk_<e1>, hk_<e2>, COUNT(*) FROM vault.link_<e1>_<e2>
GROUP BY hk_<e1>, hk_<e2> HAVING COUNT(*) > 1;

-- 1:n-Beziehung (ein <e1> zu vielen <e2>): jeder <e2> darf nur einmal vorkommen
SELECT hk_<e2>, COUNT(DISTINCT hk_<e1>) FROM vault.link_<e1>_<e2>
GROUP BY hk_<e2> HAVING COUNT(DISTINCT hk_<e1>) > 1;
```

**Mart — ein Surrogate Key je Dimensionszeile:**

```sql
SELECT <dim>_key, COUNT(*) FROM mart_<domain>.dim_<entity>
GROUP BY <dim>_key HAVING COUNT(*) > 1;
```

Die Eindeutigkeit von Hub- und Link-Hashes sowie Mart-Keys ist zusätzlich als dbt-Test (`unique`) hinterlegt: `dbt test --select <modell>`.

## 3. Referentielle Integrität (Waisen)

```sql
-- Satellite-Zeilen ohne Hub
SELECT COUNT(*) FROM vault.sat_<entity>__<quelle> s
WHERE NOT EXISTS (SELECT 1 FROM vault.hub_<entity> h WHERE h.hk_<entity> = s.hk_<entity>);

-- Link-Zeilen ohne einen der Hubs
SELECT COUNT(*) FROM vault.link_<e1>_<e2> l
WHERE NOT EXISTS (SELECT 1 FROM vault.hub_<e1> h WHERE h.hk_<e1> = l.hk_<e1>)
   OR NOT EXISTS (SELECT 1 FROM vault.hub_<e2> h WHERE h.hk_<e2> = l.hk_<e2>);

-- Fakten ohne Dimensionszeile (landen in BI-Tools unter "(leer)")
SELECT COUNT(*) FROM mart_<domain>.fakt_<inhalt> f
WHERE NOT EXISTS (SELECT 1 FROM mart_<domain>.dim_<entity> d WHERE d.<dim>_key = f.<dim>_key);
```

## 4. Historie nachvollziehen

```sql
-- alle Versionen eines Schlüssels
SELECT * FROM vault.sat_<entity>__<quelle>
WHERE hk_<entity> = (SELECT hk_<entity> FROM vault.hub_<entity> WHERE <bk> = '<wert>')
ORDER BY dss_load_date DESC;

-- Stand zu einem Stichtag
DECLARE @stichtag DATETIME2 = '2026-06-30';
SELECT * FROM vault.sat_<entity>__<quelle>
WHERE dss_load_date <= @stichtag AND (dss_end_date > @stichtag OR dss_end_date IS NULL);
```

## 5. Ladezustand

```sql
-- letzte dbt-Läufe (Status, Anzahl Modelle, Fehler)
SELECT TOP 10 status, started_at, completed_at, model_count, details
FROM vault.load_status WHERE pipeline_name = 'dbt_run' ORDER BY id DESC;

-- jüngster Ladezeitpunkt je Objekt
SELECT MAX(dss_load_date) FROM vault.sat_<entity>__<quelle>;
```

---

◀ [Neue Entity hinzufügen](07-neue-entity-hinzufuegen.md) · [Übersicht](00-benutzerhandbuch.md) · [Datenzugriff & Berechtigungen](09-datenzugriff-berechtigungen.md) ▶
