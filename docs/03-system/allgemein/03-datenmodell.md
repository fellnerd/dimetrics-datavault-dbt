---
title: "Datenmodell"
tags:
  - system
---
[Dokumentation](../../README.md) › [Data Vault 2.1 – Systemdokumentation](../00-systemdokumentation.md)

# Datenmodell

### 3.1 Data Vault Objekte

Der Raw Vault kennt die folgenden Objekttypen; welche Objekte in einem Mandanten konkret existieren, zeigt `dbt docs` bzw. die Mandanten-Dokumentation.

| Objekttyp | Namensmuster | Materialisierung | Zweck |
|-----------|--------------|------------------|-------|
| Hub | `hub_<entity>` | incremental (append) | Business Keys einer Entität, quellübergreifend |
| Satellite | `sat_<entity>__<quelle>` | incremental (append) | Historisierte Attribute, Change Detection über Hash Diff |
| Multi-Active Satellite | `sat_<entity>_<gruppe>_ma__<quelle>` | incremental (append) | Mehrere gleichzeitig gültige Sätze pro Key |
| Dependent-Child Satellite | `sat_<entity>_<child>__<quelle>` | incremental (append) | Attribute mit abhängigem Teilschlüssel |
| Effectivity Satellite | `sat_<entity>_eff__<quelle>` bzw. `eff_sat_*` | incremental (append) | Gültigkeitszeiträume von Beziehungen |
| Link | `link_<entity1>_<entity2>` | incremental (append) | Beziehung zwischen Hubs |
| Transaction Link | `link_<event>_tl` | incremental (append) | Ereignisse/Transaktionen |
| Reference Table | `ref_<thema>` | view / seed | Codetabellen, Zuordnungslisten |
| Current View | `sat_<entity>_current_v` | view | Aktueller Stand eines Satellites |
| PIT Table | `pit_<entity>` | table | Point-in-Time für performante Abfragen |

Konfiguration je Objektgruppe (Schema, Materialisierung, `on_schema_change: append_new_columns`) steht in `dbt_project.yml`, siehe [Konfiguration](06-konfiguration.md).

### 3.2 Hash-Berechnung

Konfiguriert über `vars` in `dbt_project.yml`:

| Variable | Wert | Bedeutung |
|----------|------|-----------|
| `hash` | `SHA` | SHA2_256, hex-kodiert |
| `concat_string` | `\|\|` | Trenner beim Multi-Column-Hashing |
| `null_placeholder_string` | `-1` | Platzhalter für NULL im Hash-Input |
| `hash_content_casing` | `DISABLED` | kein `UPPER()` auf Hash-Inputs (case-sensitive Daten) |
| `escape_char_left` / `escape_char_right` | `[` / `]` | Escaping reservierter SQL-Server-Schlüsselwörter |

Zwei eigene Overrides in `macros/hash_override.sql` passen automate_dv an SQL Server an:

- `sqlserver__cast_binary` → `CHAR(64)` statt `BINARY(32)`, damit Hash Keys lesbar sind
- `sqlserver__type_string` → `NVARCHAR` statt `VARCHAR` (Unicode-sicher; `HASHBYTES` über NVARCHAR liefert andere Werte als über VARCHAR — nach einer Umstellung ist ein Full Refresh nötig)

- **Hash Key:** `hk_<entity>` — Hash des Business Key
- **Hash Diff:** `hd_<entity>__<quelle>` — Attribut-Hash für die Change Detection

```sql
-- Hash-Berechnung (SQL Server)
CONVERT(CHAR(64), HASHBYTES('SHA2_256', 
    ISNULL(CAST(column AS NVARCHAR(MAX)), '')
), 2)
```

### 3.3 Metadata-Spalten (`dss_*`)

Alle technischen Spalten tragen das Präfix `dss_` (Data Store Service). Sie sind nach Zweck gruppiert — nicht jedes Objekt hat jede Spalte.

#### Pflicht in jedem Vault-Objekt

