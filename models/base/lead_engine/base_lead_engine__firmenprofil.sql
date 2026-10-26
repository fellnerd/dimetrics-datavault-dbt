{#
    Base-Tabelle (incremental, append): base_lead_engine__firmenprofil
    Quelle: landing.lead_engine_datei (source = 'firmenprofil', query_id z. B. 'karriere-profil')
    Grain: eine Zeile je Lauf (run_id), Quelle der Firma (quelle) und company_id
    Payload: $ (quelle, company_id, name, profil_url, website)
    firma_bk = company_id, quelle ist der Kollisionscode der Firma (gleicher hk_firma wie in den Quellen karriere/theirstack).
    Version: 2026-10-26 V1.0 Initialversion
#}
{{ config(materialized='incremental', incremental_strategy='append', as_columnstore=false) }}

with items as (
    select
        f.run_id, f.query_id, f.fetched_at, f.file_path,
        j.*
    from {{ source('lead_engine', 'lead_engine_datei') }} f
    cross apply openjson(f.payload) with (
        quelle       nvarchar(50)   '$.quelle',
        company_id   nvarchar(40)   '$.company_id',
        name         nvarchar(500)  '$.name',
        profil_url   nvarchar(1000) '$.profil_url',
        website      nvarchar(1000) '$.website'
    ) j
    where f.source = 'firmenprofil'
      -- nur abgeschlossene Laeufe: neueste Datei des Laufs (alle Quellen) ist mindestens 30 Minuten alt.
      and f.run_id in (select run_id from {{ source('lead_engine', 'lead_engine_datei') }}
                       group by run_id
                       having max(fetched_at) < dateadd(minute, -{{ var('lead_engine_ruhezeit_minuten', 30) }}, sysdatetimeoffset()))
      {% if is_incremental() %}
      and f.run_id > coalesce((select max(run_id) from {{ this }}), '')
      {% endif %}
),

ranked as (
    select i.*,
           row_number() over (partition by i.run_id, i.quelle, i.company_id order by i.fetched_at desc, i.file_path) as rn
    from items i
    where i.company_id is not null and i.quelle is not null
)

select
    r.run_id,
    r.fetched_at,
    r.quelle,
    r.company_id    as firma_bk,
    r.name          as firma_name,
    r.profil_url,
    r.website       as website_url
from ranked r
where r.rn = 1
