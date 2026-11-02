{#
    Satellite: sat_gelegenheit__ki_bewertung
    Parent Hub: hub_gelegenheit
    Source: stg_lead_engine__ki_bewertung
    Payload: Urteil der KI-Bewertung (Einstufung A/B/C/X, Score, Begruendung, Anlass, naechster Schritt, Baustein, Vorscore bei der Bewertung, Modell, Lauf).
    Jedes Urteil bleibt als eigene Zeile erhalten (bewertung_id im Hash Diff); dss_is_current markiert das juengste Urteil je Gelegenheit.
    Version: 2026-11-03 V1.0 Initialversion
#}

{{ config(
    materialized='incremental',
    as_columnstore=false,
    meta={'apply_source_filter': true},
    post_hook=[
        "{{ create_hash_index('hk_gelegenheit') }}",
        "{{ update_satellite_current_flag(this, 'hk_gelegenheit') }}"
    ]
) }}

{%- set yaml_metadata -%}
source_model: "stg_lead_engine__ki_bewertung"
src_pk: "hk_gelegenheit"
src_hashdiff:
  source_column: "hd_gelegenheit__ki_bewertung"
  alias: "hashdiff"
src_payload:
  - bewertung_id
  - ki_einstufung
  - ki_score
  - ki_begruendung
  - ki_anlass
  - ki_naechster_schritt
  - ki_baustein
  - vorscore_bei_bewertung
  - modell
  - lauf_id
  - bewertet_am
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
