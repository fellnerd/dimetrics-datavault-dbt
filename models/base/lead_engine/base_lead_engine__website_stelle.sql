{#
    Base-Tabelle (incremental, append): base_lead_engine__website_stelle
    Quelle: landing.lead_engine_datei (source = 'website')
    Grain: eine Zeile je Lauf (run_id), Firma (Domain) und normalisiertem Titel
    Payload: $.company, $.jobs[*]
    BK Stelle: Domain|normalisierter Titel (die Quelle hat keine Anzeigen-ID);
               ein geaenderter Titel ergibt eine neue Stelle.
    Version: 2026-10-25 V1.0 Initialversion
    Version: 2026-10-25 V1.1 profil_ids (Suchprofil, das die Stelle im Lauf gefunden hat)
    Version: 2026-10-26 V1.2 incremental: nur abgeschlossene Laeufe (Ruhezeit 30 Min.) mit run_id > bisherigem Maximum
#}
{{ config(materialized='incremental', incremental_strategy='append', as_columnstore=false) }}

with items as (
    select
        f.run_id, f.query_id, f.fetched_at, f.file_path,
        -- Suchprofil aus dem Landing-Umschlag; aeltere Dateien ohne Profil = 'data-bi'
        coalesce(json_value(f.query_params, '$.profil_id'), 'data-bi') as profil_id,
        json_value(f.payload, '$.company.name')   as company_name,
        json_value(f.payload, '$.company.url')    as company_url,
        j.title, j.url
    from {{ source('lead_engine', 'lead_engine_datei') }} f
    cross apply openjson(f.payload, '$.jobs') with (
        title nvarchar(400)  '$.title',
        url   nvarchar(1000) '$.url'
    ) j
    where f.source = 'website'
      -- nur abgeschlossene Laeufe: neueste Datei des Laufs (alle Quellen) ist mindestens 30 Minuten alt.
      -- (Das Laufprotokoll taugt nicht: seit Collector 0.3.0/Dagster hat es eine andere run_id als die Dateien.)
      and f.run_id in (select run_id from {{ source('lead_engine', 'lead_engine_datei') }}
                       group by run_id
                       having max(fetched_at) < dateadd(minute, -30, sysdatetimeoffset()))
      {% if is_incremental() %}
      and f.run_id > (select max(run_id) from {{ this }})
      {% endif %}
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

profile as (
    select run_id, company_domain, title_norm,
           string_agg(profil_id, ',') within group (order by profil_id) as profil_ids
    from (select distinct run_id, company_domain, title_norm, profil_id from normalized) d
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
    q.query_ids,
    p.profil_ids
from ranked r
join queries q on q.run_id = r.run_id
             and q.title_norm = r.title_norm
             and (q.company_domain = r.company_domain or (q.company_domain is null and r.company_domain is null))
join profile p on p.run_id = r.run_id
             and p.title_norm = r.title_norm
             and (p.company_domain = r.company_domain or (p.company_domain is null and r.company_domain is null))
where r.rn = 1
