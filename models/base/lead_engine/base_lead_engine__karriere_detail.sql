{#
    Base-Tabelle (incremental, append): base_lead_engine__karriere_detail
    Quelle: landing.lead_engine_datei (source = 'karriere_detail', Datei stelle__<id>)
    Grain: eine Zeile je Lauf (run_id) und karriere-Job-ID (= stelle_bk der karriere-Stelle)
    Payload: id, titel, beschreibung (voll, OPENJSON: JSON_VALUE schneidet ueber 4000 Zeichen ab), date_posted, valid_through,
             employment_type[], orte[] (postalCode, addressLocality, addressRegion, addressCountry), base_salary, firma
    Version: 2026-11-02 V1.0 Initialversion
#}
{{ config(materialized='incremental', incremental_strategy='append', as_columnstore=false) }}

with items as (
    select
        f.run_id, f.fetched_at, f.file_path,
        j.*
    from {{ source('lead_engine', 'lead_engine_datei') }} f
    cross apply openjson(f.payload) with (
        job_id              nvarchar(40)   '$.id',
        titel               nvarchar(500)  '$.titel',
        url                 nvarchar(1000) '$.url',
        beschreibung        nvarchar(max)  '$.beschreibung',
        date_posted         nvarchar(40)   '$.date_posted',
        valid_through       nvarchar(40)   '$.valid_through',
        employment_json     nvarchar(max)  '$.employment_type' as json,
        orte_json           nvarchar(max)  '$.orte' as json,
        salary_value        float          '$.base_salary.value.value',
        salary_unit         nvarchar(20)   '$.base_salary.value.unitText',
        salary_currency     nvarchar(10)   '$.base_salary.currency',
        firma_name          nvarchar(500)  '$.firma'
    ) j
    where f.source = 'karriere_detail'
      {{ lead_engine_lauf_filter('f') }}
),

ranked as (
    select i.*,
           row_number() over (partition by i.run_id, i.job_id order by i.fetched_at desc, i.file_path) as rn
    from items i
    where i.job_id is not null
)

select
    r.run_id, r.fetched_at,
    r.job_id                                                                  as stelle_bk,
    r.titel, r.url, r.beschreibung,
    try_cast(left(r.date_posted, 10) as date)                                 as veroeffentlicht_am,
    try_cast(left(r.valid_through, 10) as date)                               as gueltig_bis,
    (select string_agg(e.[value], ', ') within group (order by e.[value])
       from openjson(r.employment_json) e)                                    as employment_type,
    (select string_agg(x.ort, ', ') within group (order by x.ort)
       from (select distinct o.addressLocality as ort from openjson(r.orte_json) with (addressLocality nvarchar(255)) o
              where o.addressLocality is not null) x)                         as orte_text,
    (select top 1 o.postalCode from openjson(r.orte_json) with (postalCode nvarchar(20)) o where o.postalCode is not null) as plz,
    (select string_agg(x.region, ', ') within group (order by x.region)
       from (select distinct o.addressRegion as region from openjson(r.orte_json) with (addressRegion nvarchar(100)) o
              where o.addressRegion is not null) x)                           as region,
    (select top 1 o.addressCountry from openjson(r.orte_json) with (addressCountry nvarchar(10)) o where o.addressCountry is not null) as land,
    r.salary_value, r.salary_unit, r.salary_currency,
    r.firma_name
from ranked r
where r.rn = 1
