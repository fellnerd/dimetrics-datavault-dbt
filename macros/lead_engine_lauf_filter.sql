{% macro lead_engine_lauf_filter(alias='f') %}
{#- Filter der inkrementellen Base-Tabellen auf Landing-Dateien vollstaendiger, noch nicht uebernommener Laeufe.
    - vollstaendig: Das Laufprotokoll (landing.lead_engine_lauf) wird erst geschrieben, wenn alle Quellen des Laufs fertig
      sind, und dlt laedt es vor dbt. Ein Lauf mit Protokoll ist also vollstaendig.
    - noch nicht uebernommen: Anti-Join statt "run_id > max(run_id)". So wird ein Lauf nachgeholt, dessen Protokoll erst
      nach einem neueren Lauf geladen wurde. Begrenzt auf die letzten Tage (var lead_engine_nachholtage, Standard 7),
      run_id ist ein UTC-Zeitstempel JJJJMMTTTHHMMSSZ und als Text sortierbar.
    - manuell freigegeben: Laeufe ohne Protokoll (manuell erzeugt oder abgebrochen) werden bewusst NICHT automatisch uebernommen,
      weil ein unvollstaendiger Lauf Stellen faelschlich als "nicht mehr online" erscheinen laesst. Pruefte man einen solchen Lauf
      und will ihn haben, steht seine run_id in var lead_engine_freigegebene_laeufe (dbt_project.yml).
    Verwendung (in der WHERE-Klausel nach "where f.source = ..."): {{ lead_engine_lauf_filter('f') }}
-#}
{%- set freigegeben = (var('lead_engine_freigegebene_laeufe', []) | map('string') | map('tojson') | join(', ') | replace('"', "'")) or "''" -%}
{%- set grenze = "format(dateadd(day, -" ~ var('lead_engine_nachholtage', 7) ~ ", sysutcdatetime()), 'yyyyMMdd\"T\"HHmmss\"Z\"')" -%}
and ({{ alias }}.run_id in (select run_id from {{ source('lead_engine', 'lead_engine_lauf') }})
     or {{ alias }}.run_id in ({{ freigegeben }}))
{%- if is_incremental() %}
and {{ alias }}.run_id >= {{ grenze }}
and {{ alias }}.run_id not in (select run_id from {{ this }} where run_id >= {{ grenze }})
{%- endif %}
{% endmacro %}
