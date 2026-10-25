# Macros für OLS und RLS

Alle generisch — Platzhalter in spitzen Klammern durch Projektwerte ersetzen.

## `sec_value_key` — Pfad-Schlüssel bauen

```jinja
{% macro sec_value_key(context_expr=none) %}
    {%- if context_expr -%}
        CONCAT_WS('||', '{{ tenant_key() }}', {{ context_expr }})
    {%- else -%}
        '{{ tenant_key() }}'
    {%- endif -%}
{% endmacro %}
```

`tenant_key()` leitet den Mandanten aus `target.name` ab. Mehrstufige Pfade entstehen
durch geschachteltes `CONCAT_WS` — das flacht korrekt ab:

```jinja
{{ sec_value_key("CONCAT_WS('||', ISNULL(CAST(<gruppe> AS NVARCHAR(255)), '?'), CAST(<detail> AS NVARCHAR(50)))") }} AS dss_sec_value_key
```

`ISNULL(..., '?')` hält die Pfadtiefe konstant, wenn eine Hierarchiestufe fehlt.

## `rls_filter` — Prädikat für die View

```jinja
{% macro rls_filter(security_context, sec_value_key_expr='dss_sec_value_key') %}
    EXISTS (
        SELECT 1
        FROM sec.fn_check_rls({{ sec_value_key_expr }}, '{{ security_context }}')
    )
{% endmacro %}
```

