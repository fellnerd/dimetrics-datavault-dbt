{#
    Business Vault (virtuell): bv_stelle_merkmale
    Grain: 1 Zeile je hk_stelle (Stelle/Auftrag je Quelle), aktueller Stand.
    Prioritaeten: text: karriere-Detailseite > TheirStack description > freelancer.at > Adzuna > karriere summary;
                  veroeffentlicht_am: karriere datePosted (Detailseite) > karriere date > TheirStack date_posted > freelancer norm > freelancer.at > Adzuna created,
                  Fallback erste Sichtung (datum_geschaetzt = 1).
    ist_online: Stelle im juengsten Lauf ihrer Quelle noch gesehen; NULL fuer Adzuna (jede Anzeige nur einmal, Delta).
    Region: Ort -> Bundesland ueber ref_lead_engine__ort_name (PLZ folgt, sobald vorhanden); region_gruppe passt zu den
            Schluesseln im Bereich 'region' der Gewichte (Kärnten, Steiermark, ..., Osttirol, Tirol (= Nordtirol), DACH, unbekannt).
    TED: Auftraggeber (buyer_name) als firma_name, kein Firmen-Link; Vertragsart 'projekt'.
    Nicht enthalten (Phase B): Website-Detailtexte, Lead-Status, Firmenbuch.
    Materialisierung: Tabelle statt View (Business Vault sonst virtuell): die Berechnung (viele Satelliten, Textnormalisierung) wird von
    bv_stelle_thema, bv_stelle_cluster und bv_gelegenheit_score mehrfach gebraucht und waere als View je Abfrage zu teuer.
    Version: 2026-10-26 V1.0 Erste Fassung
#}
{{ config(materialized='table', as_columnstore=false, tags=['business_vault']) }}

with sichtung as (
    select hk_stelle, run_id, query_ids, dss_load_date, 'karriere' as q from {{ ref('sat_stelle_sichtung__karriere') }}
    union all select hk_stelle, run_id, query_ids, dss_load_date, 'theirstack' from {{ ref('sat_stelle_sichtung__theirstack') }}
    union all select hk_stelle, run_id, query_ids, dss_load_date, 'website' from {{ ref('sat_stelle_sichtung__website') }}
    union all select hk_stelle, run_id, query_ids, dss_load_date, 'freelancer' from {{ ref('sat_stelle_sichtung__freelancer') }}
    union all select hk_stelle, run_id, query_ids, dss_load_date, 'adzuna' from {{ ref('sat_stelle_sichtung__adzuna') }}
    union all select hk_stelle, run_id, query_ids, dss_load_date, 'ted' from {{ ref('sat_stelle_sichtung__ted') }}
),

sicht as (
    select hk_stelle,
           cast(min(dss_load_date) as date) as erste_sichtung,
           cast(max(dss_load_date) as date) as letzte_sichtung,
           max(run_id) as letzter_run_id,
           max(case when query_ids like '%projektarbeit%' then 1 else 0 end) as aus_projektarbeit,
           max(case when query_ids like '%projekte%' then 1 else 0 end)      as aus_projekte_suche
    from sichtung
    group by hk_stelle
),

letzter_run_quelle as (
    select h.collision_code, max(s.letzter_run_id) as run_id
    from sicht s join {{ ref('hub_stelle') }} h on h.hk_stelle = s.hk_stelle
    group by h.collision_code
),

link_aktuell as (
    select hk_stelle, hk_firma
    from (select l.hk_stelle, l.hk_firma,
                 row_number() over (partition by l.hk_stelle order by l.dss_load_date desc, l.hk_firma) as rn
          from {{ ref('link_stelle_firma') }} l) x
    where rn = 1
),

basis as (
    select
        h.hk_stelle, h.collision_code as quelle, h.stelle_bk,
        coalesce(k.title, t.title, w.title, fl.title, az.title, te.titel)               as titel,
        coalesce(k.link, t.url, w.url, fl.url, az.url, te.url)                        as url,
        case when kd.beschreibung is not null and kd.beschreibung <> '' then kd.beschreibung
             when td.description is not null and td.description <> ''  then td.description
             when te.description is not null and te.description <> ''   then te.description
             when fl.beschreibung is not null and fl.beschreibung <> '' then fl.beschreibung
             when az.description is not null and az.description <> ''   then az.description
             else kt.summary end                                                        as text,
        case when kd.beschreibung is not null and kd.beschreibung <> '' then 'karriere_detail'
             when td.description is not null and td.description <> ''  then 'theirstack'
             when te.description is not null and te.description <> ''   then 'ted'
             when fl.beschreibung is not null and fl.beschreibung <> '' then 'freelancer'
             when az.description is not null and az.description <> ''   then 'adzuna'
             when kt.summary is not null and kt.summary <> ''           then 'karriere_summary' end as text_quelle,
        coalesce(kd.veroeffentlicht_am, k.posted_date, t.date_posted, fd.norm_veroeffentlicht_am, fl.veroeffentlicht_am, az.created_am, te.publication_date) as veroeffentlicht_roh,
        s.erste_sichtung, s.letzte_sichtung,
        td.reposted                                                                     as ist_reposted,
        case when h.collision_code = 'adzuna' then null
             when s.letzter_run_id = lq.run_id then 1 else 0 end                        as ist_online,
        lower(concat_ws(' ', k.employment_types, kd.employment_type, td.employment_statuses, az.contract_type, az.contract_time,
                        case when h.collision_code = 'freelancer' then 'freiberuflich' end,
                        case when h.collision_code = 'ted' then 'projekt' end)) as vertrag_roh,
        coalesce(t.is_remote, fd.norm_ist_remote,
                 case when lower(fl.location) like '%ferne%' or lower(coalesce(k.title, t.title, w.title, fl.title, az.title)) like '%remote%' then 1 end) as ist_remote_roh,
        coalesce(t.is_hybrid, k.is_home_office,
                 case when lower(coalesce(k.title, t.title, w.title, fl.title, az.title)) like '%hybrid%' then 1 end) as ist_hybrid_roh,
        coalesce(nullif(fd.norm_ort, ''), nullif(az.location_name, ''), nullif(kd.orte_text, ''), nullif(k.locations, ''), nullif(td.short_location, ''),
                 nullif(t.location, ''), nullif(fl.location, ''), nullif(te.buyer_city, ''))                       as ort_roh,
        concat_ws(' ', az.location_area, kd.region)                                     as location_area,
        kd.plz                                                                          as plz_roh,
        coalesce(fd.norm_land, td.country_code, kd.land, case when te.place like '%AUT%' then 'AT' end) as land_roh,
        coalesce(k.salary, fl.budget,
                 case when az.salary_min is not null then concat(cast(cast(az.salary_min as int) as nvarchar(20)), ' - ', cast(cast(az.salary_max as int) as nvarchar(20))) end) as budget_text,
        case when fd.norm_budget_einheit = 'stunde' then fd.norm_budget_min end         as stundensatz_min,
        fd.norm_reaktionen                                                              as reaktionen,
        s.aus_projektarbeit, s.aus_projekte_suche, te.buyer_name,
        la.hk_firma
    from {{ ref('hub_stelle') }} h
    left join sicht s on s.hk_stelle = h.hk_stelle
    left join letzter_run_quelle lq on lq.collision_code = h.collision_code
    left join {{ ref('sat_stelle__karriere') }} k          on k.hk_stelle = h.hk_stelle  and k.dss_is_current = 'Y'
    left join {{ ref('sat_stelle__karriere_text') }} kt    on kt.hk_stelle = h.hk_stelle and kt.dss_is_current = 'Y'
    left join {{ ref('sat_stelle__karriere_detail') }} kd  on kd.hk_stelle = h.hk_stelle and kd.dss_is_current = 'Y'
    left join {{ ref('sat_stelle__theirstack') }} t        on t.hk_stelle = h.hk_stelle  and t.dss_is_current = 'Y'
    left join {{ ref('sat_stelle__theirstack_detail') }} td on td.hk_stelle = h.hk_stelle and td.dss_is_current = 'Y'
    left join {{ ref('sat_stelle__website') }} w           on w.hk_stelle = h.hk_stelle  and w.dss_is_current = 'Y'
    left join {{ ref('sat_stelle__freelancer') }} fl       on fl.hk_stelle = h.hk_stelle and fl.dss_is_current = 'Y'
    left join {{ ref('sat_stelle__freelancer_detail') }} fd on fd.hk_stelle = h.hk_stelle and fd.dss_is_current = 'Y'
    left join {{ ref('sat_stelle__adzuna') }} az           on az.hk_stelle = h.hk_stelle and az.dss_is_current = 'Y'
    left join {{ ref('sat_stelle__ted') }} te              on te.hk_stelle = h.hk_stelle and te.dss_is_current = 'Y'
    left join link_aktuell la on la.hk_stelle = h.hk_stelle
),

ort as (
    select b.*,
           -- Ortsname: Text vor dem ersten Komma/Klammer, klein
           lower(ltrim(rtrim(case when b.ort_roh is null then null
                                  when patindex('%[,(]%', b.ort_roh) > 1 then left(b.ort_roh, patindex('%[,(]%', b.ort_roh) - 1)
                                  else b.ort_roh end))) as ort_name
    from basis b
),

region as (
    select o.*,
           coalesce(
               on1.bundesland,
               (select top 1 x.bundesland from (select distinct bundesland from {{ ref('ref_lead_engine__ort') }}) x
                 where o.location_area like '%' + x.bundesland + '%')) as bundesland,
           on1.bezirk
    from ort o
    left join {{ ref('ref_lead_engine__ort_name') }} on1 on on1.name_norm = o.ort_name
),

firma as (
    select hk_firma, firma_name, master_firma_bk from {{ ref('bv_firma_same_as') }}
),

firma_attr as (
    select h.hk_firma,
           coalesce(ft.employee_count,
                    try_cast(left(coalesce(ft.employee_count_range, k.company_size), patindex('%[^0-9]%', coalesce(ft.employee_count_range, k.company_size) + ' ') - 1) as int)) as mitarbeiter,
           ft.industry as branche, ft.is_recruiting_agency as ist_vermittler, fd.technology_names as technologien,
           imp.konzern_hinweis, imp.fremde_jobdomain
    from {{ ref('hub_firma') }} h
    left join {{ ref('sat_firma__theirstack') }} ft on ft.hk_firma = h.hk_firma and ft.dss_is_current = 'Y'
    left join {{ ref('sat_firma__karriere') }} k on k.hk_firma = h.hk_firma and k.dss_is_current = 'Y'
    left join {{ ref('sat_firma__theirstack_detail') }} fd on fd.hk_firma = h.hk_firma and fd.dss_is_current = 'Y'
    left join {{ ref('sat_firma__impressum') }} imp on imp.hk_firma = h.hk_firma and imp.dss_is_current = 'Y'
),

abschluss as (   -- Groessenklasse des juengsten Jahresabschlusses je Master-Firma (ueber alle Firmen des Masters)
    select x.master_firma_bk, x.groessenklasse_code
    from (select f.master_firma_bk, ja.groessenklasse_code,
                 row_number() over (partition by f.master_firma_bk order by ja.stichtag desc, f.hk_firma) as rn
          from {{ ref('bv_firma_same_as') }} f
          join {{ ref('sat_firma__jahresabschluss') }} ja on ja.hk_firma = f.hk_firma and ja.dss_is_current = 'Y') x
    where x.rn = 1
)

select
    r.hk_stelle, r.quelle, r.stelle_bk, r.titel, r.url, r.text, r.text_quelle,
    coalesce(r.veroeffentlicht_roh, r.erste_sichtung)                                   as veroeffentlicht_am,
    case when r.veroeffentlicht_roh is null then 1 else 0 end                           as datum_geschaetzt,
    r.erste_sichtung, r.letzte_sichtung,
    datediff(day, coalesce(r.veroeffentlicht_roh, r.erste_sichtung), r.letzte_sichtung) as tage_online,
    cast(coalesce(r.ist_reposted, 0) as int)                                            as ist_reposted,
    r.ist_online,
    case when r.vertrag_roh like '%prakti%' or r.vertrag_roh like '%intern%'            then 'praktikum'
         when r.vertrag_roh like '%lehr%' or r.vertrag_roh like '%apprentice%'          then 'lehre'
         when r.vertrag_roh like '%freiberuf%' or r.vertrag_roh like '%freelanc%'
              or r.vertrag_roh like '%freie dienst%' or r.vertrag_roh like '%werkvertrag%' or r.vertrag_roh like '%contract%' then 'freiberuflich'
         when r.vertrag_roh like '%projekt%' or r.aus_projektarbeit = 1                 then 'projekt'
         when r.vertrag_roh like '%befrist%' or r.vertrag_roh like '%temporary%' or r.vertrag_roh like '%interim%' or r.vertrag_roh like '%karenz%' then 'befristet'
         when r.vertrag_roh like '%teilzeit%' or r.vertrag_roh like '%part%'            then 'teilzeit'
         when r.vertrag_roh like '%vollzeit%' or r.vertrag_roh like '%full%' or r.vertrag_roh like '%permanent%' then 'fest'
         end                                                                            as vertragsart,
    cast(coalesce(r.ist_remote_roh, 0) as int)                                          as ist_remote,
    cast(coalesce(r.ist_hybrid_roh, 0) as int)                                          as ist_hybrid,
    r.plz_roh                                                                           as plz,
    r.ort_roh                                                                           as ort,
    r.bundesland,
    coalesce(r.land_roh, case when r.bundesland is not null then 'AT' end)              as land,
    case when r.bundesland = 'Kärnten' then 'Kärnten'
         when r.bundesland = 'Steiermark' then 'Steiermark'
         when r.bundesland = 'Salzburg' then 'Salzburg'
         when r.bundesland = 'Tirol' and r.bezirk = 'Lienz' then 'Osttirol'
         when r.bundesland = 'Tirol' then 'Tirol'
         when r.bundesland in ('Oberösterreich', 'Niederösterreich', 'Wien', 'Burgenland', 'Vorarlberg') then r.bundesland
         when coalesce(r.land_roh, '') in ('DE', 'CH', 'LI') then 'DACH'
         else 'unbekannt' end                                                           as region_gruppe,
    fm.master_firma_bk, coalesce(fm.firma_name, r.buyer_name) as firma_name,
    cast(coalesce(fa.ist_vermittler, 0) as int)                                         as ist_vermittler,
    fa.mitarbeiter, ab.groessenklasse_code, fa.branche, fa.technologien, fa.konzern_hinweis, fa.fremde_jobdomain,
    r.budget_text, r.stundensatz_min, r.reaktionen,
    r.aus_projektarbeit, r.aus_projekte_suche
from region r
left join firma fm on fm.hk_firma = r.hk_firma
left join firma_attr fa on fa.hk_firma = r.hk_firma
left join abschluss ab on ab.master_firma_bk = fm.master_firma_bk
