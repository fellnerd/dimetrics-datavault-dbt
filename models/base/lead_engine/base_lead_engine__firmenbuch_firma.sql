{#
    Sicht: base_lead_engine__firmenbuch_firma
    Nur sichere Zuordnungen (qualitaet = 'sicher') mit FN aus base_lead_engine__firmenbuch_zuordnung: Quelle fuer das Staging.
    Unsichere und wahrscheinliche Zuordnungen bleiben in der Base-Tabelle (zur Pruefung), gehen aber nicht in den Vault.
#}
{{ config(materialized='view', post_hook=["EXEC sp_refreshview '{{ this.schema }}.{{ this.identifier }}'"]) }}
select * from {{ ref('base_lead_engine__firmenbuch_zuordnung') }}
where qualitaet = 'sicher' and fn is not null
