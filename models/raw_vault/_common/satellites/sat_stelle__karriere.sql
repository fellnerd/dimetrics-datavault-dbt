{#
    Satellite: sat_stelle__karriere
    Parent Hub: hub_stelle
    Source: stg_lead_engine__karriere_stelle
    Payload: Titel, Link, posted_date (abgeleitet), Beschaeftigungsart, Gehalt, Homeoffice, Orte, aktiv
    Nicht im Hashdiff: date_text (relativ), summary, snippet
    Version: 2026-10-25 V1.0 Initialversion
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
source_model: "stg_lead_engine__karriere_stelle"
src_pk: "hk_stelle"
src_hashdiff:
  source_column: "hd_stelle__karriere"
  alias: "hashdiff"
src_payload:
  - title
  - link
  - posted_date
  - employment_types
  - salary
  - is_home_office
  - locations
  - is_active
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
