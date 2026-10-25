---
name: dv-patterns
description: Data Vault 2.1 Pattern-Bibliothek mit Entscheidungslogik und automate_dv-Templates für Hub, Satellite, Link, Transaction Link, Multi-Active Satellite, Dependent-Child Satellite, Effectivity Satellite und Reference Table. Immer verwenden, wenn ein Raw-Vault-Objekt erstellt oder geändert wird — auch bei Formulierungen wie "Hub anlegen", "Satellite für X", "Beziehung modellieren", "neue Entity", "Tabelle historisieren" oder wenn unklar ist, welcher DV-Objekttyp passt.
---

# Data Vault 2.1 Pattern-Bibliothek

Templates und Entscheidungslogik für Raw-Vault-Objekte mit dbt + automate_dv auf SQL Server / Azure SQL. Die Templates sind das Ergebnis produktiver DV-2.1-Projekte — Abweichungen (z. B. fehlender `hashdiff`-Alias, fehlende post_hooks oder fehlende `dss_*`-Pflichtspalten) führen erfahrungsgemäß zu schwer findbaren Folgefehlern, deshalb den Mustern exakt folgen.

## Konvention vor Bestand

Bestehende Modelle im Projekt sind **nur dann Vorlage, wenn sie konform sind**. Ältere oder schnell gebaute Modelle verletzen die Pflichtkonventionen oft (z. B. Hubs ohne `dss_business_key`) — wer sie kopiert, vervielfacht den Fehler. Deshalb:

1. Neue Objekte immer nach den Templates dieses Skills bauen, nicht nach dem Nachbarmodell.
2. Projektspezifisch **legitim** sind nur bewusste Projektentscheidungen: Hash-Separator/-Weg, Macro-Signaturen, Schema-Zuordnung, Quell-Kürzel.
3. Nicht konforme Bestandsmodelle dem User melden (Liste), nicht still übernehmen. Das Audit zeigt sie: `python <plugin>/hooks/dv_lint.py --audit .` (läuft auch beim Sitzungsstart).

## Entscheidungslogik: Welches DV-Objekt?

```
Gibt es einen stabilen Business Key?                      → HUB
Ändern sich beschreibende Attribute über Zeit?            → SATELLITE (am Hub)
Beziehung zwischen 2+ Entities?                           → LINK
Beziehung hat eigene Attribute?                           → LINK SATELLITE (am Link)
Entity ohne eigenen BK (z. B. Positionen)?                → DEPENDENT CHILD SATELLITE (am Link)
Mehrere gleichzeitig gültige Werte (z. B. Rollen)?        → MULTI-ACTIVE SATELLITE (am Hub, src_cdk)
Stabile Lookup-Werte (Länder, Status)?                    → REFERENCE TABLE (kein Hub!)
Unveränderliche Ereignis-Daten (Transaktionen, Events)?   → TRANSACTION LINK (_tl Suffix)
Zeitraum/Gültigkeit einer Beziehung?                      → EFFECTIVITY SATELLITE (am Link)
Performance-Problem bei Zeitreisen-Abfragen?              → PIT TABLE (nur bei Bedarf)
```

Vor dem Anlegen: Entscheidung mit dem User abstimmen (nummerierte Optionen anbieten), Business Key und Grain explizit benennen.

## Naming-Konventionen

| Objekt | Muster | `__source`-Suffix | Beispiel |
|--------|--------|:-----------------:|----------|
| Hub | `hub_<entity>` | ❌ | `hub_kunde` |
| Satellite | `sat_<entity>__<source>` | ✅ | `sat_kunde__erp` |
| MA Satellite | `sat_<entity>_ma__<source>` | ✅ (`_ma` davor) | `sat_kunde_kontakt_ma__crm` |
| Link | `link_<e1>_<e2>` | ❌ | `link_verkauf_kunde` |
| Transaction Link | `link_<entity>_tl` | ❌ | `link_event_tl` |
| Reference Table | `ref_<name>` | ❌ | `ref_status` |

Der `__source`-Suffix gilt **nur für Satellites** — jede Quelle bekommt ihren eigenen Satellite am gemeinsamen Hub (Multi-Source-Integration). Entitätsnamen immer lowercase.

## Pflichtspalten (DV-Metadaten)

| Spalte | Typ | Bedeutung |
|--------|-----|-----------|
| `hk_<entity>` | CHAR(64) | SHA-256 Hash Key (hex via `CONVERT(CHAR(64), HASHBYTES('SHA2_256', …), 2)`) |
| `hashdiff` | CHAR(64) | Hash der Payload — **Alias, nicht der Quellspaltenname!** |
| `dss_load_date` | DATETIME2(6) | Ladezeitpunkt — jedes Objekt |
| `dss_record_source` | VARCHAR(50) | Quellsystem-Kennung — jedes Objekt |
| `dss_business_key` | NVARCHAR | **Jeder Hub**, genau eine Spalte ohne Suffix: `CONCAT_WS('\|\|', 'default', 'default', ISNULL(LTRIM(RTRIM(CAST(<bk> AS NVARCHAR(MAX)))), '-1') …)` — Segment 1 Mandant, Segment 2 Collision-Code, danach die BK-Spalten wie in `hashed_columns` |
| `dss_create_datetime` | DATETIME2 | **Jeder Hub und jeder Standard-/DC-Satellite** (MA/Eff/TL empfohlen) — über `src_extra_columns`, nie im Payload; im Staging `CAST(GETDATE() AS DATETIME2)` |
| `dss_start_date` / `dss_end_date` / `dss_is_current` | — | Satellite-Historisierung (end_date NULL = aktuell) |

