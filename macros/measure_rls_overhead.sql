/*
 * Macro: measure_rls_overhead
 *
 * Misst logische Reads und Laufzeit einer Aggregation ueber ein Mart-Objekt —
 * sitzungsisoliert ueber sys.dm_exec_sessions.logical_reads (@@SPID), damit
 * parallele Power-BI-Last die Messung nicht verfaelscht. sys.dm_exec_query_stats
 * ist dafuer ungeeignet: dbt umhuellt Abfragen, und fremder Traffic auf
 * derselben View landet in denselben Eintraegen.
 *
 * Verwendung:
 *   dbt run-operation measure_rls_overhead --args '{relation: mart_finance.fakt_buchungen_v}' --target <mandant>-dev
 *   dbt run-operation measure_rls_overhead --args '{relation: mart_finance.fakt_buchungen_v, iterations: 5, measure_column: betrag}'
 *
 * Der erste Lauf ist typischerweise teurer (kalter Buffer Pool) und wird
 * separat ausgewiesen; fuer Vergleiche den Median der Folgelaeufe verwenden.
 *
 * Reines Messwerkzeug — veraendert nichts.
 */

{% macro measure_rls_overhead(relation, iterations=3, measure_column='betrag') %}

    {%- if not execute -%}{{ return('') }}{%- endif -%}

    {% do log('', info=true) %}
    {% do log('=== RLS-Messung: ' ~ relation ~ ' (' ~ iterations ~ ' Laeufe) ===', info=true) %}

    {% set results = [] %}

    {% for i in range(iterations | int) %}
        {#- Der Reads-Wert in dm_exec_sessions wird erst bei Statement-Ende
            fortgeschrieben — im selben Batch gelesen liefert er 0. Deshalb drei
            getrennte run_query-Aufrufe; sie teilen sich dieselbe Verbindung. -#}
        {% set snapshot %}
            SELECT logical_reads AS reads FROM sys.dm_exec_sessions WHERE session_id = @@SPID
        {% endset %}

        {% set measure %}
            DECLARE @t0 DATETIME2(7) = SYSUTCDATETIME();
            DECLARE @zeilen BIGINT, @summe DECIMAL(38,6);

            SELECT @zeilen = COUNT(*), @summe = SUM({{ measure_column }})
            FROM {{ relation }};

            SELECT DATEDIFF(MILLISECOND, @t0, SYSUTCDATETIME()) AS ms, @zeilen AS zeilen;
        {% endset %}

        {% set r0 = run_query(snapshot).columns[0].values()[0] %}
        {% set r  = run_query(measure) %}
        {% set r1 = run_query(snapshot).columns[0].values()[0] %}

        {% set ms     = r.columns[0].values()[0] %}
        {% set zeilen = r.columns[1].values()[0] %}
        {% set reads  = r1 - r0 %}
        {% do results.append((ms, reads)) %}

        {% do log('  Lauf %-3s  %7s ms   %12s logische Reads   %s Zeilen'
                  | format(i + 1, ms, reads, zeilen), info=true) %}
    {% endfor %}

    {% if results | length > 1 %}
        {% set warm = results[1:] %}
        {% set ms_avg    = (warm | map(attribute=0) | sum) / (warm | length) %}
        {% set reads_avg = (warm | map(attribute=1) | sum) / (warm | length) %}
        {% do log('  ----', info=true) %}
        {% do log('  Mittel ohne ersten Lauf: %.0f ms, %.0f logische Reads'
                  | format(ms_avg, reads_avg), info=true) %}
    {% endif %}

{% endmacro %}
