{#
    Staging: stg_lead_engine__firmenbuch_ereignis
    Quelle: base_lead_engine__firmenbuch_ereignis (Veraenderungen im Firmenbuch, zugeordnet ueber die FN der sicheren Zuordnungen)
    Signal je Firma und Zeitraum: Anzahl, juengstes Datum, juengste Art, Arten. Hash Key wie in den Firmen-Quellen.
    Speist sat_firma__firmenbuch_ereignis (Signal-Satellit).
    Version: 2026-11-02 V1.0 Initialversion
#}
{{ config(
    materialized='table',
    as_columnstore=false,
    post_hook=["{{ create_hash_index('hk_firma') }}"]
) }}
{%- set yaml_metadata -%}
source_model: base_lead_engine__firmenbuch_ereignis
derived_columns:
  dss_record_source: "!lead-engine/firmenbuch"
  dss_load_date: "COALESCE(TRY_CAST(fetched_at AS DATETIME2), GETDATE())"
  dss_create_datetime: "CAST(GETDATE() AS DATETIME2)"
  dss_business_key: "CONCAT_WS('||', 'default', firma_quelle, ISNULL(LTRIM(RTRIM(CAST(firma_bk AS NVARCHAR(MAX)))), '-1'))"
  collision_code: "firma_quelle"
hashed_columns:
  hk_firma: [collision_code, firma_bk]
  hd_firma__firmenbuch_ereignis:
    is_hashdiff: true
    columns: [zeitraum_von, zeitraum_bis, anzahl_veraenderungen, letzte_veraenderung_am, letzte_art, arten]
{%- endset -%}

{{ automate_dv.stage(**fromyaml(yaml_metadata)) }}
