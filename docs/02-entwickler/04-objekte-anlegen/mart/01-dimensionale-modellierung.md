---
title: "Dimensionale Modellierung"
tags:
  - entwickler/mart
---
[Dokumentation](../../../README.md) › [Data Vault 2.1 – Developer Guide](../../00-entwicklerhandbuch.md) › [Objekte anlegen](../00-objekte-anlegen.md) › [Mart](00-mart.md)

# Dimensionale Modellierung

Der Mart bildet Kimball-Star-Schemas auf dem Vault: Dimensionen (beschreibend) und Fakten (Messwerte), verbunden über deterministische BIGINT-Surrogate-Keys.

## Hausmuster: Tabelle + publizierte View

```
Vault (Current Views, PIT, Links) ─► dim_<entity> / fakt_<inhalt>      Tabelle: Logik, Joins, Berechnungen
                                  ─► dim_<entity>_v / fakt_<inhalt>_v  View: SELECT * + Security (RLS/CLS)
```

| Objekt | Materialisierung | Inhalt | Zugriff |
|--------|------------------|--------|---------|
| `dim_*`, `fakt_*` | `table` (Voreinstellung für `mart` in `dbt_project.yml`), `as_columnstore=false` | gesamte Logik | nur Entwickler |
| `dim_*_v`, `fakt_*_v` | `view` | `SELECT *` aus der Tabelle + `rls_filter`/`cls_mask` bzw. Join auf Träger-Dimensionen | BI-Tools (View-Grants per Hook) |

Warum: Nicht materialisierte View-Ketten werden bei **jedem** DirectQuery-Aufruf komplett neu berechnet, und Ketten bis zu einer External Table brechen, sobald die Landing Zone gerade beschrieben wird. Triviale Dimensionen ohne nennenswerte Joins dürfen direkt als `_v`-View gebaut werden.

## Stern, kein Snowflake: keine Keys zwischen Dimensionen

Dimensionen hängen **nur an Fakten**. Eine Dimension führt ausschließlich ihren eigenen `<dim>_key` — nie den Key einer anderen Dimension (`dim_rezept.sorte_key`, `dim_baustelle.kunde_key` o. ä.).

| Fachliche Beziehung | So modellieren | Nicht so |
|---|---|---|
| Merkmal eines Vorgangs (Charge gehört zu Sorte, Lieferung zu Werk) | `<dim>_key` **im Fakt** — aus dem Vault abgeleitet, auch wenn er über eine andere Entität läuft (Charge → Rezept → Sorte) | Key in der Dimension, Fakt erreicht die Sorte nur über `dim_rezept` |
| Hierarchie/Zugehörigkeit zur Anzeige (Rezept gehört zu Sorte, Anlage zu Firma) | **denormalisierte Attribute** in der Dimension: `sorte_code`, `sorte_name`, `firma_name` | `sorte_key` in `dim_rezept` |

Warum: Ketten Fakt → Dimension → Dimension erzeugen in Power BI mehrdeutige Filterpfade und in Qlik synthetische Schlüssel bzw. Loops — spätestens, wenn derselbe Key (z. B. Werk) zusätzlich direkt im Fakt steht. Fakten wachsen dafür additiv um weitere Keys; der Grain bleibt gleich.

Auch Vorgaben aus Bus-Matrizen oder Fach-ER-Diagrammen („Sorte 1:n Rezept“) werden so umgesetzt: die fachliche Kante wird zum Attribut in der Dimension plus Key in den Fakten.

## Surrogate Keys

```sql
{{ surrogate_key('<bk_spalte>') }} AS <dim>_key
-- = ABS(CONVERT(BIGINT, HASHBYTES('MD5', CAST(<bk_spalte> AS NVARCHAR(MAX)))))
```

- Dimension (PK) und Fakt (FK) rufen `surrogate_key()` auf **derselben** Business-Key-Spalte auf — nur so matchen die Joins. Nie `ROW_NUMBER()` oder Identity (ändert sich bei Rebuilds).
- Zusammengesetzter Schlüssel: Spalten vorher verketten, z. B. `{{ surrogate_key("CONCAT_WS('||', mandant, kst)") }}`.
- Datum: `CONVERT(INT, FORMAT(<datum>, 'yyyyMMdd')) AS datum_key` gegen `dim_date`.

## SCD1 oder SCD2?

| | SCD1 — aktueller Stand | SCD2 — Versionen |
|---|---|---|
| Frage, die der Bericht beantwortet | „Wie ist es heute?“ — alle Fakten unter dem heutigen Namen/der heutigen Zuordnung | „Wie war es damals?“ — Fakten unter der Zuordnung zum Buchungszeitpunkt |
| Quelle im Vault | `sat_…_current_v` (bzw. `dss_is_current = 'Y'`) | alle Satellite-Versionen mit `dss_load_date`/`dss_end_date`, bei mehreren Satellites eine PIT |
| Zeilen je Business Key | 1 | 1 je Version |
| Surrogate Key | `surrogate_key(<bk>)` | `surrogate_key(CONCAT_WS('\|\|', <bk>, <gueltig_von>))` |
| Zusatzspalten | — | `gueltig_von`, `gueltig_bis`, `ist_aktuell` |
| Fakt-Join | über `<dim>_key` | Fakt ermittelt den Key der zum Ereignisdatum gültigen Version |
| **Standard im Projekt** | **ja** | nur auf ausdrückliche fachliche Anforderung |

SCD2-Dimension aus einem Satellite:

