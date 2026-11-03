{#
    Satellite: sat_firma__firmenbuch
    Parent Hub: hub_firma
    Source: stg_lead_engine__firmenbuch_firma
    Payload: Firmenbuchnummer (normalisiert), Name, Sitz, Rechtsform, Gericht, Status laut Firmenbuch (nur sichere Zuordnungen)
    Auszug (Kurzinformation): Geschaeftsanschrift (Strasse, PLZ, Ort, Staat), Homepage, EUID. Funktionstraeger: sat_firma__firmenbuch_funktion.
    Version: 2026-11-02 V1.0 Initialversion
    Version: 2026-11-03 V1.1 Auszug-Felder; neue Spalten per on_schema_change (alte Zeilen behalten NULL, keine Neuaufbau)
#}

{{ config(
    materialized='incremental',
    on_schema_change='append_new_columns',
    as_columnstore=false,
    meta={'apply_source_filter': true},
    post_hook=[
        "{{ create_hash_index('hk_firma') }}",
        "{{ update_satellite_current_flag(this, 'hk_firma') }}"
    ]
) }}

{%- set yaml_metadata -%}
source_model: "stg_lead_engine__firmenbuch_firma"
src_pk: "hk_firma"
src_hashdiff:
  source_column: "hd_firma__firmenbuch"
  alias: "hashdiff"
src_payload:
  - fn
  - firmenbuch_name
  - sitz
  - rechtsform_code
  - rechtsform
  - gericht
  - firmenbuch_status
  - adresse_strasse
  - adresse_plz
  - adresse_ort
  - adresse_staat
  - homepage
  - euid
src_extra_columns:
  - "dss_create_datetime"
src_ldts: "dss_load_date"
src_source: "dss_record_source"
{%- endset -%}

{% set metadata_dict = fromyaml(yaml_metadata) %}

{{ automate_dv.sat(src_pk=metadata_dict["src_pk"],
                   src_hashdiff=metadata_dict["src_hashdiff"],
                   src_payload=metadata_dict["src_payload"],
                   src_extra_columns=metadata_dict["src_extra_columns"],
                   src_ldts=metadata_dict["src_ldts"],
                   src_source=metadata_dict["src_source"],
                   source_model=metadata_dict["source_model"]) }}
