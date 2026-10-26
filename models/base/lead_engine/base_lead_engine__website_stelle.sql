{#
    Base-Tabelle (incremental, append): base_lead_engine__website_stelle
    Quelle: landing.lead_engine_datei (source = 'website')
    Grain: eine Zeile je Lauf (run_id), Firma (Domain) und normalisiertem Titel
    Payload: $.company, $.jobs[*]
    BK Stelle: Domain|normalisierter Titel (die Quelle hat keine Anzeigen-ID);
               ein geaenderter Titel ergibt eine neue Stelle.
    Version: 2026-10-25 V1.0 Initialversion
    Version: 2026-10-26 V1.3 Firma aus karriere_company_id / theirstack_company_id (payload.company), sonst Domain
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
        json_value(f.payload, '$.company.name')   as company_name,
        json_value(f.payload, '$.company.url')    as company_url,
        json_value(f.payload, '$.company.karriere_company_id')   as karriere_company_id,
        json_value(f.payload, '$.company.theirstack_company_id') as theirstack_company_id,
        j.title, j.url
    from {{ source('lead_engine', 'lead_engine_datei') }} f
    cross apply openjson(f.payload, '$.jobs') with (
        title nvarchar(400)  '$.title',
        url   nvarchar(1000) '$.url'
    ) j
    where f.source = 'website'
      {{ lead_engine_lauf_filter('f') }}
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
    -- Firma: bevorzugt die ID der bestehenden Firma aus karriere.at bzw. TheirStack (haengt die Stelle an dieselbe
    -- hub_firma-Zeile), sonst wie bisher die Domain (Quelle website). firma_quelle ist der Kollisionscode der Firma.
    case when r.karriere_company_id is not null then 'karriere'
         when r.theirstack_company_id is not null then 'theirstack'
         else 'website' end                                     as firma_quelle,
    coalesce(r.karriere_company_id, r.theirstack_company_id, r.company_domain, '-1') as firma_bk,
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
