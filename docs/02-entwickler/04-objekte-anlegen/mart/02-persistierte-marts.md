---
title: "Persistierte Marts"
tags:
  - entwickler/mart
---
[Dokumentation](../../../README.md) › [Data Vault 2.1 – Developer Guide](../../00-entwicklerhandbuch.md) › [Objekte anlegen](../00-objekte-anlegen.md) › [Mart](00-mart.md)

# Persistierte Marts

Wie ein Mart-Objekt materialisiert wird, entscheidet über die Antwortzeit in Power BI (DirectQuery fragt bei jeder Interaktion live ab) und über die Laufzeit des Ladens.

## Entscheidung

| Situation | Materialisierung | Beispiel |
|-----------|------------------|----------|
| Publizierte Schnittstelle | `view` (`_v`), nur `SELECT *` + Security | `fakt_buchungen_v` |
| Dimension oder Fakt mit Joins/Berechnungen, bis einige Mio. Zeilen | `table` (**Standard**, Voreinstellung für `mart`) | `dim_konto`, `fakt_buchungen` |
| Großer Fakt oder Aggregat über Massendaten, Rebuild dauert zu lange | `incremental` mit `delete+insert` und Nachlade-Fenster | Tagesaggregat über Sensor-Messwerte |
| Triviale Dimension ohne Joins (Codeliste) | direkt `view` | `dim_buchungsstatus_v` |

Faustregel: erst messen (Laufzeit, logische Reads — Skill `dv-performance`), dann materialisieren. Ein Mart-Objekt ist aus dem Vault jederzeit neu baubar; Full Refresh ist hier unkritisch.

## Incremental mit Nachlade-Fenster

```sql
{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key=['<dim1>_key', 'datum_key'],     -- Grain des Aggregats
    as_columnstore=false,
    tags=['fact'],
    post_hook=["{{ create_clustered_index(['datum_key']) }}"]
) }}

SELECT <dim1>_key, datum_key, COUNT(*) AS anzahl, SUM(<wert>) AS summe,
       MAX(dss_load_date) AS dss_load_date, MAX(dss_record_source) AS dss_record_source
FROM {{ ref('fakt_<detail>_v') }}
{% if is_incremental() %}
WHERE datum_key >= CONVERT(INT, FORMAT(DATEADD(day, -2, GETDATE()), 'yyyyMMdd'))   -- verspätete Lieferungen
{% endif %}
GROUP BY <dim1>_key, datum_key
```

- `delete+insert` ersetzt die Schlüssel des Fensters vollständig — richtig für Aggregate.
- Das Fenster muss die maximale Verspätung der Quelle abdecken.
- **Clustered Index Pflicht bei `delete+insert`:** Auf einem Heap gibt `DELETE` die Pages nicht frei, die Tabelle wächst mit jedem Lauf (gemessen: 1,6 GB Daten, 27 GB belegt).

## Index-Macros

| Macro | Wirkung | Verwendung |
|-------|---------|-----------|
| `create_hash_index('<spalte>', include_columns=[…])` | Non-Clustered Index auf einer Spalte, idempotent | Hash Keys, Join-Spalten |
| `create_composite_index(['<a>', '<b>'])` | Index auf Spaltenkombination | häufige Filter/Joins |
| `create_clustered_index(['<spalte>'])` | wandelt einen Heap in eine Tabelle mit Clustered Index | Pflicht bei `delete+insert` |
| `drop_and_create_index('<spalte>')` | Index neu anlegen | nach Typänderungen |

Alle als `post_hook` in der Modell-Config.

## Prüfen

```sql
-- Indizes einer Tabelle
SELECT i.name, i.type_desc, c.name AS spalte
FROM sys.indexes i
JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE i.object_id = OBJECT_ID('mart_<domain>.fakt_<inhalt>');

-- belegter vs. genutzter Platz (Heap-Wachstum erkennen)
EXEC sp_spaceused 'mart_<domain>.fakt_<inhalt>';
```

---

◀ [Dimensionale Modellierung](01-dimensionale-modellierung.md) · [Übersicht](00-mart.md) · [Security in Mart-Models (RLS/CLS)](03-security-rls-cls.md) ▶
