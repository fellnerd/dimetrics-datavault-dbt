{#
    Staging: stg_lead_engine__firmenbuch_firma
    Quelle: base_lead_engine__firmenbuch_firma (nur sichere Zuordnungen, Lead-Engine, source = 'firmenbuch')
    BK Firma: firma_bk, Kollisionscode = firma_quelle (karriere, ...): gleicher hk_firma wie in den Firmen-Quellen.
    Speist hub_firma und sat_firma__firmenbuch (FN, Name, Sitz, Rechtsform, Gericht, Status; Auszug: Anschrift, Homepage, EUID).
    Kein Delta: je Lauf nur wenige Zeilen; apply_source_filter im Satelliten macht das Wiedereinlesen idempotent.
    Version: 2026-11-02 V1.0 Initialversion
    Version: 2026-11-03 V1.1 Auszug-Felder (Anschrift, Homepage, EUID) im Hash Diff
#}
{{ config(
    materialized='table',
    as_columnstore=false,
    post_hook=["{{ create_hash_index('hk_firma') }}"]
) }}
{%- set yaml_metadata -%}
source_model: base_lead_engine__firmenbuch_firma
derived_columns:
  dss_record_source: "!lead-engine/firmenbuch"
  dss_load_date: "COALESCE(TRY_CAST(fetched_at AS DATETIME2), GETDATE())"
  dss_create_datetime: "CAST(GETDATE() AS DATETIME2)"
  dss_business_key: "CONCAT_WS('||', 'default', firma_quelle, ISNULL(LTRIM(RTRIM(CAST(firma_bk AS NVARCHAR(MAX)))), '-1'))"
  collision_code: "firma_quelle"
hashed_columns:
  hk_firma: [collision_code, firma_bk]
  hd_firma__firmenbuch:
    is_hashdiff: true
    columns: [fn, firmenbuch_name, sitz, rechtsform_code, rechtsform, gericht, firmenbuch_status, adresse_strasse, adresse_plz, adresse_ort, adresse_staat, homepage, euid]
{%- endset -%}

{{ automate_dv.stage(**fromyaml(yaml_metadata)) }}
