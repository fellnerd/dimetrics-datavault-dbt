{% macro create_load_status_table() %}
  {% set sql %}
    IF OBJECT_ID('vault.load_status', 'U') IS NULL
    CREATE TABLE vault.load_status (
        id                  INT IDENTITY(1,1) PRIMARY KEY,
        pipeline_name       NVARCHAR(100)  NOT NULL,
        dss_run_id          NVARCHAR(255),
        status              NVARCHAR(50)   NOT NULL,
        started_at          DATETIME2,
        completed_at        DATETIME2,
        target_database     NVARCHAR(100),
        dss_record_source   NVARCHAR(255),
        dss_load_date       DATETIME2,
        dss_create_datetime DATETIME2      DEFAULT GETDATE(),
        model_count         INT,
        details             NVARCHAR(MAX)
    )
  {% endset %}
  {% do run_query(sql) %}
  {{ log("vault.load_status created (or already exists)", info=True) }}
{% endmacro %}


{% macro log_load_status(results=none) %}
  {#-
    Schreibt die Zeile, gegen die load_status_pending_v prüft, ob ein ADF-Load
    schon von dbt verarbeitet wurde. Aufruf: on-run-end "{{ log_load_status(results) }}".

    Nur vollständige Läufe zählen (dbt run / dbt build ohne --select; --exclude zählt
    als vollständig). Vorher hat jeder Aufruf mit on-run-end geloggt — auch dbt test und
    selektive Läufe (z. B. Massendaten-Jobs mit --select tag:<domain>). Endete ein ADF-Load während eines solchen
    Laufs, galt er danach als verarbeitet und der ADF-getriggerte Lauf wurde still übersprungen.

    started_at = Start des dbt-Laufs (UTC, wie GETDATE() auf Azure SQL): ein ADF-Load,
    der erst während des Laufs fertig wird, bleibt dadurch "pending".
    status = 'failed', wenn Modelle mit Fehler endeten (on-run-end läuft auch dann);
    details = Anzahl Fehler. Die View behandelt 'failed' wie 'completed' (kein Auto-Retry).
    Fehlt 'which' (unbekannte dbt-Version), wird wie bisher geloggt.
  -#}
  {% set which = invocation_args_dict.get('which') %}
  {% if which is not none and (which not in ['run', 'build'] or invocation_args_dict.get('select')) %}
    {{ log("load_status nicht geschrieben (" ~ which ~ ", select=" ~ invocation_args_dict.get('select') ~ ")", info=True) }}
    {{ return('') }}
  {% endif %}

  {% set ns = namespace(total=0, errors=0) %}
  {% for res in (results or []) %}
    {% set ns.total = ns.total + 1 %}
    {% if res.status in ['error', 'fail', 'runtime error'] %}
      {% set ns.errors = ns.errors + 1 %}
    {% endif %}
  {% endfor %}
  {% set run_status = 'failed' if ns.errors > 0 else 'completed' %}

  {#- started_at existiert seit create_load_status_table; für ältere Tabellen nachziehen -#}
  {% do run_query("IF COL_LENGTH('vault.load_status', 'started_at') IS NULL ALTER TABLE vault.load_status ADD started_at DATETIME2 NULL") %}

  {% set sql %}
    INSERT INTO vault.load_status (
        pipeline_name,
        dss_run_id,
        status,
        started_at,
        completed_at,
        target_database,
        dss_record_source,
        dss_load_date,
        dss_create_datetime,
        model_count,
        details
    ) VALUES (
        'dbt_run',
        '{{ invocation_id }}',
        '{{ run_status }}',
        CONVERT(DATETIME2, '{{ run_started_at.strftime("%Y-%m-%d %H:%M:%S") }}', 120),
        GETDATE(),
        '{{ target.database }}',
        'dbt',
        CAST(GETDATE() AS DATE),
        GETDATE(),
        {{ ns.total }},
        {% if ns.errors > 0 %}'{{ ns.errors }} Knoten mit Fehler'{% else %}NULL{% endif %}
    )
  {% endset %}
  {% do run_query(sql) %}
  {{ log("load_status " ~ run_status ~ " für Invocation " ~ invocation_id ~ " (" ~ ns.total ~ " Knoten, " ~ ns.errors ~ " Fehler)", info=True) }}
{% endmacro %}