{#
    Base-Tabelle (incremental, append): base_lead_engine__adzuna_stelle
    Quelle: landing.lead_engine_datei (source = 'adzuna')
    Grain: eine Zeile je Lauf (run_id) und Anzeigen-ID (adzuna id)
    Payload: $.results[*] (id, title, company.display_name, location.*, category.*, created, description (Auszug),
             salary_min/max, salary_is_predicted, contract_type/time, redirect_url, latitude/longitude)
    Firma: Adzuna liefert keine Firmen-ID und keine Website. BK Firma = normierter Firmenname (trim, lower, Mehrfach-
           Leerzeichen), '-1' wenn der Name fehlt. query_ids/profil_ids je Lauf ueber alle Dateien (dieselbe Anzeige
           kann ueber mehrere Begriffe oder Profile kommen).
    Hinweis: Adzuna liefert wegen des Deltas jede Anzeige nur einmal (im Lauf nach ihrem Erscheinen).
    Version: 2026-10-26 V1.0 Initialversion
#}
{{ config(materialized='incremental', incremental_strategy='append', as_columnstore=false) }}

with items as (
    select
        f.run_id, f.query_id, f.fetched_at, f.file_path,
        coalesce(nullif(f.profil_id, ''), 'ohne-treffer') as profil_id,
        j.*
    from {{ source('lead_engine', 'lead_engine_datei') }} f
    cross apply openjson(f.payload, '$.results') with (
        adzuna_id            nvarchar(40)   '$.id',
        title                nvarchar(500)  '$.title',
        company_name         nvarchar(500)  '$.company.display_name',
        location_name        nvarchar(500)  '$.location.display_name',
        area_json            nvarchar(max)  '$.location.area' as json,
        category_tag         nvarchar(100)  '$.category.tag',
        category_label       nvarchar(255)  '$.category.label',
        created              nvarchar(40)   '$.created',
        description          nvarchar(max)  '$.description',
        salary_min           float          '$.salary_min',
        salary_max           float          '$.salary_max',
        salary_is_predicted  nvarchar(10)   '$.salary_is_predicted',
        contract_type        nvarchar(50)   '$.contract_type',
        contract_time        nvarchar(50)   '$.contract_time',
        url                  nvarchar(2000) '$.redirect_url',
        latitude             float          '$.latitude',
        longitude            float          '$.longitude'
    ) j
    where f.source = 'adzuna'
      {{ lead_engine_lauf_filter('f') }}
),

queries as (
    select run_id, adzuna_id,
           string_agg(query_id, ',') within group (order by query_id) as query_ids
    from (select distinct run_id, adzuna_id, query_id from items) d
    group by run_id, adzuna_id
),

profile as (
    select run_id, adzuna_id,
           string_agg(profil_id, ',') within group (order by profil_id) as profil_ids
    from (select distinct run_id, adzuna_id, profil_id from items) d
    group by run_id, adzuna_id
),

ranked as (
    select i.*,
           row_number() over (partition by i.run_id, i.adzuna_id order by i.fetched_at, i.file_path) as rn
    from items i
    where i.adzuna_id is not null
)

select
    r.run_id,
    r.fetched_at,
    r.adzuna_id                                                  as stelle_bk,
    coalesce(nullif(lower(ltrim(rtrim(replace(replace(replace(replace(r.company_name, char(160), ' '), '   ', ' '), '  ', ' '), '  ', ' ')))), ''), '-1') as firma_bk,
    r.company_name                                               as firma_name,
    r.title, r.description,
    r.location_name,
    (select string_agg(a.[value], ' > ') within group (order by try_cast(a.[key] as int))
       from openjson(r.area_json) a)                             as location_area,
    r.category_tag, r.category_label,
    try_cast(try_convert(datetime2, r.created, 127) as date)     as created_am,
    r.salary_min, r.salary_max, r.salary_is_predicted,
    r.contract_type, r.contract_time,
    r.url, r.latitude, r.longitude,
    q.query_ids,
    p.profil_ids
from ranked r
join queries q on q.run_id = r.run_id and q.adzuna_id = r.adzuna_id
join profile p on p.run_id = r.run_id and p.adzuna_id = r.adzuna_id
where r.rn = 1
