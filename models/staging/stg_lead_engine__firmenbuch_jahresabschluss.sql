{#
    Staging: stg_lead_engine__firmenbuch_jahresabschluss
    Quelle: base_lead_engine__firmenbuch_jahresabschluss_firma (Kennzahlen des juengsten Jahresabschlusses, zugeordnet ueber die FN)
    Hash Key wie in den Firmen-Quellen. Speist sat_firma__jahresabschluss.
    Version: 2026-11-03 V1.0 Initialversion
#}
{{ config(
    materialized='table',
    as_columnstore=false,
    post_hook=["{{ create_hash_index('hk_firma') }}"]
) }}
{%- set yaml_metadata -%}
source_model: base_lead_engine__firmenbuch_jahresabschluss_firma
derived_columns:
  dss_record_source: "!lead-engine/firmenbuch"
  dss_load_date: "COALESCE(TRY_CAST(fetched_at AS DATETIME2), GETDATE())"
  dss_create_datetime: "CAST(GETDATE() AS DATETIME2)"
  dss_business_key: "CONCAT_WS('||', 'default', firma_quelle, ISNULL(LTRIM(RTRIM(CAST(firma_bk AS NVARCHAR(MAX)))), '-1'))"
  collision_code: "firma_quelle"
hashed_columns:
  hk_firma: [collision_code, firma_bk]
  hd_firma__jahresabschluss:
    is_hashdiff: true
    columns: [stichtag, groessenklasse_code, bilanzsumme, umsatzerloese, eigenkapital, jahresergebnis, mitarbeiter_durchschnitt]
{%- endset -%}

{{ automate_dv.stage(**fromyaml(yaml_metadata)) }}
