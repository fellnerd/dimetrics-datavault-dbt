---
title: "Link erstellen"
tags:
  - entwickler/raw-vault
---
[Dokumentation](../../../README.md) › [Data Vault 2.1 – Developer Guide](../../00-entwicklerhandbuch.md) › [Objekte anlegen](../00-objekte-anlegen.md) › [Raw Vault](00-raw-vault.md)

# Link erstellen

Ein Link verbindet zwei (oder mehr) Hubs — eine Zeile je Kombination von Schlüsseln.

Namenskonvention: `link_<entity_1>_<entity_2>`, **ohne** Quell-Suffix.

## Template

```sql
{#
    Link: link_<e1>_<e2>
    Hubs: hub_<e1>, hub_<e2>
    Source: <staging_model>
    Version: <YYYY-MM-DD> V1.0 Initialversion
#}

{{ config(
    materialized='incremental',
    as_columnstore=false,
    post_hook=["{{ create_hash_index('hk_link_<e1>_<e2>') }}"]
) }}

{%- set yaml_metadata -%}
source_model: "<staging_model>"
src_pk: "hk_link_<e1>_<e2>"
src_fk:
    - "hk_<e1>"
    - "hk_<e2>"
src_ldts: "dss_load_date"
src_source: "dss_record_source"
{%- endset -%}

{% set metadata_dict = fromyaml(yaml_metadata) %}

{{ automate_dv.link(src_pk=metadata_dict["src_pk"],
                    src_fk=metadata_dict["src_fk"],
                    src_ldts=metadata_dict["src_ldts"],
                    src_source=metadata_dict["src_source"],
                    source_model=metadata_dict["source_model"]) }}
```

Links führen kein `dss_business_key` und im Projekt auch kein `dss_create_datetime`.

## Der Link-Hash im Staging

Der Link-Hash wird aus den **Business Keys beider Hubs** gebildet, in der Reihenfolge von `src_fk`:

```yaml
hashed_columns:
  hk_<e1>: "<BK_E1>"
  hk_<e2>: ["<BK_E2_A>", "<BK_E2_B>"]
  hk_link_<e1>_<e2>:
    - "<BK_E1>"          # Business Key von hub_<e1>
    - "<BK_E2_A>"        # ┐
    - "<BK_E2_B>"        # ┘ Business Key von hub_<e2>
```

> **Doppelte Spalten sind hier richtig.** Ist eine Spalte Teil *beider* Hub-Schlüssel, steht sie zweimal. Beispiel Kreditorenbeleg ↔ Zahlung:
>
> ```yaml
> hk_link_kreditorenbeleg_zahlung:
>   - "DOCUMENTNR"     # hub_kreditorenbeleg
>   - "DOCUMENTNR"     # ┐
>   - "POSITIONNR"     # │ hub_zahlung
>   - "ELEMENTTYP"     # │
>   - "INR"            # ┘
> ```
>
> Das sieht nach einem Kopierfehler aus, ist aber die korrekte Verkettung beider Schlüssel. Nachgeprüft: eine Link-Zeile je Zahlung, nichts verloren.

**Prüfen, ob der Grain stimmt:**

```sql
SELECT (SELECT COUNT(*) FROM vault.link_<e1>_<e2>)                 AS link_zeilen,
       (SELECT COUNT(DISTINCT hk_<e2>) FROM vault.link_<e1>_<e2>)  AS schluessel_<e2>;
```

Bei einer 1:n-Beziehung (ein `<e1>` zu vielen `<e2>`) müssen beide Zahlen gleich sein.

## Transaction Link

Für Ereignisse ohne Historisierung (Buchungen, Messwerte, Log-Einträge): `_tl`-Suffix, siehe Skill `dv-patterns` im Plugin.

## Häufige Fehler

| Symptom | Ursache |
|---|---|
| Weniger Link-Zeilen als erwartet | Link-Hash enthält nicht den vollständigen Schlüssel beider Hubs |
| Link zeigt auf nicht existierende Hubs | FK-Hub wird nicht aus demselben Staging bzw. seiner FK-Staging-View geladen |
| `link_…__quelle` | Kein Quell-Suffix bei Links — nur Satellites haben ihn |

---

◀ [Satellite erstellen](02-satellite.md) · [Übersicht](00-raw-vault.md) · [Transaction Link](04-transaction-link.md) ▶
