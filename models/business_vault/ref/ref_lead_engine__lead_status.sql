{#
    Referenz: ref_lead_engine__lead_status
    Lead-Status aus der Landing-Quelle suchprofil (Blatt Lead-Status, lead_status[], juengste Datei).
    Spalten: gelegenheit_id (= gelegenheit_id aus lead_gelegenheiten_v), firma, firma_norm, status (klein), grund, datum.
    Je gelegenheit_id (bzw. Firma ohne gelegenheit_id) gilt der Eintrag mit dem juengsten datum.
    Version: 2026-11-02 V1.0 Initialversion
#}
{{ config(materialized='table', as_columnstore=false, tags=['business_vault']) }}

with neueste as (
    select top 1 payload
    from {{ source('lead_engine', 'lead_engine_datei') }}
    where source = 'suchprofil'
    order by fetched_at desc, run_id desc
),

zeilen as (
    select nullif(ltrim(rtrim(s.gelegenheit_id)), '') as gelegenheit_id,
           nullif(ltrim(rtrim(s.firma)), '')          as firma,
           lower(ltrim(rtrim(s.status)))              as status,
           s.grund,
           try_cast(s.datum as date)                  as datum
    from neueste n
    cross apply openjson(n.payload, '$.lead_status') with (
        gelegenheit_id nvarchar(64)  '$.gelegenheit_id',
        firma          nvarchar(500) '$.firma',
        status         nvarchar(50)  '$.status',
        grund          nvarchar(1000) '$.grund',
        datum          nvarchar(30)  '$.datum'
    ) s
    where s.status is not null
)

select z.gelegenheit_id, z.firma, {{ lead_engine_name_norm('z.firma') }} as firma_norm, z.status, z.grund, z.datum
from (select zeilen.*, row_number() over (partition by coalesce(zeilen.gelegenheit_id, 'firma:' + coalesce(zeilen.firma, '')) order by zeilen.datum desc) as rn
      from zeilen) z
where z.rn = 1
