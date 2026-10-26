{#
    Base-Tabelle (incremental, append): base_lead_engine__karriere_stelle
    Quelle: landing.lead_engine_datei (source = 'karriere')
    Grain: eine Zeile je Lauf (run_id) und Anzeigen-ID
    Payload: $.data.jobsSearchList.activeItems.items[*].jobsItem
    Version: 2026-10-25 V1.0 Initialversion
    Version: 2026-10-25 V1.1 profil_ids (Suchprofil, das die Stelle im Lauf gefunden hat)
    Version: 2026-10-26 V1.2 incremental: nur vollstaendige Laeufe (Laufprotokoll vorhanden) mit run_id > bisherigem Maximum
#}
{{ config(materialized='incremental', incremental_strategy='append', as_columnstore=false) }}

with items as (
    select
        f.run_id, f.query_id, f.fetched_at, f.file_path,
        -- Suchprofil aus dem Landing-Umschlag; aeltere Dateien ohne Profil = 'data-bi'
        coalesce(json_value(f.query_params, '$.profil_id'), 'data-bi') as profil_id,
        j.*
    from {{ source('lead_engine', 'lead_engine_datei') }} f
    cross apply openjson(f.payload, '$.data.jobsSearchList.activeItems.items') it
    cross apply openjson(it.[value], '$.jobsItem') with (
        job_id                nvarchar(20)  '$.id',
        company_id            nvarchar(20)  '$.companyId',
        title                 nvarchar(400) '$.title',
        link                  nvarchar(400) '$.link',
        date_text             nvarchar(100) '$.date',
        employment_types      nvarchar(200) '$.employmentTypes',
        salary                nvarchar(200) '$.salary',
        is_home_office        bit           '$.isHomeOffice',
        is_active             bit           '$.isActive',
        pushed_job            bit           '$.pushedJob',
        locations_json        nvarchar(max) '$.locations' as json,
        company_name          nvarchar(400) '$.company.name',
        company_slug          nvarchar(200) '$.company.slug',
        company_size          nvarchar(30)  '$.company.employees',
        company_main_location nvarchar(200) '$.company.mainLocation',
        company_link          nvarchar(400) '$.company.link'
    ) j
    where f.source = 'karriere'
      -- nur vollstaendige Laeufe: das Laufprotokoll wird erst am Ende eines Collector-Laufs geschrieben
      and f.run_id in (select run_id from {{ source('lead_engine', 'lead_engine_lauf') }})
      {% if is_incremental() %}
      and f.run_id > (select max(run_id) from {{ this }})
      {% endif %}
),

queries as (
    select run_id, job_id,
           string_agg(query_id, ',') within group (order by query_id) as query_ids
    from (select distinct run_id, job_id, query_id from items) d
    group by run_id, job_id
),

profile as (
    select run_id, job_id,
           string_agg(profil_id, ',') within group (order by profil_id) as profil_ids
    from (select distinct run_id, job_id, profil_id from items) d
    group by run_id, job_id
),

ranked as (
    select i.*,
           row_number() over (partition by i.run_id, i.job_id order by i.fetched_at, i.file_path) as rn
    from items i
)

select
    r.run_id,
    r.fetched_at,
    r.job_id                         as stelle_bk,
    coalesce(r.company_id, '-1')     as firma_bk,
    r.title, r.link,
    r.employment_types, r.salary, r.is_home_office, r.is_active, r.pushed_job,
    r.company_name, r.company_slug, r.company_size, r.company_main_location, r.company_link,
    q.query_ids,
    p.profil_ids,
    (select string_agg(json_value(l.[value], '$.name'), ', ')
       from openjson(r.locations_json) l) as locations,
    r.date_text,
    -- fetched_at ist UTC; fuer Heute/Gestern ggf. auf Ortszeit umrechnen
    case
        when r.date_text like 'Heute%'      then cast(r.fetched_at as date)
        when r.date_text like 'Gestern%'    then dateadd(day, -1, cast(r.fetched_at as date))
        when r.date_text like 'vor % Tag%'  then dateadd(day,
             -try_cast(substring(r.date_text, 5, charindex(' ', r.date_text, 5) - 5) as int),
             cast(r.fetched_at as date))
        else try_convert(date, substring(r.date_text,
             patindex('%[0-9][0-9].[0-9][0-9].[0-9][0-9][0-9][0-9]%', r.date_text), 10), 104)
    end as posted_date
from ranked r
join queries q on q.run_id = r.run_id and q.job_id = r.job_id
join profile p on p.run_id = r.run_id and p.job_id = r.job_id
where r.rn = 1
