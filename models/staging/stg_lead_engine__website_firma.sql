{#
    Staging: stg_lead_engine__website_firma
    Quelle: base_lead_engine__website_firma (Lead-Engine, source = 'website', Impressum)
    BK Firma: firma_bk, Kollisionscode = firma_quelle (karriere, theirstack, website): gleicher hk_firma wie in den Firmen-Quellen.
    Hauptentitaet ist die Firma: speist hub_firma direkt und sat_firma__impressum.
    Hashes: hk_firma -> hub_firma · hd_firma__impressum -> sat_firma__impressum
    Kein Delta: je Lauf nur wenige Zeilen; apply_source_filter im Satelliten macht das Wiedereinlesen idempotent.
    Version: 2026-11-02 V1.0 Initialversion
#}
{{ config(
    materialized='table',
    as_columnstore=false,
    post_hook=["{{ create_hash_index('hk_firma') }}"]
) }}
{%- set yaml_metadata -%}
source_model: base_lead_engine__website_firma
derived_columns:
  dss_record_source: "!lead-engine/website"
  dss_load_date: "COALESCE(TRY_CAST(fetched_at AS DATETIME2), GETDATE())"
  dss_create_datetime: "CAST(GETDATE() AS DATETIME2)"
  dss_business_key: "CONCAT_WS('||', 'default', firma_quelle, ISNULL(LTRIM(RTRIM(CAST(firma_bk AS NVARCHAR(MAX)))), '-1'))"
  collision_code: "firma_quelle"
hashed_columns:
  hk_firma: [collision_code, firma_bk]
  hd_firma__impressum:
    is_hashdiff: true
    columns: [fn, uid, plz, ort, firmenname, konzern_hinweis, fremde_jobdomain]
{%- endset -%}

{{ automate_dv.stage(**fromyaml(yaml_metadata)) }}