**Fallstrick 1 — Alias im `WHERE`:** Wird `dss_sec_value_key` im selben `SELECT` erst
berechnet, ist es in der `WHERE`-Klausel derselben Ebene nicht sichtbar
(„Invalid column name"). Die Spalte in einer CTE erzeugen und außen filtern:

```sql
WITH dim AS (
    SELECT …, {{ sec_value_key(...) }} AS dss_sec_value_key FROM …
)
SELECT * FROM dim WHERE {{ rls_filter('<kontext>') }}
```

**Fallstrick 2 — Mehrdeutigkeit nach Joins:** Tragen mehrere Relationen die Spalte, muss
der Ausdruck qualifiziert werden: `{{ rls_filter('<kontext>', 'f.dss_sec_value_key') }}`.

## `grant_select_on_views` — OLS als `on-run-end`-Hook

Setzt `SELECT` ausschließlich auf Views. Die Schleife liest aus `sys.views`, eine
physische Tabelle kann daher nie getroffen werden. Nicht existierende Principals werden
still übersprungen — derselbe Konfigurationsblock funktioniert auf dev wie auf prod.

```jinja
{% macro grant_select_on_views() %}
    {%- if not execute -%}{{ return('') }}{%- endif -%}
    {% set grant_map = var('ols_view_grants', {}) %}
    {% if not grant_map %}{{ return('') }}{% endif %}

    {% for principal, schemas in grant_map.items() %}
        {%- set principal_literal = principal | replace("'", "''") -%}
        {%- set schema_list = [] -%}
        {%- for s in schemas -%}
            {%- do schema_list.append("N'" ~ (s | replace("'", "''")) ~ "'") -%}
        {%- endfor -%}

        {% set grant_sql %}
            DECLARE @principal SYSNAME = N'{{ principal_literal }}';
            DECLARE @sql NVARCHAR(MAX) = N'';
            DECLARE @n INT = 0;

            IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @principal)
            BEGIN
                SELECT @sql = @sql
                     + N'GRANT SELECT ON ' + QUOTENAME(s.name) + N'.' + QUOTENAME(v.name)
                     + N' TO ' + QUOTENAME(@principal) + N';',
                       @n = @n + 1
                FROM sys.views v
                JOIN sys.schemas s ON s.schema_id = v.schema_id
                WHERE s.name IN ({{ schema_list | join(', ') }});

                IF @sql <> N'' EXEC sp_executesql @sql;
            END
            SELECT @n AS views_granted;
        {% endset %}

        {% set n = run_query(grant_sql).columns[0].values()[0] %}
        {% if n and n > 0 %}
            {% do log('OLS: ' ~ n ~ ' View-Grants fuer ' ~ principal, info=true) %}
        {% endif %}
    {% endfor %}
{% endmacro %}
```

Verdrahtung:

```yaml
# dbt_project.yml
on-run-end:
  - "{{ grant_select_on_views() }}"

vars:
  ols_view_grants:
    <gruppe-oder-user>: ['mart', 'mart_<domain>']
```

> Wer eine Verzeichnisgruppe nur für den **Objektzugriff** braucht, aber nicht für den
> Zeilenzugriff, bekommt hier einen Eintrag und **keine** Zeile in `sec_group_privilege`.
> Sonst hebt das Gruppenrecht die Einzeleinschränkungen seiner Mitglieder auf.

Einzelne Views von einem Principal ausnehmen ist mit diesem Mapping (Principal → Schema)
nicht möglich. Falls nötig: Ausschlussliste je Principal ergänzen oder das Objekt in ein
eigenes, nicht berechtigtes Schema legen.

## `measure_rls_overhead` — Vorher/Nachher messen

Sitzungsisoliert über `sys.dm_exec_sessions.logical_reads`. `sys.dm_exec_query_stats` ist
dafür ungeeignet: dbt umhüllt Abfragen, und fremder Traffic auf derselben View landet in
denselben Einträgen.

```jinja
{% macro measure_rls_overhead(relation, iterations=3, measure_column='1') %}
    {%- if not execute -%}{{ return('') }}{%- endif -%}
    {% for i in range(iterations | int) %}
        {% set snapshot %}
            SELECT logical_reads AS reads FROM sys.dm_exec_sessions WHERE session_id = @@SPID
        {% endset %}
        {% set measure %}
            DECLARE @t0 DATETIME2(7) = SYSUTCDATETIME();
            DECLARE @zeilen BIGINT, @summe DECIMAL(38,6);
            SELECT @zeilen = COUNT(*), @summe = SUM({{ measure_column }}) FROM {{ relation }};
            SELECT DATEDIFF(MILLISECOND, @t0, SYSUTCDATETIME()) AS ms, @zeilen AS zeilen;
        {% endset %}
        {% set r0 = run_query(snapshot).columns[0].values()[0] %}
        {% set r  = run_query(measure) %}
        {% set r1 = run_query(snapshot).columns[0].values()[0] %}
        {% do log('  Lauf %-3s %7s ms %12s Reads %s Zeilen'
                  | format(i + 1, r.columns[0].values()[0], r1 - r0,
                           r.columns[1].values()[0]), info=true) %}
    {% endfor %}
{% endmacro %}
```

Der Reads-Zähler wird erst bei Statement-Ende fortgeschrieben — im selben Batch gelesen
liefert er 0. Daher drei getrennte `run_query`-Aufrufe; sie teilen sich die Verbindung.

Ersten Lauf beim Vergleich ausklammern (kalter Buffer Pool).

## Native Security Policies — wann überhaupt

Nur nötig, wenn eine **physische Tabelle** direkt berechtigt ist. Bei konsequenten
View-Grants entfällt das. Falls doch:

```jinja
{% macro drop_security_policy() %}
    {% set policy_name = 'policy_' ~ this.identifier %}
    IF EXISTS (SELECT 1 FROM sys.security_policies sp
               JOIN sys.schemas s ON s.schema_id = sp.schema_id
               WHERE sp.name = '{{ policy_name }}' AND s.name = 'sec')
        DROP SECURITY POLICY sec.[{{ policy_name }}]
{% endmacro %}
```

Mit `apply_security_policy(...)` als `post_hook` **immer paarweise** verwenden: eine
Tabelle mit gebundener Policy lässt sich nicht droppen, ohne `pre_hook` schlägt jeder Run
fehl; ohne `post_hook` bleibt die Tabelle ungeschützt.

Policies binden auch an Views — dann mit `schemabinding = off`. Für dbt-Projekte ist der
eingebettete Filter trotzdem vorzuziehen: er steht im Klartext im Modell, ist versioniert
und im Review sichtbar, während eine Policy unsichtbare DDL ist.
