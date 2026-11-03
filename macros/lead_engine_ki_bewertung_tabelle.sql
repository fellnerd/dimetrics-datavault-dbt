{% macro lead_engine_ki_bewertung_tabelle() %}
{#- Eingangstabelle fuer die KI-Bewertung (Skill lead-bewertung schreibt ueber den MCP, Benutzer lead_mart_mcp: nur Einfuegen).
    Laeuft als on-run-start-Hook: "create if not exists", wird nie gedroppt oder geaendert (die Urteile gehen sonst verloren).
    Der Benutzer bekommt SELECT und INSERT, kein UPDATE oder DELETE; fehlt er in der Datenbank, wird die Vergabe uebersprungen.
    Ohne Verbindung (dbt parse, docs) passiert nichts. -#}
  {%- if not execute -%}
    {{ return('') }}
  {%- endif -%}
  {% set ddl %}
    IF OBJECT_ID('landing.lead_engine_ki_bewertung', 'U') IS NULL
    CREATE TABLE landing.lead_engine_ki_bewertung (
        bewertung_id           int IDENTITY(1,1) NOT NULL CONSTRAINT pk_lead_engine_ki_bewertung PRIMARY KEY,
        gelegenheit_id         varchar(32)    NOT NULL,
        ki_einstufung          char(1)        NOT NULL CONSTRAINT ck_lead_engine_ki_einstufung CHECK (ki_einstufung IN ('A', 'B', 'C', 'X')),
        ki_score               tinyint        NOT NULL CONSTRAINT ck_lead_engine_ki_score CHECK (ki_score BETWEEN 0 AND 100),
        ki_begruendung         nvarchar(1000) NOT NULL,
        ki_anlass              nvarchar(400)  NULL,
        ki_naechster_schritt   varchar(30)    NULL CONSTRAINT ck_lead_engine_ki_schritt CHECK (ki_naechster_schritt IN ('bewerben', 'anschreiben', 'linkedin', 'partner_fragen', 'beobachten', 'nichts')),
        ki_baustein            nvarchar(2000) NULL,
        vorscore_bei_bewertung tinyint        NULL,
        modell                 varchar(60)    NOT NULL,
        lauf_id                varchar(40)    NOT NULL,
        bewertet_am            datetime2(0)   NOT NULL CONSTRAINT df_lead_engine_ki_bewertet_am DEFAULT sysutcdatetime()
    )
  {% endset %}
  {% do run_query(ddl) %}
  {#- Index fuer "juengstes Urteil je Gelegenheit" (die Views lead_gelegenheiten_v, lead_firmen_v, lead_ki_offen_v lesen live); if not exists -#}
  {% set idx %}
    IF NOT EXISTS (select 1 from sys.indexes where name = 'ix_lead_engine_ki_bewertung_gelegenheit' and object_id = object_id('landing.lead_engine_ki_bewertung'))
        CREATE NONCLUSTERED INDEX ix_lead_engine_ki_bewertung_gelegenheit ON landing.lead_engine_ki_bewertung (gelegenheit_id, bewertet_am DESC)
  {% endset %}
  {% do run_query(idx) %}
  {% set grant_sql %}
    IF DATABASE_PRINCIPAL_ID('lead_mart_mcp') IS NOT NULL
        GRANT SELECT, INSERT ON landing.lead_engine_ki_bewertung TO lead_mart_mcp
  {% endset %}
  {% do run_query(grant_sql) %}
{% endmacro %}
