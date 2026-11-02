{#
    Delta-View: base_lead_engine__karriere_detail_delta
    Nur Laeufe von base_lead_engine__karriere_detail, die noch nicht im Vault sind (Macro lead_engine_delta). Die Detailseiten gehoeren zu
    denselben Laeufen wie die karriere-Suche, Wasserstand daher der Sichtungs-Satellit sat_stelle_sichtung__karriere.
#}
{{ config(materialized='view', post_hook=["EXEC sp_refreshview '{{ this.schema }}.{{ this.identifier }}'"]) }}
-- SELECT * friert die Spaltenliste beim Erstellen ein: der Hook aktualisiert sie, wenn die Base-Tabelle neue Spalten bekommt.
{{ lead_engine_delta('base_lead_engine__karriere_detail', 'sat_stelle_sichtung__karriere') }}
