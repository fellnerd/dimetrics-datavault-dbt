---
name: dv-marts
description: Erstellt Information-Mart-Objekte (Star Schema) auf dem Raw Vault — Dimensionen und Faktentabellen mit deterministischen BIGINT-Surrogate-Keys, Unbekannt-Zeile, NULL-Fallbacks, publizierten _v-Views und BI-tauglichen Konventionen (Power BI/Qlik/Tableau). Immer verwenden bei "Dimension erstellen", "Faktentabelle", "Mart bauen", "Star Schema", "Reporting-View", "Information Mart", "dim_" oder "fakt_"-Objekten oder wenn Vault-Daten für BI-Tools aufbereitet werden sollen — auch für schnelle erste Entwürfe.
---

# Information Marts auf Data Vault (Star Schema)

Marts sind die BI-Schicht über dem Raw Vault: Kimball-Star-Schema. Der Vault bleibt die einzige Wahrheit — Marts enthalten keine eigene Historisierungslogik, sondern lesen den aktuellen Stand (`dss_is_current = 'Y'` bzw. `_current_v`) oder gezielt Historie über PIT-Tabellen.

**Konvention vor Bestand:** Bestehende Marts sind nur Vorlage, wenn sie diesem Muster folgen. Auch ein „schneller erster Entwurf“ folgt dem Muster — ein Mart mit `hk_*`-Keys oder ohne `_code`/`_name` muss sonst komplett umgebaut werden.

## Hausmuster: Tabelle + publizierte View

| Objekt | Materialisierung | Inhalt | Zugriff |
|--------|------------------|--------|---------|
| `dim_<entity>`, `fakt_<inhalt>` | `table`, `as_columnstore=false`, `tags=['dimension']` bzw. `['fact']` | gesamte Logik, Joins, Berechnungen | Entwickler |
| `dim_<entity>_v`, `fakt_<inhalt>_v` | `view` | `SELECT *` aus der Tabelle, später + RLS/CLS | BI-Tools |

Naming: Fakten heißen **`fakt_`** (nicht `fact_`). Triviale Dimensionen ohne nennenswerte Joins dürfen direkt als `_v`-View gebaut werden.

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

- Dimension (PK) und Fakt (FK) rufen `surrogate_key()` auf **demselben Ausdruck** auf — nur so matchen die Joins. Nie `hk_*`-Hashes als Key, nie `ROW_NUMBER()` oder Identity (ändern sich bei Rebuilds).
- Zusammengesetzter Schlüssel: vorher verketten, z. B. `{{ surrogate_key("CONCAT_WS('||', h.kunde_bk, h.quelle)") }}`.
- **Unbekannt-Zeile:** jede Dimension enthält per `UNION ALL` eine Zeile `<dim>_key = -1` (`<dim>_id`/`_code` `'-1'`, `<dim>_name` `'Unbekannt'`). Fakten lenken fehlende Bezüge per `ISNULL(<key>, -1)` / `CASE` darauf, statt Zeilen zu verlieren.
- Datum: `CONVERT(INT, FORMAT(<datum>, 'yyyyMMdd')) AS datum_key` gegen `dim_date` (`dim_date` wiederverwenden, keine eigene Datumslogik).

## Pflichtspalten

### Dimension (`dim_<entity>`)

| Spalte | Typ | Regel |
|--------|-----|-------|
| `<dim>_key` | BIGINT | `surrogate_key()`, getestet `unique` + `not_null` |
| `<dim>_id` | NVARCHAR(255) | technische ID aus dem Vorsystem |
| `<dim>_code` | NVARCHAR(255) | sprechender Schlüssel; Fallback = ID |
| `<dim>_name` | NVARCHAR(255) | Bezeichnung; Fallback = Code, sonst `'UNKNOWN'` |
| `dss_sec_value_key` | NVARCHAR | nur auf Dimensionen, die Zeilen filtern (Skill `dv-security`) |
| `dss_load_date`, `dss_record_source` | | aus dem Vault durchgereicht |

`ISNULL(code, CAST(id AS NVARCHAR(255)))`, `ISNULL(name, ISNULL(code, 'UNKNOWN'))` — NULL-Member brechen BI-Tools.

