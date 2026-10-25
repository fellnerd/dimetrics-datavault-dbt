{#
    Base-View: base_lead_engine__website_stelle
    Quelle: landing.lead_engine_datei (source = 'website')
    Grain: eine Zeile je Lauf (run_id), Firma (Domain) und normalisiertem Titel
    Payload: $.company, $.jobs[*]
    BK Stelle: Domain|normalisierter Titel (die Quelle hat keine Anzeigen-ID);
               ein geaenderter Titel ergibt eine neue Stelle.
    Version: 2026-10-25 V1.0 Initialversion
#}
{{ config(materialized='view') }}

with items as (
    select
        f.run_id, f.query_id, f.fetched_at, f.file_path,
        json_value(f.payload, '$.company.name')   as company_name,
        json_value(f.payload, '$.company.url')    as company_url,
        j.title, j.url
    from {{ source('lead_engine', 'lead_engine_datei') }} f
    cross apply openjson(f.payload, '$.jobs') with (
        title nvarchar(400)  '$.title',
        url   nvarchar(1000) '$.url'
    ) j
    where f.source = 'website'
),

normalized as (
    select
        i.*,
        lower(case when charindex('/', d.host) > 0
                   then left(d.host, charindex('/', d.host) - 1)
                   else d.host end) as company_domain,
        lower(ltrim(rtrim(replace(replace(i.title, char(160), ' '), '  ', ' ')))) as title_norm
    from items i
    cross apply (select replace(replace(replace(i.company_url, 'https://', ''), 'http://', ''), 'www.', '') as host) d
),

queries as (
    select run_id, company_domain, title_norm,
           string_agg(query_id, ',') within group (order by query_id) as query_ids
    from (select distinct run_id, company_domain, title_norm, query_id from normalized) d
    group by run_id, company_domain, title_norm
),

ranked as (
    select n.*,
           row_number() over (partition by n.run_id, n.company_domain, n.title_norm
                              order by n.fetched_at, n.file_path) as rn
    from normalized n
    where n.title_norm <> ''
)

select
    r.run_id,
    r.fetched_at,
    concat(coalesce(r.company_domain, '-1'), '|', r.title_norm) as stelle_bk,
    coalesce(r.company_domain, '-1')                            as firma_bk,
    r.title, r.url,
    r.company_name,
    q.query_ids
from ranked r
join queries q on q.run_id = r.run_id
             and q.title_norm = r.title_norm
             and (q.company_domain = r.company_domain or (q.company_domain is null and r.company_domain is null))
where r.rn = 1