Beide Zusatzspalten entstehen als `derived_columns` im Staging (Skill `dv-staging`). Speist ein Staging einen **FK-Hub** (Fremdschlüssel, z. B. Bestellungs-Staging → `hub_kunde`), liest dieser aus einer eigenen FK-Staging-View `<staging>__<entity>` — Details: [references/templates.md](references/templates.md), Abschnitt Hub.

## Templates

Alle Vault-Modelle folgen demselben Aufbau: Header-Kommentar → `config()` → `yaml_metadata`-Block → `fromyaml()` → automate_dv-Macro-Aufruf. Vollständige Templates: [references/templates.md](references/templates.md) · Objekt-Leitlinien (Wann/Warum je Typ, DC/MA/Eff-Sat/PSA/PIT im Detail, Fehlannahmen, Checklisten): [references/developer-guide.md](references/developer-guide.md)

### Hub (Kurzform)

```sql
{{ config(
    materialized='incremental',
    as_columnstore=false,
    post_hook=["{{ create_hash_index('hk_<entity>') }}"]
) }}

{%- set yaml_metadata -%}
source_model: "<staging_model>"        # Liste bei Multi-Source!
src_pk: "hk_<entity>"
src_nk: "<business_key>"
src_extra_columns:                     # Pflicht in jedem Hub
    - "dss_business_key"
    - "dss_create_datetime"
src_ldts: "dss_load_date"
src_source: "dss_record_source"
{%- endset -%}

{% set metadata_dict = fromyaml(yaml_metadata) %}

{{ automate_dv.hub(src_pk=metadata_dict["src_pk"], src_nk=metadata_dict["src_nk"],
                   src_extra_columns=metadata_dict["src_extra_columns"],
                   src_ldts=metadata_dict["src_ldts"], src_source=metadata_dict["src_source"],
                   source_model=metadata_dict["source_model"]) }}
```

`src_extra_columns` muss auch an `automate_dv.hub()` übergeben werden — steht es nur im YAML-Block, fehlen die Spalten ohne Fehlermeldung.

### Satellite — die zwei häufigsten Fehler

1. `src_hashdiff` braucht `alias: "hashdiff"` (automate_dv erwartet den Alias, nicht den `hd_*`-Spaltennamen).
2. post_hooks nicht vergessen: `create_hash_index` **und** `update_satellite_current_flag` (setzt dss_is_current/dss_end_date).
3. `src_extra_columns: ["dss_create_datetime"]` angeben und an `automate_dv.sat()` übergeben — **nicht** in `src_payload` (sonst Teil des Hashdiff → jede Zeile eine neue Version).

```yaml
src_hashdiff:
  source_column: "hd_<entity>__<source>"
  alias: "hashdiff"
```

### Transaction Link (Non-Historized)

Für unveränderliche Events: `incremental_strategy='append'`, Event-ID gehört **in den Hash Key** (`Hash(event_id, fk_1, fk_2)`), kein Hash Diff, kein current_flag-Hook am zugehörigen Transaction Satellite.

### Multi-Active Satellite

`src_cdk` (Child Dependent Key) zusätzlich angeben — die Spalte(n), die mehrere gleichzeitig gültige Werte je Hash Key unterscheiden.

## Nach jeder Modell-Änderung (Artefakt-Synchronisation)

Ein Vault-Modell ist erst fertig, wenn alle Artefakte synchron sind — sonst driftet die Doku vom Code weg und Reviews werden wertlos:

1. SQL-Modell (`models/raw_vault/…`)
2. Schema-YAML (`_<ordner>__models.yml`) mit Tests: Hash Key `not_null` + `unique` (Hub/Link), BK `not_null`
3. ER-Diagramm im `design/`-Ordner (Skill `dv-design-sync`)

## Kritische Regeln

- **`--full-refresh` auf historisierten Objekten nur nach ausdrücklicher Freigabe des Users** (Hub/Sat/Link sind append-only — Full Refresh vernichtet Historie unwiederbringlich; in einer reinen Entwicklungsphase mit Testdaten kann der User das bewusst erlauben).
- Nach jedem neuen/geänderten Vault-Objekt meldet der PostToolUse-Lint (`dv_lint.py`) Verstöße — Befunde beheben, nicht übergehen. Meldet der Hook selbst einen Fehler (z. B. kein Python gefunden), das dem User sagen: dann läuft keine Prüfung.
- Raw Vault ist **insert-only**: kein UPDATE/DELETE, Korrekturen kommen als neue Records.
- Hash-Konfiguration (Separator, NULL-Placeholder, Casing) kommt aus `dbt_project.yml` vars — nie im Modell hart kodieren.
