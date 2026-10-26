{#
    Delta-View: base_lead_engine__theirstack_stelle_delta
    Nur Laeufe von base_lead_engine__theirstack_stelle, die noch nicht im Vault sind (siehe Macro lead_engine_delta).
    Quelle fuer stg_lead_engine__theirstack_stelle, damit Staging und Satelliten nur den neuen Lauf verarbeiten.
#}
{{ config(materialized='view', post_hook=["EXEC sp_refreshview '{{ this.schema }}.{{ this.identifier }}'"]) }}
-- SELECT * friert die Spaltenliste beim Erstellen ein: der Hook aktualisiert sie, wenn die Base-Tabelle neue Spalten bekommt.
{{ lead_engine_delta('base_lead_engine__theirstack_stelle', 'sat_stelle_sichtung__theirstack') }}
