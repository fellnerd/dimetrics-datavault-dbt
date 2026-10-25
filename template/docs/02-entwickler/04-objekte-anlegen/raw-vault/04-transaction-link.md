---
title: "Transaction Link"
tags:
  - entwickler/raw-vault
---
[Dokumentation](../../../README.md) › [Data Vault 2.1 – Developer Guide](../../00-entwicklerhandbuch.md) › [Objekte anlegen](../00-objekte-anlegen.md) › [Raw Vault](00-raw-vault.md)

# Transaction Link

Für **unveränderliche Ereignisse**: Buchungen, Sensor-Messwerte, Logeinträge. Ein Ereignis wird einmal geschrieben und nie historisiert. Namenskonvention `link_<ereignis>_tl`, die Attribute stehen in einem Transaction Satellite `sat_<ereignis>_tl__<quelle>`.

| | Link | Transaction Link |
|---|---|---|
| Grain | eine Zeile je Schlüsselkombination | eine Zeile je **Ereignis** |
| Hash Key | Hash der Hub-Business-Keys | Hash aus **Ereignis-ID** + Hub-Business-Keys |
| Attribute | im (Link-)Satellite, historisiert | im Transaction Satellite, **ohne** Hash Diff-Vergleich |
| Current Flag | ja (Satellite) | nein — es gibt keine „aktuelle Version“ |
| Datenmenge | klein bis mittel | oft Millionen Zeilen → eigene Domäne mit Tag |

## Staging

```yaml
hashed_columns:
  hk_<e1>: "<BK_E1>"
  hk_<e2>: "<BK_E2>"
  hk_link_<ereignis>_tl:
    - "<EVENT_ID>"          # macht jedes Ereignis eindeutig (z. B. Beleg- oder Datensatz-Nr.)
    - "<BK_E1>"
    - "<BK_E2>"
```

Gibt es keine Ereignis-ID, bildet die kleinste eindeutige Spaltenkombination (z. B. Zeitstempel + Sensor + Messgröße) den Schlüssel — vorher auf Eindeutigkeit prüfen.

## Link

```sql
{{ config(
    materialized='incremental',
    as_columnstore=false,
    post_hook=[
        "{{ create_hash_index('hk_link_<ereignis>_tl') }}",
        "{{ create_hash_index('hk_<e1>') }}",
        "{{ create_hash_index('hk_<e2>') }}"
    ]
) }}

{%- set yaml_metadata -%}
source_model: "<staging_model>"
src_pk: "hk_link_<ereignis>_tl"
src_fk: ["hk_<e1>", "hk_<e2>"]
src_ldts: "dss_load_date"
src_source: "dss_record_source"
{%- endset -%}
{% set m = fromyaml(yaml_metadata) %}

{{ automate_dv.link(src_pk=m["src_pk"], src_fk=m["src_fk"], src_ldts=m["src_ldts"],
                    src_source=m["src_source"], source_model=m["source_model"]) }}
```

Alternativ `automate_dv.t_link()` mit `src_payload` und `src_eff`, wenn Link und Attribute in einer Tabelle liegen sollen.

## Transaction Satellite

Wie ein [Satellite](02-satellite.md) am Link-Hash, aber:

- Der Hash Diff wird nur zur Pflicht gebildet; neue Zeilen entstehen, weil jedes Ereignis einen eigenen Hash Key hat.
- **Kein** `update_satellite_current_flag` — jede Zeile ist gültig.
- Bei großen Mengen den inkrementellen Abgleich auf das Ladefenster begrenzen (nur Keys der letzten Tage mit dem Bestand vergleichen) — sonst liest jeder Lauf die ganze Tabelle. Hintergrund: [Lessons Learned – Transaction Satellite für Messdaten](../../../lessons-learned/15-transaction-satellite-fuer-messdaten.md).

## Betrieb

- Eigene Domäne mit Tag (`+tags: [<domain>]` in `dbt_project.yml`), damit der Standardlauf nicht wartet; Laden über `dbt run --select tag:<domain>` bzw. eigenen Pipeline-Job.
- Tests mit vollem Scan (`unique` auf Millionen Zeilen) als `tag:nightly`.
- Oft mit [PSA](../staging/03-psa.md) davor, damit die Dateien nur einmal gelesen werden.

---

◀ [Link erstellen](03-link.md) · [Übersicht](00-raw-vault.md) · [Effectivity Satellite erstellen](05-effectivity-satellite.md) ▶
