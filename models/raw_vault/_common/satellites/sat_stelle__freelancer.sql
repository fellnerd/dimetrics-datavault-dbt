{#
    Satellite: sat_stelle__freelancer
    Parent Hub: hub_stelle
    Source: stg_lead_engine__freelancer_stelle
    Payload: Titel, URL, Beschreibung, Kategorie, Budget, Ort, Status, Veroeffentlichungsdatum (Liste + Detail)
    Nicht im Hashdiff: zuletzt_geaendert_am, antworten, anzahl_reaktionen
    Version: 2026-10-26 V1.0 Initialversion
#}

{{ config(
    materialized='incremental',
    as_columnstore=false,
    meta={'apply_source_filter': true},
    post_hook=[
        "{{ create_hash_index('hk_stelle') }}",
        "{{ update_satellite_current_flag(this, 'hk_stelle') }}"
    ]
) }}

{%- set yaml_metadata -%}
source_model: "stg_lead_engine__freelancer_stelle"
src_pk: "hk_stelle"
src_hashdiff:
  source_column: "hd_stelle__freelancer"
  alias: "hashdiff"
src_payload:
  - title
  - url
  - beschreibung
  - kategorie
  - budget
  - location
  - status
  - veroeffentlicht_am
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
