{% macro lead_engine_freelancer_datum(txt, ref_ts) %}
{#- Datum aus freelancer.at-Angaben ohne Jahr ("22 Oct") oder nur mit Uhrzeit ("14:45", dann gilt der Tag von ref_ts).
    Volle Angaben ("24-01-2020", aeltere Auftraege) werden direkt gelesen.
    Das Jahr kommt aus ref_ts (fetched_at); liegt das Datum dadurch in der Zukunft, wird ein Jahr abgezogen.
    Monatsnamen sind englisch und werden ohne Session-Sprache aufgeloest (CHARINDEX statt Konvertierung).
    Nicht erkennbare Werte (oder ungueltige Tage) ergeben NULL.
    Verwendung: {{ lead_engine_freelancer_datum('platziert', 'fetched_at') }} AS platziert_am
-#}
{%- set tag = "TRY_CAST(LEFT(" ~ txt ~ ", CHARINDEX(' ', " ~ txt ~ " + ' ') - 1) AS INT)" -%}
{%- set monat = "((CHARINDEX(SUBSTRING(" ~ txt ~ ", CHARINDEX(' ', " ~ txt ~ " + ' ') + 1, 3), 'JanFebMarAprMayJunJulAugSepOctNovDec') + 2) / 3)" -%}
{%- set datum = "TRY_CONVERT(DATE, CONCAT(YEAR(" ~ ref_ts ~ "), '-', RIGHT(CONCAT('0', " ~ monat ~ "), 2), '-', RIGHT(CONCAT('0', " ~ tag ~ "), 2)), 23)" -%}
CASE
    WHEN {{ txt }} LIKE '[0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9][0-9]' THEN TRY_CONVERT(DATE, {{ txt }}, 105)
    WHEN {{ txt }} LIKE '[0-9]%:[0-9][0-9]' THEN CAST({{ ref_ts }} AS DATE)
    WHEN {{ tag }} IS NOT NULL THEN
        CASE WHEN {{ datum }} > CAST({{ ref_ts }} AS DATE)
             THEN DATEADD(YEAR, -1, {{ datum }})
             ELSE {{ datum }}
        END
END
{%- endmacro %}
