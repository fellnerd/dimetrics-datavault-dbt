{% macro lead_engine_tabelle_schluessel(pk_spalte, pk_typ, sort_spalte, schritt) %}
{#- Post-Hook fuer die materialisierten Lead-Engine-Tabellen: Primaerschluessel (geclustert) auf pk_spalte und ein Index auf sort_spalte absteigend.
    Je Schritt ein eigener Post-Hook (ein Batch pro Schritt: PK-Anlage sieht sonst die alte Nullbarkeit). Die Spalte muss NOT NULL sein (SELECT INTO uebernimmt die Nullbarkeit nicht fuer berechnete Ausdruecke), daher erst ALTER COLUMN.
    Der PK bekommt keinen festen Namen: dbt baut die Tabelle neu auf, waehrend die alte noch unter anderem Namen existiert (Namenskonflikt). -#}
  {%- if schritt == 1 %}
  alter table {{ this }} alter column [{{ pk_spalte }}] {{ pk_typ }} not null
  {%- elif schritt == 2 %}
  alter table {{ this }} add primary key clustered ([{{ pk_spalte }}])
  {%- else %}
  create nonclustered index [ix_{{ this.name }}_{{ sort_spalte }}] on {{ this }} ([{{ sort_spalte }}] desc)
  {%- endif %}
{% endmacro %}
