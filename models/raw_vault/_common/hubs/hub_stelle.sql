{#
    Hub: hub_stelle
    Source: stg_lead_engine__{karriere,theirstack,website,freelancer}_stelle (Multi-Source)
    Business Key: collision_code + stelle_bk (Anzeigen-ID der Quelle; website: Domain|Titel)
    Version: 2026-10-25 V1.0 Initialversion
#}

{{ config(
    materialized='incremental',
    as_columnstore=false,
    post_hook=["{{ create_hash_index('hk_stelle') }}"]
) }}

{%- set yaml_metadata -%}
source_model:
  - "stg_lead_engine__karriere_stelle"
  - "stg_lead_engine__theirstack_stelle"
  - "stg_lead_engine__website_stelle"
  - "stg_lead_engine__freelancer_stelle"
src_pk: "hk_stelle"
src_nk:
  - "collision_code"
  - "stelle_bk"
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
