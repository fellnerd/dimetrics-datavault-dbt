---
title: "Dependent Child Satellite (DC Sat) erstellen"
tags:
  - entwickler/raw-vault
---
[Dokumentation](../../../README.md) › [Data Vault 2.1 – Developer Guide](../../00-entwicklerhandbuch.md) › [Objekte anlegen](../00-objekte-anlegen.md) › [Raw Vault](00-raw-vault.md)

# Dependent Child Satellite (DC Sat) erstellen

Ein **Dependent Child Satellite** wird verwendet, wenn ein Link zusätzliche Schlüsselspalten (DCK - Dependent Child Keys) benötigt, um Zeilen auf einer feineren Granularität zu unterscheiden.

**Anwendungsfälle:**
- Bestellpositionen (Order → Product + Positionsnummer)
- Kontaktadressen (Person → AddressType + Adresse)
- Telefonnummern (Company → PhoneType + Nummer)

#### Staging-View Anforderungen

Die Staging-View muss für DC Satellites **zusätzliche Hash-Berechnungen** enthalten. Mit automate_dv.stage() werden alle Hashes im YAML-Metadata Block definiert:

```sql
-- Beispiel: jira_order_item.sql (mit DCK: line_item_no)

{%- set yaml_metadata -%}
source_model:
  staging: "ext_jira_order_item"

derived_columns:
  dss_record_source: "!jira"
  dss_load_date: "COALESCE(TRY_CAST(dss_load_date AS DATETIME2), GETDATE())"
  dss_create_datetime: "CAST(GETDATE() AS DATETIME2)"
  dss_business_key: "CONCAT_WS('||', 'default', 'default', ISNULL(LTRIM(RTRIM(CAST(order_id AS NVARCHAR(MAX)))), '-1'))"

hashed_columns:
  hk_order_item: "order_id"
  hk_link_order_product:
    - "order_id"
    - "product_id"
    - "line_item_no"
  hd_order_item:
    is_hashdiff: true
    columns:
      - "discount"
      - "quantity"
      - "unit_price"
  hd_order_product_dc:
    is_hashdiff: true
    columns:
      - "discount"
      - "line_item_no"
      - "quantity"
      - "unit_price"
{%- endset -%}

{% set metadata_dict = fromyaml(yaml_metadata) %}

{{ automate_dv.stage(include_source_columns=true,
                     source_model=metadata_dict['source_model'],
                     derived_columns=metadata_dict['derived_columns'],
                     hashed_columns=metadata_dict['hashed_columns']) }}
```

#### DC Satellite Model

```sql
-- sat_order_product_dc.sql
{{ config(
    materialized='incremental',
    as_columnstore=false
) }}

{%- set yaml_metadata -%}
source_model: "jira_order_item"
src_pk: "hk_link_order_product"
src_hashdiff: 
  source_column: "hd_order_product_dc"
  alias: "hashdiff"
src_payload:
    - "line_item_no"
    - "quantity"
    - "unit_price"
    - "discount"
src_ldts: "dss_load_date"
src_source: "dss_record_source"
src_extra_columns:
  - "dss_create_datetime"
{%- endset -%}

{% set metadata_dict = fromyaml(yaml_metadata) %}

{{ automate_dv.sat(
    src_pk=metadata_dict["src_pk"],
    src_hashdiff=metadata_dict["src_hashdiff"],
    src_payload=metadata_dict["src_payload"],
    src_ldts=metadata_dict["src_ldts"],
    src_source=metadata_dict["src_source"],
    src_extra_columns=metadata_dict["src_extra_columns"],
    source_model=metadata_dict["source_model"]
) }}
```

---

◀ [Effectivity Satellite erstellen](05-effectivity-satellite.md) · [Übersicht](00-raw-vault.md) · [Multi-Active Satellite (MA Sat) erstellen](07-multi-active-satellite.md) ▶
