/*
 * Macro: tenant_key
 *
 * Liefert den Mandanten-Schluessel (tenant_key) des aktuellen dbt-Targets.
 * Grundlage der Mandantentrennung im dss_sec_value_key (erstes Segment).
 *
 * Ableitung: var('tenant_key') aus dbt_project.yml (Default 'default').
 * Mehrere Mandanten in einem Projekt: je Target per --vars '{tenant_key: <mandant>}'
 * setzen oder die Ableitung hier um target.name erweitern.
 *
 * Verwendung:
 *   {{ tenant_key() }}   ->   default
 */

{% macro tenant_key() %}
    {{- var('tenant_key', 'default') -}}
{% endmacro %}


/*
 * Macro: sec_value_key
 *
 * Baut den RLS-Schluessel dss_sec_value_key als SQL-Ausdruck:
 *   Mandant (tenant_key) + optionaler Kontextwert, getrennt durch '||'.
 *
 * Verwendung im Model-SQL (SELECT-Liste):
 *   {{ sec_value_key() }}                    AS dss_sec_value_key   -- 'default'
 *   {{ sec_value_key("CAST(kst AS NVARCHAR(50))") }}
 *                                            AS dss_sec_value_key   -- '<mandant>||<kst>'
 */

{% macro sec_value_key(context_expr=none) %}
    {%- if context_expr -%}
        CONCAT_WS('||', '{{ tenant_key() }}', {{ context_expr }})
    {%- else -%}
        '{{ tenant_key() }}'
    {%- endif -%}
{% endmacro %}
