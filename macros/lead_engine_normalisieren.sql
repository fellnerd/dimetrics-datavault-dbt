{% macro lead_engine_name_norm(spalte) %}
{#- Firmenname normalisiert fuer den Abgleich: klein, Sonderzeichen zu Leerzeichen, Rechtsformen entfernt
    (GmbH, AG, KG, Co, Gesellschaft m.b.H., GesmbH, e.U., OG, regGenmbH, ...), Mehrfach-Leerzeichen zusammengefasst.
    Verwendung: {{ lead_engine_name_norm('f.firma_name') }} -#}
{%- set zeichen = ['.', ',', ';', ':', '&', '/', '(', ')', '-', '+', "''", '"', '_', '|', '!', '?', '*', '#', '[', ']', '@'] -%}
{%- set formen = ['gesellschaft m b h', 'ges m b h', 'gesmbh', 'gmbh', 'reg gen m b h', 'reggenmbh', 'e u', 'ag', 'kg', 'kgaa', 'ohg', 'og', 'se', 'ug', 'co', 'ltd', 'inc', 'llc', 'vvag'] -%}
{%- set ns = namespace(e="(' ' + lower(coalesce(" ~ spalte ~ ", '')) + ' ')") -%}
{%- set ns.e = "replace(" ~ ns.e ~ ", char(160), ' ')" -%}
{%- for z in zeichen -%}{%- set ns.e = "replace(" ~ ns.e ~ ", '" ~ z ~ "', ' ')" -%}{%- endfor -%}
{%- for i in range(4) -%}{%- set ns.e = "replace(" ~ ns.e ~ ", '  ', ' ')" -%}{%- endfor -%}
{%- for r in range(2) -%}{%- for f in formen -%}{%- set ns.e = "replace(" ~ ns.e ~ ", ' " ~ f ~ " ', ' ')" -%}{%- endfor -%}{%- endfor -%}
ltrim(rtrim({{ ns.e }}))
{%- endmacro %}

{% macro lead_engine_titel_norm(spalte) %}
{#- Stellentitel normalisiert fuer den Cluster: klein, ohne Geschlechtszusaetze ((m/w/d), (all genders), ...), ohne Satzzeichen.
    Verwendung: {{ lead_engine_titel_norm('s.titel') }} -#}
{%- set zeichen = ['.', ',', ';', ':', '&', '/', '(', ')', '-', '+', "''", '"', '_', '|', '!', '?', '*', '#', '[', ']', '@'] -%}
{%- set zusaetze = ['m w d', 'w m d', 'm f d', 'f m d', 'm w x', 'm w divers', 'all genders', 'all gender', 'gn', 'd m w', 'm w'] -%}
{%- set ns = namespace(e="(' ' + lower(coalesce(" ~ spalte ~ ", '')) + ' ')") -%}
{%- set ns.e = "replace(replace(" ~ ns.e ~ ", char(160), ' '), nchar(173), '')" -%}
{%- for z in zeichen -%}{%- set ns.e = "replace(" ~ ns.e ~ ", '" ~ z ~ "', ' ')" -%}{%- endfor -%}
{%- for i in range(4) -%}{%- set ns.e = "replace(" ~ ns.e ~ ", '  ', ' ')" -%}{%- endfor -%}
{%- for r in range(2) -%}{%- for f in zusaetze -%}{%- set ns.e = "replace(" ~ ns.e ~ ", ' " ~ f ~ " ', ' ')" -%}{%- endfor -%}{%- endfor -%}
ltrim(rtrim({{ ns.e }}))
{%- endmacro %}

{% macro lead_engine_domain(url) %}
{#- Domain aus einer URL: ohne Protokoll, ohne www., ohne Pfad, klein. Leer -> NULL.
    Verwendung: {{ lead_engine_domain('fp.website_url') }} -#}
nullif(lower(case when charindex('/', replace(replace(replace({{ url }}, 'https://', ''), 'http://', ''), 'www.', '') + '/') > 0
                  then left(replace(replace(replace({{ url }}, 'https://', ''), 'http://', ''), 'www.', ''),
                            charindex('/', replace(replace(replace({{ url }}, 'https://', ''), 'http://', ''), 'www.', '') + '/') - 1)
                  end), '')
{%- endmacro %}

{% macro lead_engine_text_norm(spalte) %}
{#- Text fuer den Begriffsabgleich: klein, Bindestrich/Unterstrich/Satzzeichen/Zeilenumbrueche zu Leerzeichen
    (Leerzeichen und Bindestrich sind gleichwertig), Mehrfach-Leerzeichen zusammengefasst, mit Leerzeichen an beiden Enden.
    Verwendung: {{ lead_engine_text_norm('m.titel') }} -#}
{%- set zeichen = ['-', '_', '.', ',', ';', ':', '&', '/', '\\', '(', ')', '+', "''", '"', '|', '!', '?', '*', '#', '[', ']', '@', '=', '<', '>', '%', '$', '~', '•', '–', '—'] -%}
{%- set ns = namespace(e="(' ' + lower(coalesce(" ~ spalte ~ ", '')) + ' ')") -%}
{%- set ns.e = "replace(replace(replace(replace(" ~ ns.e ~ ", char(160), ' '), char(9), ' '), char(10), ' '), char(13), ' ')" -%}
{%- for z in zeichen -%}{%- set ns.e = "replace(" ~ ns.e ~ ", '" ~ z ~ "', ' ')" -%}{%- endfor -%}
{%- for i in range(5) -%}{%- set ns.e = "replace(" ~ ns.e ~ ", '  ', ' ')" -%}{%- endfor -%}
{{ ns.e }}
{%- endmacro %}

{% macro lead_engine_fn_norm(spalte) %}
{#- Firmenbuchnummer normalisiert: klein, ohne Leerzeichen/Bindestrich/Praefix "fn", ohne fuehrende Nullen ("088983 h" = "88983h").
    Verwendung: {{ lead_engine_fn_norm('imp.fn') }} -#}
{%- set v = "lower(replace(replace(replace(" ~ spalte ~ ", ' ', ''), '-', ''), 'fn', ''))" -%}
nullif(substring({{ v }}, patindex('%[^0]%', {{ v }} + 'x'), 30), '')
{%- endmacro %}
