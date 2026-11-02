{#
    Referenz: ref_lead_engine__ort
    Orte und Postleitzahlen Oesterreichs (Statistik Austria, CC BY 4.0, Landing-Quelle referenz_ort, juengste Datei).
    Grain: eine Zeile je PLZ und Ortschaft. Name-Spalten *_norm: klein, ohne Zusaetze nach Komma/Klammer, fuer den Abgleich.
    Version: 2026-10-26 V1.0 Initialversion
#}
{{ config(materialized='table', as_columnstore=false, tags=['business_vault']) }}

with neueste as (
    select top 1 payload
    from {{ source('lead_engine', 'lead_engine_datei') }}
    where source = 'referenz_ort'
    order by fetched_at desc, run_id desc
)
select
    z.plz, z.ortschaft, z.gemeinde, z.bezirk, z.bundesland,
    lower(ltrim(rtrim(z.ortschaft))) as ortschaft_norm,
    lower(ltrim(rtrim(z.gemeinde)))  as gemeinde_norm
from neueste n
cross apply openjson(n.payload, '$.zeilen') with (
    plz        nvarchar(10)  '$.plz',
    ortschaft  nvarchar(200) '$.ortschaft',
    gemeinde   nvarchar(200) '$.gemeinde',
    bezirk     nvarchar(200) '$.bezirk',
    bundesland nvarchar(100) '$.bundesland'
) z