### Fakt (`fakt_<inhalt>`)

| Spalte | Regel |
|--------|-------|
| `<dim>_key` je Dimension | gleicher `surrogate_key()`-Ausdruck wie in der Dimension, Fallback `-1` |
| `datum_key` | `JJJJMMTT` |
| Measures | expliziter Typ (`DECIMAL(18,2)` …), Einheit im Namen, falls mehrdeutig |
| Degenerate Dimensions | Belegnummern o. ä. direkt im Fakt |
| `dss_load_date`, `dss_record_source` | durchgereicht |

Grain im Header-Kommentar dokumentieren.

## SCD1 (Standard) oder SCD2

SCD1 (aktueller Stand, 1 Zeile je BK) ist Standard. SCD2 nur auf ausdrückliche fachliche Anforderung: Key = `surrogate_key(CONCAT_WS('||', <bk>, <gueltig_von>))`, Zusatzspalten `gueltig_von`, `gueltig_bis`, `ist_aktuell`; der Fakt wählt die zum Ereignisdatum gültige Version.

## Aufbau-Muster

```sql
{#
    Mart: dim_<entity>
    Grain: 1 Zeile je <entity> + Unbekannt-Zeile (-1). SCD1.
    Quellen: hub_<entity>, sat_<entity>__<quelle> (current)
#}
{{ config(materialized='table', as_columnstore=false, tags=['dimension']) }}

WITH basis AS (
    SELECT
        {{ surrogate_key('h.<bk>') }}                           AS <dim>_key,
        CAST(h.<bk> AS NVARCHAR(255))                           AS <dim>_id,
        CAST(s.<code> AS NVARCHAR(255))                         AS <dim>_code_quelle,
        CAST(s.<name> AS NVARCHAR(255))                         AS <dim>_name_quelle,
        COALESCE(s.dss_load_date, h.dss_load_date)              AS dss_load_date,
        COALESCE(s.dss_record_source, h.dss_record_source)      AS dss_record_source
    FROM {{ ref('hub_<entity>') }} h
    LEFT JOIN {{ ref('sat_<entity>__<quelle>') }} s
        ON s.hk_<entity> = h.hk_<entity> AND s.dss_is_current = 'Y'
)
SELECT
    <dim>_key,
    <dim>_id,
    ISNULL(<dim>_code_quelle, <dim>_id)                          AS <dim>_code,
    ISNULL(<dim>_name_quelle, ISNULL(<dim>_code_quelle, 'UNKNOWN')) AS <dim>_name,
    dss_load_date,
    dss_record_source
FROM basis
UNION ALL
SELECT CAST(-1 AS BIGINT), N'-1', N'-1', N'Unbekannt', CAST('1900-01-01' AS DATETIME2), N'SYSTEM'
```

`dim_<entity>_v.sql`:

```sql
{{ config(materialized='view', tags=['dimension']) }}
SELECT * FROM {{ ref('dim_<entity>') }}
```

Fakten joinen über Links: der Link liefert die FK-Hash-Keys, die Hubs liefern die BKs für `surrogate_key()`, Link-/Transaction-Sats liefern die Measures.

## Checkliste vor Fertigmeldung

1. Jede Dimension: `<dim>_key` (BIGINT, `surrogate_key`), `_id`, `_code`, `_name`, `dss_load_date`, `dss_record_source`, Unbekannt-Zeile `-1` — und **kein Key einer anderen Dimension** (Stern, kein Snowflake)?
2. Fakt: Keys mit identischem Ausdruck wie die Dimension, `datum_key`, Grain im Header, keine verlorenen Zeilen (COUNT Fakt vs. Quell-Link)?
3. Je Tabelle eine publizierte `_v`-View; Naming `dim_`/`fakt_`; Tags gesetzt?
4. Schema-YAML mit Tests: `<dim>_key` `unique` + `not_null`, FK-Keys `not_null` (+ `relationships` auf die Dimension)
5. Mart-ER-Diagramm `design/mart/er-mart-<domain>.mmd` aktualisiert (Skill `dv-design-sync`), Changelog-Zeile (Skill `dv-docs`)
6. Der PostToolUse-Lint meldet Verstöße gegen 1 und 3 automatisch — Befunde beheben.
