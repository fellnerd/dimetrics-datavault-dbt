{#
    Satellite: sat_stelle_sichtung__theirstack (Sichtungs-Satellit)
    Parent Hub: hub_stelle
    Source: stg_lead_engine__theirstack_stelle
    Payload: run_id, query_ids, profil_ids. run_id aendert sich je Lauf, daher eine Zeile je Lauf -> "zuletzt gesehen".
    Version: 2026-10-25 V1.0 Initialversion
    Version: 2026-10-25 V1.1 profil_ids (Suchprofil, das die Stelle im Lauf gefunden hat)
             Neue Payload-Spalte per on_schema_change append_new_columns; aeltere Zeilen NULL.
#}

{#- Wird je Quelle als LETZTES Objekt geladen: sein Wasserstand (max run_id) steuert das Delta im Staging
    (lead_engine_delta). Daher abhaengig von allen anderen Konsumenten desselben Stagings. -#}
-- depends_on: {{ ref('hub_stelle') }}
-- depends_on: {{ ref('hub_firma') }}
-- depends_on: {{ ref('link_stelle_firma') }}
-- depends_on: {{ ref('sat_stelle__theirstack') }}
-- depends_on: {{ ref('sat_firma__theirstack') }}
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
source_model: "stg_lead_engine__theirstack_stelle"
src_pk: "hk_stelle"
src_hashdiff:
  source_column: "hd_stelle_sichtung__theirstack"
  alias: "hashdiff"
src_payload:
  - run_id
  - query_ids
  - profil_ids
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
