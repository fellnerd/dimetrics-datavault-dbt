{#
    Staging: stg_lead_engine__adzuna_stelle
    Quelle: base_lead_engine__adzuna_stelle_delta (nur neue Laeufe; Lead-Engine, source = 'adzuna')
    BK Stelle: stelle_bk (Adzuna-ID) · BK Firma: firma_bk (normierter Firmenname, '-1' ohne Namen)
    Kollisionscode: adzuna (Segment 2 von dss_business_key, Teil aller Hash Keys)
    Hashes: hk_stelle -> hub_stelle · hk_firma -> hub_firma (via __firma) · hk_link_stelle_firma
            hd_stelle__adzuna -> sat_stelle__adzuna · hd_firma__adzuna -> sat_firma__adzuna
            hd_stelle_sichtung__adzuna -> sat_stelle_sichtung__adzuna
    Nicht im Hashdiff: Koordinaten, Kategorie-Tag
    Materialisierung: table, weil automate_dv.sat() die Quelle mehrfach liest (siehe stg_lead_engine__karriere_stelle).
    Version: 2026-10-26 V1.0 Initialversion
#}
{{ config(
    materialized='table',
    as_columnstore=false,
    post_hook=["{{ create_hash_index('hk_stelle') }}"]
) }}
{%- set yaml_metadata -%}
source_model: base_lead_engine__adzuna_stelle_delta
derived_columns:
  dss_record_source: "!lead-engine/adzuna"
  dss_load_date: "COALESCE(TRY_CAST(fetched_at AS DATETIME2), GETDATE())"
  dss_create_datetime: "CAST(GETDATE() AS DATETIME2)"
  dss_business_key: "CONCAT_WS('||', 'default', 'adzuna', ISNULL(LTRIM(RTRIM(CAST(stelle_bk AS NVARCHAR(MAX)))), '-1'))"
  collision_code: "!adzuna"
hashed_columns:
  hk_stelle: [collision_code, stelle_bk]
  hk_firma: [collision_code, firma_bk]
  hk_link_stelle_firma: [collision_code, stelle_bk, firma_bk]
  hd_stelle__adzuna:
    is_hashdiff: true
    columns: [title, description, location_name, location_area, category_label, created_am, salary_min, salary_max, salary_is_predicted, contract_type, contract_time, url]
  hd_firma__adzuna:
    is_hashdiff: true
    columns: [firma_name]
  hd_stelle_sichtung__adzuna:
    is_hashdiff: true
    columns: [run_id, query_ids, profil_ids]
{%- endset -%}

{{ automate_dv.stage(**fromyaml(yaml_metadata)) }}
