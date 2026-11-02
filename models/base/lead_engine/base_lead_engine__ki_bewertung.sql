{#
    Sicht: base_lead_engine__ki_bewertung
    Quelle: landing.lead_engine_ki_bewertung (Eingang der KI-Bewertung; der Skill lead-bewertung schreibt ueber den MCP, nur Einfuegen).
    Grain: eine Zeile je Urteil (bewertung_id; per CAST ohne IDENTITY-Eigenschaft, sonst erben Staging und Satellit die IDENTITY-Spalte). Alle Urteile bleiben erhalten; die Tabelle darf leer sein.
    Version: 2026-11-03 V1.0 Initialversion
#}
{{ config(materialized='view', post_hook=["EXEC sp_refreshview '{{ this.schema }}.{{ this.identifier }}'"]) }}
select
    cast(k.bewertung_id as int) as bewertung_id, k.gelegenheit_id as gelegenheit_bk, k.ki_einstufung, k.ki_score, k.ki_begruendung, k.ki_anlass,
    k.ki_naechster_schritt, k.ki_baustein, k.vorscore_bei_bewertung, k.modell, k.lauf_id, k.bewertet_am
from {{ source('lead_engine', 'lead_engine_ki_bewertung') }} k
