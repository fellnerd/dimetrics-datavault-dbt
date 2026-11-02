{#
    Staging: stg_lead_engine__ki_bewertung
    Quelle: base_lead_engine__ki_bewertung (Urteile der KI-Bewertung je Gelegenheit)
    BK Gelegenheit: gelegenheit_bk (= gelegenheit_id aus lead_gelegenheiten_v), Kollisionscode 'lead-engine'.
    dss_load_date = bewertet_am (UTC). Jedes Urteil ist ein eigenes Ereignis: bewertung_id steckt im Hash Diff, damit alle Urteile erhalten bleiben.
    Speist hub_gelegenheit und sat_gelegenheit__ki_bewertung.
    Version: 2026-11-03 V1.0 Initialversion
#}
{{ config(
    materialized='table',
    as_columnstore=false,
    post_hook=["{{ create_hash_index('hk_gelegenheit') }}"]
) }}
{%- set yaml_metadata -%}
source_model: base_lead_engine__ki_bewertung
derived_columns:
  dss_record_source: "!lead-engine/ki-bewertung"
  dss_load_date: "CAST(bewertet_am AS DATETIME2)"
  dss_create_datetime: "CAST(GETDATE() AS DATETIME2)"
  dss_business_key: "CONCAT_WS('||', 'default', 'lead-engine', ISNULL(LTRIM(RTRIM(CAST(gelegenheit_bk AS NVARCHAR(MAX)))), '-1'))"
  collision_code: "!lead-engine"
hashed_columns:
  hk_gelegenheit: [collision_code, gelegenheit_bk]
  hd_gelegenheit__ki_bewertung:
    is_hashdiff: true
    columns: [bewertung_id, ki_einstufung, ki_score, ki_begruendung, ki_anlass, ki_naechster_schritt, ki_baustein, vorscore_bei_bewertung, modell, lauf_id, bewertet_am]
{%- endset -%}

{{ automate_dv.stage(**fromyaml(yaml_metadata)) }}
