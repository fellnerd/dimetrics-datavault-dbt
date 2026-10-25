---
title: "Multi-Active Satellite (MA Sat) erstellen"
tags:
  - entwickler/raw-vault
---
[Dokumentation](../../../README.md) › [Data Vault 2.1 – Developer Guide](../../00-entwicklerhandbuch.md) › [Objekte anlegen](../00-objekte-anlegen.md) › [Raw Vault](00-raw-vault.md)

# Multi-Active Satellite (MA Sat) erstellen

Ein **Multi-Active Satellite** erlaubt **mehrere gleichzeitig gültige Werte** für denselben Business Key.

> **VS Code Extension:** Im Entity Designer Spalten als `📚 Multi-Active Key` markieren. MA Satellites werden automatisch beim Klick auf "Generate Satellites" oder "Generate All" erstellt.
> **Wichtig:** MA Sat benötigt mindestens eine Hub-Spalte (Business Key) - im Gegensatz zu DC Sat.

**Anwendungsfälle:**
- Mehrere Telefonnummern pro Kunde (phone_type unterscheidet)
- Mehrere Rollen pro Mitarbeiter (role unterscheidet)
- Mehrere Adressen pro Person (address_type unterscheidet)

#### Staging-View Anforderungen

```sql
-- Beispiel: jira_employee_phone.sql (mit CDK: phone_type)

{%- set yaml_metadata -%}
source_model:
  staging: "ext_jira_employee_phone"

derived_columns:
  dss_record_source: "!jira"
  dss_load_date: "COALESCE(TRY_CAST(dss_load_date AS DATETIME2), GETDATE())"
  dss_create_datetime: "CAST(GETDATE() AS DATETIME2)"
  dss_business_key: "CONCAT_WS('||', 'default', 'default', ISNULL(LTRIM(RTRIM(CAST(employee_id AS NVARCHAR(MAX)))), '-1'))"

hashed_columns:
  hk_employee: "employee_id"
  hd_employee__jira:
    is_hashdiff: true
    columns:
      - "is_primary"
      - "phone_number"
  hd_employee_phone_ma__jira:
    is_hashdiff: true
    columns:
      - "is_primary"
      - "phone_number"
      - "phone_type"
{%- endset -%}

{% set metadata_dict = fromyaml(yaml_metadata) %}

{{ automate_dv.stage(include_source_columns=true,
                     source_model=metadata_dict['source_model'],
                     derived_columns=metadata_dict['derived_columns'],
                     hashed_columns=metadata_dict['hashed_columns']) }}
```

#### MA Satellite Model

```sql
-- sat_employee_phone_ma__jira.sql
{{ config(
    materialized='incremental',
    as_columnstore=false,
    post_hook=[
        "{{ create_hash_index('hk_employee') }}",
        "{{ update_satellite_current_flag(this, 'hk_employee') }}"
    ]
) }}

{%- set yaml_metadata -%}
source_model: "jira_employee_phone"
src_pk: "hk_employee"
src_cdk:
    - "phone_type"
src_hashdiff: 
  source_column: "hd_employee_phone_ma__jira"
  alias: "hashdiff"
src_payload:
    - "phone_number"
    - "is_primary"
src_eff: "dss_load_date"
src_extra_columns:
    - "dss_create_datetime"
src_ldts: "dss_load_date"
src_source: "dss_record_source"
{%- endset -%}

{% set metadata_dict = fromyaml(yaml_metadata) %}

{{ automate_dv.ma_sat(
    src_pk=metadata_dict["src_pk"],
    src_cdk=metadata_dict["src_cdk"],
    src_hashdiff=metadata_dict["src_hashdiff"],
    src_payload=metadata_dict["src_payload"],
    src_eff=metadata_dict["src_eff"],
    src_extra_columns=metadata_dict["src_extra_columns"],
    src_ldts=metadata_dict["src_ldts"],
    src_source=metadata_dict["src_source"],
    source_model=metadata_dict["source_model"]
) }}
```

#### Unterschied DC Sat vs MA Sat

| Aspekt | DC Sat | MA Sat |
|--------|--------|--------|
| **Parent** | Link | Hub |
| **Hash Key** | Link Hash + DCK | Hub Hash |
| **Uniqueness** | Link + DCK + Zeit | Hub + CDK + Zeit |
| **automate_dv Macro** | `sat` | `ma_sat` |
| **Anwendung** | Zeilen auf Link-Ebene | Mehrere Werte pro Entity |

---

◀ [Dependent Child Satellite (DC Sat) erstellen](06-dependent-child-satellite.md) · [Übersicht](00-raw-vault.md) · [Reference Table erstellen](08-reference-table.md) ▶
