{#
    Base-Tabelle (incremental, append): base_lead_engine__theirstack_stelle
    Quelle: landing.lead_engine_datei (source = 'theirstack')
    Grain: eine Zeile je Lauf (run_id) und Anzeigen-ID
    Payload: $.data[*]
    Version: 2026-10-25 V1.0 Initialversion
    Version: 2026-10-25 V1.1 profil_ids (Suchprofil, das die Stelle im Lauf gefunden hat)
    Version: 2026-10-26 V1.2 incremental: nur abgeschlossene Laeufe (Ruhezeit 30 Min.) mit run_id > bisherigem Maximum
    Version: 2026-10-26 Vollstaendigkeit ueber das Laufprotokoll + Anti-Join statt Ruhezeit (Macro lead_engine_lauf_filter)
#}
{{ config(materialized='incremental', incremental_strategy='append', as_columnstore=false) }}

with items as (
    select
        f.run_id, f.query_id, f.fetched_at, f.file_path,
        -- Suchprofil aus dem Landing-Umschlag; aeltere Dateien ohne Profil = 'data-bi'
        coalesce(json_value(f.query_params, '$.profil_id'), 'data-bi') as profil_id,
        j.*
    from {{ source('lead_engine', 'lead_engine_datei') }} f
    cross apply openjson(f.payload, '$.data') with (
        job_id               nvarchar(40)  '$.id',
        title                nvarchar(400) '$.job_title',
        url                  nvarchar(1000) '$.url',
        date_posted          nvarchar(30)  '$.date_posted',
        closed_at            nvarchar(40)  '$.closed_at',
        location             nvarchar(400) '$.long_location',
        seniority            nvarchar(100) '$.seniority',
        is_remote            bit           '$.remote',
        is_hybrid            bit           '$.hybrid',
        technologies_json    nvarchar(max) '$.technology_slugs' as json,
        company_id           nvarchar(40)  '$.company_object.id',
        company_name         nvarchar(400) '$.company_object.name',
        company_domain       nvarchar(200) '$.company_object.domain',
        company_linkedin     nvarchar(400) '$.company_object.linkedin_url',
        employee_count       int           '$.company_object.employee_count',
        employee_count_range nvarchar(50)  '$.company_object.employee_count_range',
        industry             nvarchar(200) '$.company_object.industry',
        is_recruiting_agency bit           '$.company_object.is_recruiting_agency',
        description          nvarchar(max) '$.description',
        state_code           nvarchar(20)  '$.state_code',
        country_code         nvarchar(10)  '$.country_code',
        latitude             float         '$.latitude',
        longitude            float         '$.longitude',
        short_location       nvarchar(255) '$.short_location',
        reposted             bit           '$.reposted',
        employment_statuses_json nvarchar(max) '$.employment_statuses' as json,
        keyword_slugs_json   nvarchar(max) '$.keyword_slugs' as json,
        company_city         nvarchar(255) '$.company_object.city',
        company_postal_code  nvarchar(20)  '$.company_object.postal_code',
        company_country_code nvarchar(10)  '$.company_object.country_code',
        technology_names_json nvarchar(max) '$.company_object.technology_names' as json,
        industry_id          nvarchar(40)  '$.company_object.industry_id'
    ) j
    where f.source = 'theirstack'
      {{ lead_engine_lauf_filter('f') }}
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
    r.title, r.url,
    try_cast(r.date_posted as date)  as date_posted,
    try_cast(r.closed_at as datetime2) as closed_at,
    r.location, r.seniority, r.is_remote, r.is_hybrid,
    -- sortiert, damit der Hashdiff unabhaengig von der Reihenfolge der Quelle stabil bleibt
    (select string_agg(t.[value], ', ') within group (order by t.[value])
       from openjson(r.technologies_json) t) as technologies,
    r.company_name, r.company_domain, r.company_linkedin,
    r.employee_count, r.employee_count_range, r.industry, r.is_recruiting_agency,
    -- Phase A: Detailfelder (neue Satelliten sat_stelle__theirstack_detail / sat_firma__theirstack_detail); Listen sortiert, damit der Hashdiff stabil bleibt
    r.description, r.state_code, r.country_code, r.latitude, r.longitude, r.short_location, r.reposted,
    (select string_agg(x.[value], ', ') within group (order by x.[value]) from openjson(r.employment_statuses_json) x) as employment_statuses,
    (select string_agg(x.[value], ', ') within group (order by x.[value]) from openjson(r.keyword_slugs_json) x)       as keyword_slugs,
    r.company_city, r.company_postal_code, r.company_country_code, r.industry_id,
    (select string_agg(x.[value], ', ') within group (order by x.[value]) from openjson(r.technology_names_json) x)    as technology_names,
    q.query_ids,
    p.profil_ids
from ranked r
join queries q on q.run_id = r.run_id and q.job_id = r.job_id
join profile p on p.run_id = r.run_id and p.job_id = r.job_id
where r.rn = 1