```sql
SELECT
    {{ surrogate_key("CONCAT_WS('||', h.<bk>, CONVERT(NVARCHAR(30), s.dss_load_date, 126))") }} AS <dim>_key,
    CAST(h.<bk> AS NVARCHAR(255))                 AS <dim>_id,
    ISNULL(s.<code>, CAST(h.<bk> AS NVARCHAR(255))) AS <dim>_code,
    ISNULL(s.<name>, 'UNKNOWN')                   AS <dim>_name,
    s.dss_load_date                               AS gueltig_von,
    ISNULL(s.dss_end_date, '9999-12-31')          AS gueltig_bis,
    s.dss_is_current                              AS ist_aktuell,
    s.dss_load_date, s.dss_record_source
FROM {{ ref('hub_<entity>') }} h
JOIN {{ ref('sat_<entity>__<quelle>') }} s ON s.hk_<entity> = h.hk_<entity>
```

Der Fakt wählt die Version über das Ereignisdatum: `JOIN dim_<entity> d ON d.<dim>_id = f.<bk> AND f.<datum> >= d.gueltig_von AND f.<datum> < d.gueltig_bis`. Fachliche Gültigkeiten der Quelle (z. B. `gueltig_von` einer Preisliste) haben Vorrang vor Ladezeitpunkten, wenn sie vorhanden sind.

## Pflichtspalten

**Dimension**

| Spalte | Typ | Regel |
|--------|-----|-------|
| `<dim>_key` | BIGINT | `surrogate_key()`, `unique` + `not_null` getestet |
| `<dim>_id` | NVARCHAR(255) | technische ID aus der Quelle |
| `<dim>_code` | NVARCHAR(255) | sprechender Schlüssel, Fallback = ID |
| `<dim>_name` | NVARCHAR(255) | Bezeichnung, Fallback = Code, sonst `'UNKNOWN'` |
| `dss_sec_value_key` | NVARCHAR | nur auf Dimensionen, die Zeilen filtern ([Security](03-security-rls-cls.md)) |
| `dss_load_date`, `dss_record_source` | | aus dem Vault durchgereicht |

NULL in Code/Name bricht BI-Tools (leere Member) — immer mit `ISNULL` absichern.
Fehlende Bezüge im Fakt auf eine Unbekannt-Zeile (`<dim>_key = -1`) lenken statt Zeilen zu verlieren.

**Fakt**

| Spalte | Regel |
|--------|-------|
| `<dim>_key` je Dimension | gleicher `surrogate_key()`-Aufruf wie in der Dimension |
| `datum_key` | `JJJJMMTT` |
| Measures | expliziter Typ (`DECIMAL(18,2)`), Einheit im Namen falls mehrdeutig |
| Degenerate Dimensions | Belegnummern o. ä. direkt im Fakt |
| `dss_load_date`, `dss_record_source` | durchgereicht |

## Beispiel: Dimension (SCD1)

```sql
{{ config(materialized='table', as_columnstore=false, tags=['dimension']) }}

SELECT
    {{ surrogate_key('h.<bk>') }}                       AS <dim>_key,
    CAST(h.<bk> AS NVARCHAR(255))                       AS <dim>_id,
    ISNULL(s.<code>, CAST(h.<bk> AS NVARCHAR(255)))     AS <dim>_code,
    ISNULL(s.<name>, ISNULL(s.<code>, 'UNKNOWN'))       AS <dim>_name,
    s.dss_load_date,
    s.dss_record_source
FROM {{ ref('hub_<entity>') }} h
JOIN {{ ref('sat_<entity>__<quelle>_current_v') }} s ON s.hk_<entity> = h.hk_<entity>
```

`dim_<entity>_v.sql`:

```sql
{{ config(materialized='view', tags=['dimension']) }}
SELECT * FROM {{ ref('dim_<entity>') }}
WHERE {{ rls_filter('<kontext>') }}          -- nur Träger-Dimensionen; sonst ohne WHERE
```

## Beispiel: Fakt

```sql
{{ config(materialized='table', as_columnstore=false, tags=['fact']) }}

SELECT
    {{ surrogate_key('l.<bk_e1>') }}                    AS <dim1>_key,
    {{ surrogate_key('l.<bk_e2>') }}                    AS <dim2>_key,
    CONVERT(INT, FORMAT(s.<datum>, 'yyyyMMdd'))         AS datum_key,
    CAST(s.<betrag> AS DECIMAL(18,2))                   AS betrag,
    s.dss_load_date,
    s.dss_record_source
FROM {{ ref('link_<e1>_<e2>') }} l
JOIN {{ ref('sat_<ereignis>__<quelle>_current_v') }} s ON s.hk_<ereignis> = l.hk_<ereignis>
```

`fakt_<inhalt>_v.sql` joint die Träger-Dimensionen (`INNER JOIN dim_<x>_v`), damit der Fakt deren Zeilenfilter erbt — Details und die vier Regeln: [Security (RLS/CLS)](03-security-rls-cls.md), Referenz: [Security → RLS dimensional](../../../03-system/security/04-rls-dimensional.md).

## YAML und Diagramm

```yaml
  - name: dim_<entity>
    description: "Dimension <Entität> (SCD1) aus hub_<entity> + sat_<entity>__<quelle>."
    config: {tags: ['dimension']}
    columns:
      - name: <dim>_key
        data_type: bigint
        data_tests: [unique, not_null]
      - name: <dim>_name
        data_tests: [not_null]
```

Diagramm je Domäne: `design/mart/er-mart-<domain>.mmd` (Skill `dv-design-sync`).
Performance-Fragen (Indizes, Incremental, DirectQuery): [Persistierte Marts](02-persistierte-marts.md).

---

[Übersicht](00-mart.md) · [Persistierte Marts](02-persistierte-marts.md) ▶
