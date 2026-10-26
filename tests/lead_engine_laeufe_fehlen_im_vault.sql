{{ config(severity='warn') }}
{#- Wächter: Laeufe der letzten 7 Tage, die in der Landing-Tabelle liegen, aber nicht im Sichtungs-Satelliten der Quelle.
    Moegliche Ursachen: Laufprotokoll fehlt/kam spaeter (Lauf wird nicht uebernommen), Lauf kam nach einem neueren
    (Satelliten verarbeiten strikt in Reihenfolge der run_id), abgebrochener dbt-Lauf. Warnung, kein Fehler:
    Laeufe ohne Protokoll sind teils gewollt (lead_engine_freigegebene_laeufe). Nur Dateien mit Treffern zaehlen. -#}
{%- set quellen = [('karriere', 'sat_stelle_sichtung__karriere'), ('theirstack', 'sat_stelle_sichtung__theirstack'),
                   ('website', 'sat_stelle_sichtung__website'), ('freelancer', 'sat_stelle_sichtung__freelancer'),
                   ('adzuna', 'sat_stelle_sichtung__adzuna')] -%}
{% for quelle, sat in quellen %}
select '{{ quelle }}' as quelle, d.run_id, count(*) as dateien
from {{ source('lead_engine', 'lead_engine_datei') }} d
where d.source = '{{ quelle }}'
  and d.item_count > 0   -- Dateien ohne Treffer (item_count 0) erzeugen keine Zeilen im Vault
  and d.run_id >= format(dateadd(day, -7, sysutcdatetime()), 'yyyyMMdd"T"HHmmss"Z"')
  and d.run_id not in (select run_id from {{ ref(sat) }})
group by d.run_id
{% if not loop.last %}union all{% endif %}
{% endfor %}
