{#
    Link: link_stelle_firma
    Source: stg_lead_engine__{karriere,theirstack,website}_stelle
    Foreign Keys: hk_stelle, hk_firma
    Version: 2026-10-25 V1.0 Initialversion
#}

{{ config(
    materialized='incremental',
    as_columnstore=false,
    post_hook=["{{ create_hash_index('hk_link_stelle_firma') }}"]
) }}

{%- set yaml_metadata -%}
source_model:
  - "stg_lead_engine__karriere_stelle"
  - "stg_lead_engine__theirstack_stelle"
  - "stg_lead_engine__website_stelle"
src_pk: "hk_link_stelle_firma"
src_fk:
  - "hk_stelle"
  - "hk_firma"
src_ldts: "dss_load_date"
src_source: "dss_record_source"
{%- endset -%}

{% set metadata_dict = fromyaml(yaml_metadata) %}

{{ automate_dv.link(src_pk=metadata_dict["src_pk"],
                    src_fk=metadata_dict["src_fk"],
                    src_ldts=metadata_dict["src_ldts"],
                    src_source=metadata_dict["src_source"],
                    source_model=metadata_dict["source_model"]) }}
