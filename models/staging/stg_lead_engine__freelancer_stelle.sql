{#
    Staging: stg_lead_engine__freelancer_stelle
    Quelle: base_lead_engine__freelancer_stelle_delta (nur neue Laeufe; Lead-Engine, source = 'freelancer', Liste + Detail)
    BK Stelle: stelle_bk (Auftrags-ID, Text). Kein Firmen-Hub und kein Link: der Auftraggeber ist unbekannt
               (Auftraege kommen fast immer von Vermittlern), firma_bk waere konstant '-1'.
    Kollisionscode: freelancer (Segment 2 von dss_business_key, Teil des Hash Keys)
    Hashes: hk_stelle -> hub_stelle
            hd_stelle__freelancer -> sat_stelle__freelancer
            hd_stelle_sichtung__freelancer -> sat_stelle_sichtung__freelancer
    Nicht im Hashdiff: zuletzt_geaendert_am, antworten, anzahl_reaktionen (aendern sich staendig)
    Materialisierung: table, weil automate_dv.sat() die Quelle mehrfach liest (siehe stg_lead_engine__karriere_stelle).
    Version: 2026-10-26 V1.0 Initialversion
#}
{{ config(
    materialized='table',
    as_columnstore=false,
    post_hook=["{{ create_hash_index('hk_stelle') }}"]
) }}
{%- set yaml_metadata -%}
source_model: base_lead_engine__freelancer_stelle_delta
derived_columns:
  dss_record_source: "!lead-engine/freelancer"
  dss_load_date: "COALESCE(TRY_CAST(fetched_at AS DATETIME2), GETDATE())"
  dss_create_datetime: "CAST(GETDATE() AS DATETIME2)"
  dss_business_key: "CONCAT_WS('||', 'default', 'freelancer', ISNULL(LTRIM(RTRIM(CAST(stelle_bk AS NVARCHAR(MAX)))), '-1'))"
  collision_code: "!freelancer"
hashed_columns:
  hk_stelle: [collision_code, stelle_bk]
  hd_stelle__freelancer:
    is_hashdiff: true
    columns: [title, url, beschreibung, kategorie, budget, location, status, veroeffentlicht_am]
  hd_stelle_sichtung__freelancer:
    is_hashdiff: true
    columns: [run_id, query_ids, profil_ids]
{%- endset -%}

{{ automate_dv.stage(**fromyaml(yaml_metadata)) }}