| Spalte | Typ | Beschreibung |
|--------|-----|--------------|
| `dss_load_date` | DATETIME2 | Zeitpunkt des Ladens in den Vault (Batch-Wert je Ladelauf). Grundlage für inkrementelles Laden (High-Water-Mark) |
| `dss_record_source` | NVARCHAR | Quellsystem, systemweit normiert (z.B. `<mandant>_<quellsystem>`), nicht je Datei oder Feed |

#### Hubs

| Spalte | Typ | Beschreibung |
|--------|-----|--------------|
| `dss_business_key` | NVARCHAR | Business Key im Klartext, normiert — Aufbau siehe unten. **Genau eine** solche Spalte je Hub, ohne Suffix |
| `dss_create_datetime` | DATETIME2 | Technischer Insert-Zeitpunkt der Zeile. In **jedem** Hub |

#### Satellites und Historisierung

| Spalte | Typ | Beschreibung |
|--------|-----|--------------|
| `dss_is_current` | CHAR(1) | `Y`/`N` — aktuelle Version je Hash-Key, gesetzt per Post-Hook `update_satellite_current_flag` |
| `dss_end_date` | DATETIME2 | Ende der Gültigkeit einer Version (Satellites) bzw. einer Beziehung (Effectivity Satellites) |
| `dss_eff_date` | DATETIME2 | Beginn der fachlichen Gültigkeit — `src_eff` im Effectivity Satellite |
| `dss_start_date` | DATETIME2 | Beginn einer Beziehung in Effectivity-Satellites (vom Macro `satellite_current_flag` ausgewertet) |
| `dss_is_active` | CHAR(1) | `Y`/`N` — Beziehung aktiv oder beendet (Effectivity-Satellites) |
| `dss_version_rank` | INT | Nur in `_current_v`-Views berechnet (`ROW_NUMBER`), **nicht persistiert** |

#### Lineage bei dateibasierten Quellen

| Spalte | Typ | Beschreibung |
|--------|-----|--------------|
| `dss_source_file_name` | NVARCHAR | Herkunftsdatei. **Schreibweise für neue Objekte** |
| `dss_source_filename` | NVARCHAR | Dasselbe — ältere Schreibweise in einzelnen Bestandsobjekten. Nicht umbenennen (Vault-Tabellen), aber nicht neu verwenden |
| `dss_stage_timestamp` | DATETIME2 | Zeitstempel der Landing Zone |
| `dss_run_id` | NVARCHAR | Lauf-/Pipeline-Kennung |
| `dss_source_feed` | NVARCHAR | Rohwert der Quelle (z.B. Ordnerpfad), bevor `dss_record_source` normiert wurde |
| `dss_export_datum` | DATETIME2 | Exportzeitpunkt, aus dem Dateinamen abgeleitet — für „letzter Export gewinnt"-Deduplizierung |

> **Lineage-Spalten gehören nie in den Hashdiff.** Sonst erzeugt jeder Export eine neue Satellite-Version, obwohl sich fachlich nichts geändert hat.

#### Security

| Spalte | Typ | Beschreibung |
|--------|-----|--------------|
| `dss_sec_value_key` | NVARCHAR | RLS-Schlüssel als hierarchischer Pfad (`<mandant>\|\|<gruppe>\|\|<detail>`), nur auf den Träger-Dimensionen der Zeilenfilter. Siehe [03-system/security/](../security/04-rls-dimensional.md) |

### 3.4 `dss_business_key` im Detail

#### Aufbau

```sql
dss_business_key = CONCAT_WS('||', 'default', 'default', <BK-Spalte 1>, <BK-Spalte 2>, …)
```

Jede Business-Key-Spalte wird normiert: als Text, ohne Leerzeichen am Rand, NULL wird `-1`.

```sql
ISNULL(LTRIM(RTRIM(CAST(<spalte> AS NVARCHAR(MAX)))), '-1')
```

| Segment | Inhalt |
|---|---|
| 1 | `'default'` — reserviert für den Mandanten |
| 2 | Collision-Code (Quellsystem-Kontext) — `'default'`, solange keine Kollisionen möglich sind; sonst die Projektkonvention, z. B. das Quellsystem |
| 3 … n | die Business-Key-Spalten |

