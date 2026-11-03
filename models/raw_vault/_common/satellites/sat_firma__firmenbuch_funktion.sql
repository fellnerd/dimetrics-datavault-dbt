{#
    Satellite (Multi-Active): sat_firma__firmenbuch_funktion
    Parent Hub: hub_firma
    Source: stg_lead_engine__firmenbuch_funktion
    CDK: funktion_code + pnr (Funktion und Personennummer im Auszug)
    Payload: Funktion (Text), Titel, Titel nachgestellt, Vorname, Nachname (bei juristischen Personen die Bezeichnung, ist_person = 0), seit (DATVON).
    Nicht enthalten: Geburtsdatum, Privatanschrift. Gruppenweise historisiert: ein neuer Auszug mit anderer Besetzung legt die ganze Gruppe neu an.
    Version: 2026-11-03 V1.0 Initialversion
#}

{{ config(
    materialized='incremental',
    as_columnstore=false,
    post_hook=[
        "{{ create_hash_index('hk_firma') }}",
        "{{ update_satellite_current_flag(this, 'hk_firma') }}"
    ]
) }}

{%- set yaml_metadata -%}
source_model: "stg_lead_engine__firmenbuch_funktion"
src_pk: "hk_firma"
src_cdk:
  - "funktion_code"
  - "pnr"
src_hashdiff:
  source_column: "hd_firma__firmenbuch_funktion"
  alias: "hashdiff"
src_payload:
  - funktion
  - titel
  - titel_nach
  - vorname
  - nachname
  - ist_person
  - seit
src_extra_columns:
  - "dss_create_datetime"
src_ldts: "dss_load_date"
src_source: "dss_record_source"
{%- endset -%}

{% set metadata_dict = fromyaml(yaml_metadata) %}

{{ automate_dv.ma_sat(src_pk=metadata_dict["src_pk"],
                      src_cdk=metadata_dict["src_cdk"],
                      src_hashdiff=metadata_dict["src_hashdiff"],
                      src_payload=metadata_dict["src_payload"],
                      src_extra_columns=metadata_dict["src_extra_columns"],
                      src_ldts=metadata_dict["src_ldts"],
                      src_source=metadata_dict["src_source"],
                      source_model=metadata_dict["source_model"]) }}
