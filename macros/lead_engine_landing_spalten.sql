{% macro lead_engine_landing_spalten() %}
{#- Typisiert source und run_id in landing.lead_engine_datei (dlt legt Text als nvarchar(max) an, das ist kein gueltiger Indexschluessel)
    und legt den Index ix_lead_engine_datei_source_run (source, run_id) an. Laeuft als on-run-start-Hook, idempotent:
    - ALTER COLUMN nur, wenn die Spalte noch max_length = -1 hat; vorher Abbruch, wenn eine Laenge > 40 vorkommt. Nullbarkeit bleibt wie sie ist.
    - Index nur, wenn er fehlt. dlt haengt nur an, der Index stoert nicht.
    Den ersten Lauf nicht zwischen 04:45 und 06:00 und nicht um 12:30 starten (geplante dlt-Laeufe).
    Ohne Verbindung (dbt parse, docs) oder ohne Tabelle (leere Umgebung) passiert nichts. -#}
  {%- if not execute -%}
    {{ return('') }}
  {%- endif -%}
  {% set spalten = run_query("
    select c.name, c.max_length, c.is_nullable
    from sys.columns c
    where c.object_id = object_id('landing.lead_engine_datei') and c.name in ('source', 'run_id')") %}
  {% if spalten.rows | length == 0 %}
    {{ return('') }}
  {% endif %}
  {% for sp in spalten.rows %}
    {% if sp[1] == -1 %}
      {% set maxlen = run_query('select coalesce(max(len([' ~ sp[0] ~ '])), 0) from landing.lead_engine_datei').columns[0].values()[0] %}
      {% if maxlen > 40 %}
        {{ exceptions.raise_compiler_error("landing.lead_engine_datei." ~ sp[0] ~ ": laengster Wert hat " ~ maxlen ~ " Zeichen (> 40), Umstellung auf nvarchar(40) abgebrochen") }}
      {% endif %}
      {% do run_query('alter table landing.lead_engine_datei alter column [' ~ sp[0] ~ '] nvarchar(40) ' ~ ('null' if sp[2] else 'not null')) %}
      {{ log("landing.lead_engine_datei." ~ sp[0] ~ " auf nvarchar(40) umgestellt", info=True) }}
    {% endif %}
  {% endfor %}
  {% set idx %}
    IF NOT EXISTS (select 1 from sys.indexes where name = 'ix_lead_engine_datei_source_run' and object_id = object_id('landing.lead_engine_datei'))
       AND NOT EXISTS (select 1 from sys.columns where object_id = object_id('landing.lead_engine_datei') and name in ('source', 'run_id') and max_length = -1)
        CREATE NONCLUSTERED INDEX ix_lead_engine_datei_source_run ON landing.lead_engine_datei (source, run_id)
  {% endset %}
  {% do run_query(idx) %}
{% endmacro %}
