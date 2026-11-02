{#
    Staging: stg_lead_engine__ted_stelle
    Quelle: base_lead_engine__ted_stelle_delta (nur neue Laeufe; Lead-Engine, source = 'ted')
    BK Stelle: stelle_bk (publication-number der Bekanntmachung), Kollisionscode ted.
    Kein Firmen-Hub/Link: TED nennt nur den Namen des Auftraggebers (Attribut buyer_name), keine ID.
    Hashes: hk_stelle -> hub_stelle · hd_stelle__ted -> sat_stelle__ted · hd_stelle_sichtung__ted -> sat_stelle_sichtung__ted
    Materialisierung: table, weil automate_dv.sat() die Quelle mehrfach liest (siehe stg_lead_engine__karriere_stelle).
    Version: 2026-11-02 V1.0 Initialversion
#}
{{ config(
    materialized='table',
    as_columnstore=false,
    post_hook=["{{ create_hash_index('hk_stelle') }}"]
) }}
{%- set yaml_metadata -%}
source_model: base_lead_engine__ted_stelle_delta
derived_columns:
  dss_record_source: "!lead-engine/ted"
  dss_load_date: "COALESCE(TRY_CAST(fetched_at AS DATETIME2), GETDATE())"
  dss_create_datetime: "CAST(GETDATE() AS DATETIME2)"
  dss_business_key: "CONCAT_WS('||', 'default', 'ted', ISNULL(LTRIM(RTRIM(CAST(stelle_bk AS NVARCHAR(MAX)))), '-1'))"
  collision_code: "!ted"
hashed_columns:
  hk_stelle: [collision_code, stelle_bk]
  hd_stelle__ted:
    is_hashdiff: true
    columns: [titel, notice_type, buyer_name, buyer_city, publication_date, deadline_date, description, place, cpv, url]
  hd_stelle_sichtung__ted:
    is_hashdiff: true
    columns: [run_id, query_ids, profil_ids]
{%- endset -%}

{{ automate_dv.stage(**fromyaml(yaml_metadata)) }}
