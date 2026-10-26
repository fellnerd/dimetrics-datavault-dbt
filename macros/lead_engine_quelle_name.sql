{% macro lead_engine_quelle_name(collision_code) %}
{#- Anzeigename der Lead-Engine-Quelle (Kollisionscode -> Bezeichnung), einheitlich in allen Mart-Objekten.
    Verwendung: {{ lead_engine_quelle_name('h.collision_code') }} AS quelle_name
-#}
CASE {{ collision_code }}
    WHEN 'karriere'   THEN N'karriere.at'
    WHEN 'theirstack' THEN N'TheirStack'
    WHEN 'website'    THEN N'Firmenwebsite'
    WHEN 'freelancer' THEN N'freelancer.at'
    ELSE CAST({{ collision_code }} AS NVARCHAR(255))
END
{%- endmacro %}
