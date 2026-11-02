{#
    Satellite: sat_firma__jahresabschluss
    Parent Hub: hub_firma
    Source: stg_lead_engine__firmenbuch_jahresabschluss
    Payload: Kennzahlen des juengsten Jahresabschlusses aus dem Firmenbuch (Stichtag, Einreichung, Groessenklasse, Bilanzsumme, Umsatzerloese,
             Eigenkapital, Jahresergebnis, durchschnittliche Mitarbeiterzahl). Umsatz, Ergebnis und Mitarbeiter nur, wenn die Firma sie offenlegt (sonst NULL).
             Das Bilanz-XML und Personen werden nicht uebernommen.
    Version: 2026-11-03 V1.0 Initialversion
#}

{{ config(
    materialized='incremental',
    as_columnstore=false,
    meta={'apply_source_filter': true},
    post_hook=[
        "{{ create_hash_index('hk_firma') }}",
        "{{ update_satellite_current_flag(this, 'hk_firma') }}"
    ]
) }}

{%- set yaml_metadata -%}
source_model: "stg_lead_engine__firmenbuch_jahresabschluss"
src_pk: "hk_firma"
src_hashdiff:
  source_column: "hd_firma__jahresabschluss"
  alias: "hashdiff"
src_payload:
  - stichtag
  - eingereicht_am
  - groessenklasse_code
  - groessenklasse
  - bilanzsumme
  - umsatzerloese
  - eigenkapital
  - jahresergebnis
  - mitarbeiter_durchschnitt
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
