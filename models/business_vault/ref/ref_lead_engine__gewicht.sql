{#
    Referenz: ref_lead_engine__gewicht
    Gewichte und Punkte der Bewertung. Grundlage ist der Seed lead_engine_gewicht_startwerte (Startwerte aus dem Plan);
    Eintraege aus der Landing-Quelle suchprofil (gewichte[], juengste Datei) ueberschreiben je (bereich, schluessel).
    Spalten: bereich, schluessel, punkte, bemerkung, quelle (seed/landing).
    Version: 2026-10-26 V1.0 Initialversion
#}
{{ config(materialized='table', as_columnstore=false, tags=['business_vault']) }}

with neueste as (
    select top 1 payload
    from {{ source('lead_engine', 'lead_engine_datei') }}
    where source = 'suchprofil'
    order by fetched_at desc, run_id desc
),

landing as (
    select g.bereich, g.schluessel, g.punkte, g.bemerkung
    from neueste n
    cross apply openjson(n.payload, '$.gewichte') with (
        bereich   nvarchar(50)  '$.bereich',
        schluessel nvarchar(100) '$.schluessel',
        punkte    float         '$.punkte',
        bemerkung nvarchar(500) '$.bemerkung'
    ) g
    where g.bereich is not null and g.schluessel is not null
)

select coalesce(l.bereich, s.bereich)     as bereich,
       coalesce(l.schluessel, s.schluessel) as schluessel,
       cast(coalesce(l.punkte, s.punkte) as float) as punkte,
       coalesce(l.bemerkung, s.bemerkung) as bemerkung,
       case when l.bereich is not null then 'landing' else 'seed' end as quelle
from {{ ref('lead_engine_gewicht_startwerte') }} s
full outer join landing l on l.bereich = s.bereich and l.schluessel = s.schluessel
