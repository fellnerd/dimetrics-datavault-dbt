{#
    Base-Tabelle (incremental, append): base_lead_engine__ted_stelle
    Quelle: landing.lead_engine_datei (source = 'ted'), Payload $.notices[*]
    Grain: eine Zeile je Lauf (run_id) und Bekanntmachung (publication-number). Dieselbe Bekanntmachung wird in jedem Lauf erneut gelistet.
    Sprachfelder (notice-title, buyer-name, buyer-city, description-lot) sind Objekte je Sprache: Deutsch, sonst Englisch, sonst die erste Sprache.
    Kein Firmenschluessel: TED nennt nur den Namen des Auftraggebers (buyer_name), er steht als Attribut im Satelliten.
    Version: 2026-11-02 V1.0 Initialversion
#}
{{ config(materialized='incremental', incremental_strategy='append', as_columnstore=false) }}

with items as (
    select
        f.run_id, f.query_id, f.fetched_at, f.file_path,
        j.*
    from {{ source('lead_engine', 'lead_engine_datei') }} f
    cross apply openjson(f.payload, '$.notices') with (
        publication_number nvarchar(40)   '$."publication-number"',
        titel_deu          nvarchar(1000) '$."notice-title".deu',
        titel_eng          nvarchar(1000) '$."notice-title".eng',
        titel_json         nvarchar(max)  '$."notice-title"' as json,
        notice_type        nvarchar(50)   '$."notice-type"',
        buyer_json         nvarchar(max)  '$."buyer-name"' as json,
        city_json          nvarchar(max)  '$."buyer-city"' as json,
        pub_date           nvarchar(40)   '$."publication-date"',
        deadline_skalar    nvarchar(60)   '$."deadline-receipt-tender-date-lot"',
        deadline_erstes    nvarchar(60)   '$."deadline-receipt-tender-date-lot"[0]',
        desc_json          nvarchar(max)  '$."description-lot"' as json,
        place_json         nvarchar(max)  '$."place-of-performance"' as json,
        cpv_json           nvarchar(max)  '$."classification-cpv"' as json,
        url_deu            nvarchar(1000) '$.links.pdf.DEU',
        url_eng            nvarchar(1000) '$.links.pdf.ENG'
    ) j
    where f.source = 'ted'
      {{ lead_engine_lauf_filter('f') }}
),

queries as (
    select run_id, publication_number,
           string_agg(query_id, ',') within group (order by query_id) as query_ids
    from (select distinct run_id, publication_number, query_id from items) d
    group by run_id, publication_number
),

ranked as (
    select i.*,
           row_number() over (partition by i.run_id, i.publication_number order by i.fetched_at, i.file_path) as rn
    from items i
    where i.publication_number is not null
)

select
    r.run_id, r.fetched_at,
    r.publication_number                                                                       as stelle_bk,
    coalesce(r.titel_deu, r.titel_eng,
             (select top 1 t.[value] from openjson(r.titel_json) t))                           as titel,
    r.notice_type,
    coalesce(json_value(r.buyer_json, '$.deu[0]'), json_value(r.buyer_json, '$.eng[0]'),
             (select top 1 j2.[value] from openjson(r.buyer_json) l cross apply openjson(l.[value]) j2)) as buyer_name,
    coalesce(json_value(r.city_json, '$.deu[0]'), json_value(r.city_json, '$.mul[0]'), json_value(r.city_json, '$.eng[0]'),
             (select top 1 j2.[value] from openjson(r.city_json) l cross apply openjson(l.[value]) j2)) as buyer_city,
    try_cast(left(r.pub_date, 10) as date)                                                     as publication_date,
    try_cast(left(coalesce(r.deadline_erstes, r.deadline_skalar), 10) as date)                 as deadline_date,
    coalesce((select string_agg(d.[value], ' | ') from openjson(r.desc_json, '$.deu') d),
             (select string_agg(d.[value], ' | ') from openjson(r.desc_json, '$.eng') d),
             (select top 1 string_agg(j2.[value], ' | ') from openjson(r.desc_json) l cross apply openjson(l.[value]) j2)) as description,
    (select string_agg(p.[value], ', ') within group (order by p.[value])
       from (select distinct x.[value] from openjson(r.place_json) x) p)                      as place,
    (select string_agg(c.[value], ', ') within group (order by c.[value])
       from (select distinct x.[value] from openjson(r.cpv_json) x) c)                          as cpv,
    coalesce(r.url_deu, r.url_eng)                                                              as url,
    q.query_ids,
    'ohne-treffer'                                                                              as profil_ids
from ranked r
join queries q on q.run_id = r.run_id and q.publication_number = r.publication_number
where r.rn = 1
