{#- Wächter: kein Satellit der Lead-Engine darf exakt doppelte Zeilen enthalten (Hash Key, Ladedatum, Hashdiff).
    Doppelte entstehen, wenn Staging-Historie erneut eingelesen wird (siehe apply_source_filter in den Satelliten). -#}
{%- set sats = [('sat_stelle__karriere', 'hk_stelle'), ('sat_stelle__theirstack', 'hk_stelle'), ('sat_stelle__website', 'hk_stelle'),
                ('sat_stelle__freelancer', 'hk_stelle'), ('sat_firma__karriere', 'hk_firma'), ('sat_firma__theirstack', 'hk_firma'),
                ('sat_firma__firmenprofil', 'hk_firma'), ('sat_stelle_sichtung__karriere', 'hk_stelle'),
                ('sat_stelle_sichtung__theirstack', 'hk_stelle'), ('sat_stelle_sichtung__website', 'hk_stelle'),
                ('sat_stelle_sichtung__freelancer', 'hk_stelle'),
                ('sat_stelle__adzuna', 'hk_stelle'), ('sat_firma__adzuna', 'hk_firma'), ('sat_stelle_sichtung__adzuna', 'hk_stelle')] -%}
{% for sat, pk in sats %}
select '{{ sat }}' as satellit, {{ pk }} as hash_key, dss_load_date, count(*) as anzahl
from {{ ref(sat) }}
group by {{ pk }}, dss_load_date, hashdiff
having count(*) > 1
{% if not loop.last %}union all{% endif %}
{% endfor %}
