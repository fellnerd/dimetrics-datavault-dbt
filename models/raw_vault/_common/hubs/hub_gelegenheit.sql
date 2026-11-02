{#
    Hub: hub_gelegenheit
    Source: stg_lead_engine__ki_bewertung
    Business Key: collision_code ('lead-engine') + gelegenheit_bk (cluster_key aus bv_stelle_cluster = gelegenheit_id in lead_gelegenheiten_v)
    Eine Gelegenheit ist ein Cluster derselben Stelle aus mehreren Quellen (Business Vault); der Hub haelt die bewerteten Gelegenheiten,
    damit alle KI-Urteile erhalten bleiben, auch wenn sich der Cluster-Repraesentant aendert oder die Gelegenheit ablaeuft.
    Version: 2026-11-03 V1.0 Initialversion
#}

{{ config(
    materialized='incremental',
    as_columnstore=false,
    post_hook=["{{ create_hash_index('hk_gelegenheit') }}"]
) }}

{%- set yaml_metadata -%}
source_model: "stg_lead_engine__ki_bewertung"
src_pk: "hk_gelegenheit"
src_nk:
  - "collision_code"
  - "gelegenheit_bk"
src_extra_columns:
  - "dss_business_key"
  - "dss_create_datetime"
src_ldts: "dss_load_date"
src_source: "dss_record_source"
{%- endset -%}

{% set metadata_dict = fromyaml(yaml_metadata) %}

{{ automate_dv.hub(src_pk=metadata_dict["src_pk"],
                   src_nk=metadata_dict["src_nk"],
                   src_extra_columns=metadata_dict["src_extra_columns"],
                   src_ldts=metadata_dict["src_ldts"],
                   src_source=metadata_dict["src_source"],
                   source_model=metadata_dict["source_model"]) }}
