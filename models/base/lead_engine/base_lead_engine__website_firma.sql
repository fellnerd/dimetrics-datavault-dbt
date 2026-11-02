{#
    Base-Tabelle (incremental, append): base_lead_engine__website_firma
    Quelle: landing.lead_engine_datei (source = 'website'), ein Datensatz je Datei, auch ohne Stellen
    Grain: eine Zeile je Lauf (run_id), Firma (firma_quelle, firma_bk), nur Dateien mit mindestens einem Impressum-Feld
    Firma: wie in base_lead_engine__website_stelle (karriere_company_id > theirstack_company_id > Domain), damit hk_firma identisch ist.
    Impressum: fn (Firmenbuchnummer), uid, plz, ort, firmenname, konzern_hinweis; dazu fremde_jobdomain.
    Version: 2026-11-02 V1.0 Initialversion
#}
{{ config(materialized='incremental', incremental_strategy='append', as_columnstore=false) }}

with items as (
    select
        f.run_id, f.fetched_at, f.file_path,
        j.company_name,
        {{ lead_engine_domain('j.company_url') }}            as company_domain,
        j.karriere_company_id, j.theirstack_company_id,
        j.fremde_jobdomain, j.imp_fn, j.imp_uid, j.imp_plz, j.imp_ort, j.imp_firmenname, j.imp_konzern_hinweis
    from {{ source('lead_engine', 'lead_engine_datei') }} f
    cross apply openjson(f.payload) with (
        company_name          nvarchar(500)  '$.company.name',
        company_url           nvarchar(1000) '$.company.url',
        karriere_company_id   nvarchar(40)   '$.company.karriere_company_id',
        theirstack_company_id nvarchar(40)   '$.company.theirstack_company_id',
        fremde_jobdomain      nvarchar(500)  '$.fremde_jobdomain',
        imp_fn                nvarchar(50)   '$.impressum.fn',
        imp_uid               nvarchar(50)   '$.impressum.uid',
        imp_plz               nvarchar(20)   '$.impressum.plz',
        imp_ort               nvarchar(255)  '$.impressum.ort',
        imp_firmenname        nvarchar(500)  '$.impressum.firmenname',
        imp_konzern_hinweis   nvarchar(1000) '$.impressum.konzern_hinweis'
    ) j
    where f.source = 'website'
      {{ lead_engine_lauf_filter('f') }}
),

ranked as (
    select i.*,
           case when i.karriere_company_id is not null then 'karriere'
                when i.theirstack_company_id is not null then 'theirstack'
                else 'website' end                                                              as firma_quelle,
           coalesce(i.karriere_company_id, i.theirstack_company_id, i.company_domain, '-1')      as firma_bk
    from items i
    where coalesce(i.imp_fn, i.imp_uid, i.imp_plz, i.imp_ort, i.imp_firmenname, i.imp_konzern_hinweis, i.fremde_jobdomain) is not null
)

select run_id, fetched_at, firma_quelle, firma_bk, company_name,
       imp_fn as fn, imp_uid as uid, imp_plz as plz, imp_ort as ort, imp_firmenname as firmenname,
       imp_konzern_hinweis as konzern_hinweis, fremde_jobdomain
from (
    select r.*, row_number() over (partition by r.run_id, r.firma_quelle, r.firma_bk order by r.fetched_at desc, r.file_path) as rn
    from ranked r
) x
where rn = 1
