{#
    Referenz: ref_lead_engine__thema
    Begriffe der Bewertung aus der Landing-Quelle suchprofil (Blatt Themen), jeweils die juengste Datei.
    Spalten: begriff, thema, gewicht, nur_titel, aktiv. Begriffe sind klein geschrieben.
    Version: 2026-10-26 V1.0 Initialversion
#}
{{ config(materialized='table', as_columnstore=false, tags=['business_vault']) }}

with neueste as (
    select top 1 payload
    from {{ source('lead_engine', 'lead_engine_datei') }}
    where source = 'suchprofil'
    order by fetched_at desc, run_id desc
)
select
    lower(ltrim(rtrim(t.begriff)))        as begriff,
    t.thema,
    t.gewicht,
    cast(coalesce(t.nur_titel, 0) as int) as nur_titel,
    cast(coalesce(t.aktiv, 1) as int)     as aktiv
from neueste n
cross apply openjson(n.payload, '$.themen') with (
    begriff   nvarchar(200) '$.begriff',
    thema     nvarchar(100) '$.thema',
    gewicht   int           '$.gewicht',
    nur_titel bit           '$.nur_titel',
    aktiv     bit           '$.aktiv'
) t
where t.begriff is not null
