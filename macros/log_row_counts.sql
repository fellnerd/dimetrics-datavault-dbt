{% macro log_row_counts() %}
  {#
    Gibt Row Counts der unten gelisteten Tabellen aus (Beispielliste — je Projekt anpassen).
    Aufruf: dbt run-operation log_row_counts --target <mandant>-dev
  #}
  {% set tables = [
    ('stg',          'psa_iot_sensor_messung'),
    ('vault',        'hub_vertrag'),
    ('vault',        'hub_kunde'),
    ('vault',        'link_vertrag_kunde'),
    ('vault',        'sat_kunde__crm'),
    ('vault',        'sat_vertrag_eff__crm'),
    ('vault',        'sat_vertrag_optionen_ma__crm'),
    ('vault_iot',    'hub_sensor'),
    ('vault_iot',    'hub_maschine'),
    ('vault_iot',    'link_sensor_maschine'),
    ('vault_iot',    'link_sensor_messung_tl'),
    ('vault_iot',    'sat_sensor_messung__iot'),
  ] %}

  {% do log('', info=true) %}
  {% do log('=== Row Count Summary (' ~ target.database ~ ') ===', info=true) %}

  {% for schema, table in tables %}
    {% set rel = adapter.get_relation(
        database=target.database,
        schema=schema,
        identifier=table
    ) %}
    {% if rel %}
      {% set result = run_query("SELECT COUNT(*) AS cnt FROM " ~ rel) %}
      {% set cnt = result.columns[0].values()[0] %}
      {% do log('  %-45s %s rows' | format(schema ~ '.' ~ table, cnt), info=true) %}
    {% else %}
      {% do log('  %-45s (not deployed yet)' | format(schema ~ '.' ~ table), info=true) %}
    {% endif %}
  {% endfor %}

  {% do log('==========================================', info=true) %}
  {% do log('', info=true) %}
{% endmacro %}