Beispiele: `default||default||4711` (ein Schlüssel), `default||default||4711||1||2||99` (zusammengesetzter Schlüssel).

#### Beziehung zum Hash-Key

Der Hash-Key wird **nicht** aus `dss_business_key` gebildet, sondern direkt aus den Business-Key-Spalten in `hashed_columns`:

```yaml
derived_columns:
  dss_business_key: "CONCAT_WS('||', 'default', 'default', ISNULL(LTRIM(RTRIM(CAST(BELNR AS NVARCHAR(MAX)))), '-1'))"
hashed_columns:
  hk_kreditorenbeleg: "BELNR"
```

`dss_business_key` ist die **lesbare Form** des Schlüssels — für Prüfungen und Fehlersuche. Segment 1 und 2 fließen nicht in den Hash ein.

> Die Business-Key-Spalten in `dss_business_key` und in `hashed_columns` müssen dieselben sein, in derselben Reihenfolge. Sonst beschreibt die Klartext-Spalte einen anderen Schlüssel als der Hash.
>
> **Ausnahme Collision-Code:** Ist der Collision-Code selbst Teil des Hash-Keys — etwa bei quellübergreifenden Hubs mit abstrahiertem Schlüssel `hk = HASH(<x>_bk, quelle)` —, steht er in Segment 2 und nicht noch einmal am Ende: `default||<quelle>||<x>_bk`. Die Regel gilt dann für die übrigen Spalten. Das Muster je Projekt einmal festlegen und in der Projekt-`CLAUDE.md` dokumentieren.

> **`derived_columns` können sich nicht gegenseitig referenzieren** — `automate_dv.stage()` berechnet sie alle aus den Quellspalten. Wird ein Business Key erst abgeleitet (z. B. `<x>_bk: "CONCAT_WS('||', a, b)"`), steht derselbe Ausdruck in `dss_business_key` noch einmal statt `<x>_bk`. Beide Stellen gemeinsam ändern (Kommentar setzen), sonst driften Hash und Klartext auseinander. Konstanten (z. B. das Quellsystem) als Literal einsetzen.

#### Primär-Hub vs. FK-Hub

**Jeder Hub hat genau eine Spalte `dss_business_key` — immer unter diesem Namen, ohne Suffix.**

Ein Staging-Model hat eine Haupt-Entität, speist aber oft mehrere Hubs — etwa `stg_bestellung` (Haupt-Entität Bestellung, BK `bestell_nr`) den Hub der Bestellung *und* den Hub des Kunden (Fremdschlüssel, BK `kunden_nr`). Sein `dss_business_key` gehört der Haupt-Entität.

| Hub-Typ | Beispiel | Quelle des `dss_business_key` |
|---|---|---|
| **Primär-Hub** — Haupt-Entität des Stagings | `hub_bestellung` aus `stg_bestellung` | direkt aus dem Staging |
| **FK-Hub** — Fremdschlüssel im Staging | `hub_kunde` aus `stg_bestellung` | aus einer **eigenen FK-Staging-View** `stg_bestellung__kunde` |

**Der `dss_business_key` des Stagings darf nie in einen FK-Hub.** In `hub_kunde` stünde sonst die Bestellnummer.

Umbenennen im Hub geht nicht — `automate_dv.hub()` übernimmt Zusatzspalten nur unter ihrem Namen. Deshalb bekommt jeder FK-Hub eine schlanke Staging-View, die den Schlüssel *seiner* Entität unter dem Namen `dss_business_key` bildet:

```sql
-- models/staging/<staging>__<entity>.sql   (View, reine Projektion)
SELECT
    hk_<entity>,
    <FK_BK>,
    CONCAT_WS('||', 'default', 'default',
              ISNULL(LTRIM(RTRIM(CAST(<FK_BK> AS NVARCHAR(MAX)))), '-1')) AS dss_business_key,
    dss_create_datetime,
    dss_load_date,
    dss_record_source
FROM {{ ref('<staging>') }}
```

Der FK-Hub liest dann aus dieser View (`source_model: "<staging>__<entity>"`). Die Deduplizierung je Hash-Key übernimmt `automate_dv.hub()` selbst.
