{#
    Hub: hub_firma
    Source: stg_lead_engine__{karriere,theirstack,website}_stelle__firma (FK-Staging, Multi-Source)
    Business Key: collision_code + firma_bk (karriere companyId, theirstack company_object.id, website Domain; '-1' = unbekannt)
    Quelluebergreifende Zusammenfuehrung derselben Firma: spaeter Same-as-Link im Business Vault.
    Version: 2026-10-25 V1.0 Initialversion
#}

{{ config(
    materialized='incremental',
    as_columnstore=false,
    post_hook=["{{ create_hash_index('hk_firma') }}"]
) }}

{%- set yaml_metadata -%}
source_model:
  - "stg_lead_engine__karriere_stelle__firma"
  - "stg_lead_engine__theirstack_stelle__firma"
  - "stg_lead_engine__website_stelle__firma"
src_pk: "hk_firma"
src_nk:
  - "collision_code"
  - "firma_bk"
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
