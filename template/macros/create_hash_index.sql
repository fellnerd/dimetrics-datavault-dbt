/*
 * Macro: create_hash_index
 * 
 * Erstellt einen Non-Clustered Index auf der Hash Key Spalte einer Static Table.
 * Azure SQL Basic Tier kompatibel (kein Columnstore).
 * 
 * Verwendung als post_hook:
 *   post_hook=["{{ create_hash_index('hk_company') }}"]
 */

{% macro create_hash_index(hash_key_column, include_columns=[]) %}
    {% set index_name = 'IX_' ~ this.name ~ '_' ~ hash_key_column %}
    
    {% set include_clause = '' %}
    {% if include_columns | length > 0 %}
        {% set include_clause = ' INCLUDE (' ~ include_columns | join(', ') ~ ')' %}
    {% endif %}
    
    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes 
        WHERE object_id = OBJECT_ID('{{ this }}') 
        AND name = '{{ index_name }}'
    )
    BEGIN
        CREATE NONCLUSTERED INDEX [{{ index_name }}]
        ON {{ this }} ([{{ hash_key_column }}]){{ include_clause }}
        WITH (ONLINE = OFF, DROP_EXISTING = OFF)
    END
{% endmacro %}


/*
 * Macro: create_composite_index
 * 
 * Erstellt einen zusammengesetzten Index auf mehreren Spalten.
 * Nützlich für Static Tables mit Multi-Hub-Joins.
 * 
 * Verwendung als post_hook:
 *   post_hook=["{{ create_composite_index(['hk_company', 'hk_project']) }}"]
 */

{% macro create_composite_index(columns, include_columns=[]) %}
    {% set index_name = 'IX_' ~ this.name ~ '_' ~ columns | join('_') %}
    {% set column_list = columns | join('], [') %}
    
    {% set include_clause = '' %}
    {% if include_columns | length > 0 %}
        {% set include_clause = ' INCLUDE (' ~ include_columns | join(', ') ~ ')' %}
    {% endif %}
    
    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes 
        WHERE object_id = OBJECT_ID('{{ this }}') 
        AND name = '{{ index_name }}'
    )
    BEGIN
        CREATE NONCLUSTERED INDEX [{{ index_name }}]
        ON {{ this }} ([{{ column_list }}]){{ include_clause }}
        WITH (ONLINE = OFF, DROP_EXISTING = OFF)
    END
{% endmacro %}


/*
 * Macro: create_clustered_index
 *
 * Wandelt einen Heap in eine Tabelle mit Clustered Index um (falls noch keiner existiert).
 * Pflicht für Rowstore-Tabellen mit incremental_strategy='delete+insert':
 * Auf einem Heap gibt DELETE die geleerten Pages nicht frei → Tabelle wächst bei jedem
 * Run um die gelöschte Datenmenge (psa_<mandant>_fibu_gl: 1,6 GB Daten → 27 GB belegt).
 * Mit Clustered Index werden leere Pages dealloziert bzw. wiederverwendet.
 *
 * Verwendung als post_hook:
 *   post_hook=["{{ create_clustered_index(['zeilen_nr']) }}"]
 */

{% macro create_clustered_index(columns) %}
    {% set index_name = 'CIX_' ~ this.name ~ '_' ~ columns | join('_') %}
    {% set column_list = columns | join('], [') %}

    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes
        WHERE object_id = OBJECT_ID('{{ this }}')
        AND type = 1
    )
    BEGIN
        CREATE CLUSTERED INDEX [{{ index_name }}]
        ON {{ this }} ([{{ column_list }}])
        WITH (ONLINE = OFF, DROP_EXISTING = OFF)
    END
{% endmacro %}


/*
 * Macro: drop_and_create_index
 * 
 * Löscht existierenden Index und erstellt ihn neu.
 * Nützlich bei Schema-Änderungen.
 */

{% macro drop_and_create_index(hash_key_column) %}
    {% set index_name = 'IX_' ~ this.name ~ '_' ~ hash_key_column %}
    
    IF EXISTS (
        SELECT 1 FROM sys.indexes 
        WHERE object_id = OBJECT_ID('{{ this }}') 
        AND name = '{{ index_name }}'
    )
    BEGIN
        DROP INDEX [{{ index_name }}] ON {{ this }}
    END
    
    CREATE NONCLUSTERED INDEX [{{ index_name }}]
    ON {{ this }} ([{{ hash_key_column }}])
    WITH (ONLINE = OFF)
{% endmacro %}
