{% macro lead_engine_delta(base_model, sichtung_sat) %}
{#- Delta der Lead-Engine-Base-Tabelle: nur Laeufe, die der Vault noch nicht verarbeitet hat.
    Wasserstand = hoechste run_id im Sichtungs-Satelliten der Quelle. Der Sichtungs-Satellit wird je Quelle
    als letztes Objekt geladen (-- depends_on in den Sichtungs-Satelliten); bricht ein Lauf vorher ab,
    bleibt der Wasserstand stehen und der naechste Lauf holt den Rest nach (automate_dv apply_source_filter
    macht das Wiedereinlesen idempotent). Existiert der Satellit noch nicht (Erstladung), gibt es keinen Filter.
    Verwendung: {{ lead_engine_delta('base_lead_engine__karriere_stelle', 'sat_stelle_sichtung__karriere') }}
-#}
{%- set rel = adapter.get_relation(database=target.database, schema='vault', identifier=sichtung_sat) -%}
SELECT * FROM {{ ref(base_model) }}
{%- if execute and rel is not none %}
WHERE run_id > COALESCE((SELECT MAX(run_id) FROM {{ rel }}), '')
{%- endif %}
{% endmacro %}
