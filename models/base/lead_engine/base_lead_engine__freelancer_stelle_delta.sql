{#
    Delta-View: base_lead_engine__freelancer_stelle_delta
    Nur Laeufe von base_lead_engine__freelancer_stelle, die noch nicht im Vault sind (siehe Macro lead_engine_delta).
    Quelle fuer stg_lead_engine__freelancer_stelle, damit Staging und Satelliten nur den neuen Lauf verarbeiten.
#}
{{ config(materialized='view') }}
{{ lead_engine_delta('base_lead_engine__freelancer_stelle', 'sat_stelle_sichtung__freelancer') }}
