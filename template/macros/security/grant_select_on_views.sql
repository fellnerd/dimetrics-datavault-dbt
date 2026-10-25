/*
 * Macro: grant_select_on_views
 *
 * OLS-Kern: vergibt SELECT ausschließlich auf VIEWS der Mart-Schemas.
 * Laeuft als on-run-end-Hook nach jedem dbt-Lauf (dbt_project.yml).
 *
 * Warum kein Schema-Grant?
 *   GRANT SELECT ON SCHEMA::mart_finance wuerde auch die physischen
 *   Performance-Caches (fakt_buchungen, dim_konto, ...) mit freigeben.
 *   Endnutzer sollen ausschließlich die publizierten _v-Views sehen.
 *
 * Warum kein statisches Objekt-Grant-Skript?
 *   dbt erstellt Views bei jedem Run neu - objektbezogene Rechte haengen am
 *   Objekt und sterben mit ihm. Der Hook setzt sie nach jedem Run neu.
 *
 * Der Schutz ist strukturell, nicht prozedural: die Schleife liest aus
 * sys.views. Eine physische Tabelle kann damit gar keinen Grant bekommen -
 * nicht weil jemand daran denkt, sondern weil sie in der Quelle fehlt.
 * Ein neues _v-Model ist automatisch berechtigt, ein neuer Cache nicht.
 *
 * Konfiguration: var ols_view_grants in dbt_project.yml
 *   <principal>: [<schema>, <schema>, ...]
 *
 * Principals, die in der Datenbank nicht existieren, werden still
 * uebersprungen (dev-Targets ohne Entra-Gruppen).
 *
 * Dasselbe SQL steht als manuelle Variante in security/ols/ols_*.sql.
 */

{% macro grant_select_on_views() %}

    {%- if not execute -%}
        {{ return('') }}
    {%- endif -%}

    {% set grant_map = var('ols_view_grants', {}) %}

    {% if not grant_map %}
        {% do log('OLS: var ols_view_grants leer - keine View-Grants gesetzt.', info=false) %}
        {{ return('') }}
    {% endif %}

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

        {% set result = run_query(grant_sql) %}
        {% set n = result.columns[0].values()[0] %}

        {% if n and n > 0 %}
            {% do log('OLS: ' ~ n ~ ' View-Grants fuer ' ~ principal ~ ' gesetzt (' ~ schemas | join(', ') ~ ').', info=true) %}
        {% else %}
            {% do log('OLS: Principal ' ~ principal ~ ' existiert nicht oder hat keine Views - uebersprungen.', info=false) %}
        {% endif %}

    {% endfor %}

{% endmacro %}
