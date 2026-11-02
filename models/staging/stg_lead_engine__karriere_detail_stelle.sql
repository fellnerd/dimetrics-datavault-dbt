{#
    Staging: stg_lead_engine__karriere_detail_stelle
    Quelle: base_lead_engine__karriere_detail_delta (nur neue Laeufe; Lead-Engine, source = 'karriere_detail')
    BK Stelle: stelle_bk = karriere-Job-ID, Kollisionscode karriere (gleicher hk_stelle wie in stg_lead_engine__karriere_stelle).
    Hashes: hk_stelle -> hub_stelle · hd_stelle_detail__karriere -> sat_stelle__karriere_detail
    Materialisierung: table, weil automate_dv.sat() die Quelle mehrfach liest (siehe stg_lead_engine__karriere_stelle).
    Version: 2026-11-02 V1.0 Initialversion
#}
{{ config(
    materialized='table',
    as_columnstore=false,
    post_hook=["{{ create_hash_index('hk_stelle') }}"]
) }}
{%- set yaml_metadata -%}
source_model: base_lead_engine__karriere_detail_delta
derived_columns:
  dss_record_source: "!lead-engine/karriere_detail"
  dss_load_date: "COALESCE(TRY_CAST(fetched_at AS DATETIME2), GETDATE())"
  dss_create_datetime: "CAST(GETDATE() AS DATETIME2)"
  dss_business_key: "CONCAT_WS('||', 'default', 'karriere', ISNULL(LTRIM(RTRIM(CAST(stelle_bk AS NVARCHAR(MAX)))), '-1'))"
  collision_code: "!karriere"
hashed_columns:
  hk_stelle: [collision_code, stelle_bk]
  hd_stelle_detail__karriere:
    is_hashdiff: true
    columns: [beschreibung, veroeffentlicht_am, gueltig_bis, employment_type, orte_text, plz, region, land, salary_value, salary_unit, salary_currency]
{%- endset -%}

{{ automate_dv.stage(**fromyaml(yaml_metadata)) }}
