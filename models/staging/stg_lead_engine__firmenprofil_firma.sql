{#
    Staging: stg_lead_engine__firmenprofil_firma
    Quelle: base_lead_engine__firmenprofil (Lead-Engine, source = 'firmenprofil')
    BK Firma: firma_bk (company_id der Quelle), Kollisionscode = quelle (karriere, ...). Hauptentitaet ist die Firma:
              speist hub_firma direkt (kein FK-Staging noetig) und sat_firma__firmenprofil.
    Hashes: hk_firma -> hub_firma (gleicher Hash wie in karriere/theirstack/website)
            hd_firma__firmenprofil -> sat_firma__firmenprofil
    Kein Delta: je Lauf nur wenige Zeilen; apply_source_filter im Satelliten macht das Wiedereinlesen idempotent.
    Materialisierung: table (siehe stg_lead_engine__karriere_stelle).
    Version: 2026-10-26 V1.0 Initialversion
#}
{{ config(
    materialized='table',
    as_columnstore=false,
    post_hook=["{{ create_hash_index('hk_firma') }}"]
) }}
{%- set yaml_metadata -%}
source_model: base_lead_engine__firmenprofil
derived_columns:
  dss_record_source: "!lead-engine/firmenprofil"
  dss_load_date: "COALESCE(TRY_CAST(fetched_at AS DATETIME2), GETDATE())"
  dss_create_datetime: "CAST(GETDATE() AS DATETIME2)"
  dss_business_key: "CONCAT_WS('||', 'default', quelle, ISNULL(LTRIM(RTRIM(CAST(firma_bk AS NVARCHAR(MAX)))), '-1'))"
  collision_code: "quelle"
hashed_columns:
  hk_firma: [collision_code, firma_bk]
  hd_firma__firmenprofil:
    is_hashdiff: true
    columns: [firma_name, profil_url, website_url]
{%- endset -%}

{{ automate_dv.stage(**fromyaml(yaml_metadata)) }}
