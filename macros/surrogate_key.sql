{% macro surrogate_key(column) %}
{#- Deterministischer Surrogate Key (BIGINT) aus Business Key via MD5 Hash.
    Verwendung: {{ surrogate_key('kunden_nr') }} AS kunde_key
-#}
ABS(CONVERT(BIGINT, HASHBYTES('MD5', CAST({{ column }} AS NVARCHAR(MAX)))))
{%- endmacro %}
