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
    Ort: hat eine Stelle weder Ort noch PLZ noch Region (und ist nicht remote), dient der Sitz der Firma laut Firmenbuch-Auszug (PLZ, Ort)
         als Ersatz. Kette: Ort der Stelle -> PLZ/Ort aus dem Impressum der Firma (ort_quelle 'impressum') -> Sitz laut Firmenbuch
         (ort_quelle 'firmenbuch_sitz'); das Bundesland kommt dann ueber den Ort oder die PLZ (ref_lead_engine__ort). Beide Ersatzquellen
         zaehlen in p_region nur halb.
    Einsatzort (freelancer.at): steht im Text eine Zeile "Einsatzort: ...", gilt sie vor dem Feld "Ort" der Seite: enthaelt sie "remote", ist die Stelle remote;
         ein bekannter Ort oder ein Bundesland (ref_lead_engine__ort_name, ohne landesweite Angaben) setzt ort (ort_quelle 'einsatzort_text', volle Regionspunkte).
         Wird nichts erkannt, bleibt das Feld "Ort" der Seite.
    Nicht enthalten (Phase B): Website-Detailtexte, Lead-Status.
    Materialisierung: Tabelle statt View (Business Vault sonst virtuell): die Berechnung (viele Satelliten, Textnormalisierung) wird von
    bv_stelle_thema, bv_stelle_cluster und bv_gelegenheit_score mehrfach gebraucht und waere als View je Abfrage zu teuer.
    Version: 2026-10-26 V1.0 Erste Fassung
    Version: 2026-11-04 V1.2 Einsatzort aus dem Text (freelancer.at): Zeile "Einsatzort:" -> remote, bekannter Ort/Bundesland (ort_quelle 'einsatzort_text')
    Version: 2026-11-03 V1.1 Ortskette (Impressum-PLZ), Ortsnamen-Normalisierung und Alias-Seed (lead_engine_ort_alias)
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

fb_sitz as (   -- Ersatz-Ort je Firma (Master-Ebene): erst PLZ/Ort aus dem Impressum der Website, sonst Sitz laut Firmenbuch-Auszug
    select f.hk_firma,
           coalesce(i.plz, m.plz) as plz,
           case when i.plz is not null then i.ort else m.ort end as ort,
           case when i.plz is not null then 'impressum' else 'firmenbuch_sitz' end as quelle
    from {{ ref('bv_firma_same_as') }} f
    left join (select f2.master_firma_bk, min(fb.adresse_plz) as plz, min(fb.adresse_ort) as ort
               from {{ ref('bv_firma_same_as') }} f2
               join {{ ref('sat_firma__firmenbuch') }} fb on fb.hk_firma = f2.hk_firma and fb.dss_is_current = 'Y'
               where fb.adresse_staat = 'AUT' and fb.adresse_plz is not null
               group by f2.master_firma_bk) m on m.master_firma_bk = f.master_firma_bk
    left join (select f3.master_firma_bk, min(im.plz) as plz, min(im.ort) as ort
               from {{ ref('bv_firma_same_as') }} f3
               join {{ ref('sat_firma__impressum') }} im on im.hk_firma = f3.hk_firma and im.dss_is_current = 'Y'
               where im.plz like '[1-9][0-9][0-9][0-9]'      -- oesterreichische PLZ (vierstellig); Impressum-PLZ anderer Laender bleibt aussen vor
                 and exists (select 1 from {{ ref('ref_lead_engine__ort') }} z where z.plz = im.plz)
               group by f3.master_firma_bk) i on i.master_firma_bk = f.master_firma_bk
    where i.plz is not null or m.plz is not null
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
        coalesce(oc.ort_stelle, case when oc.ohne_ort = 1 then fs.ort end)                                    as ort_roh,
        case when oc.ort_stelle is null and oc.ohne_ort = 1 and fs.plz is not null then fs.quelle else 'stelle' end as ort_quelle,
        concat_ws(' ', az.location_area, kd.region)                                     as location_area,
        coalesce(kd.plz, case when oc.ohne_ort = 1 then fs.plz end)                     as plz_roh,
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
    left join fb_sitz fs on fs.hk_firma = la.hk_firma
    outer apply (
        select coalesce(nullif(fd.norm_ort, ''), nullif(az.location_name, ''), nullif(kd.orte_text, ''), nullif(k.locations, ''), nullif(td.short_location, ''),
                        nullif(t.location, ''), nullif(fl.location, ''), nullif(te.buyer_city, '')) as ort_stelle,
               case when coalesce(nullif(fd.norm_ort, ''), nullif(az.location_name, ''), nullif(kd.orte_text, ''), nullif(k.locations, ''), nullif(td.short_location, ''),
                                  nullif(t.location, ''), nullif(fl.location, ''), nullif(te.buyer_city, '')) is null
                         and kd.plz is null and nullif(concat_ws(' ', az.location_area, kd.region), '') is null
                         and coalesce(t.is_remote, fd.norm_ist_remote, 0) = 0 then 1 else 0 end as ohne_ort
    ) oc
),

einsatz_name as (   -- bekannte Orte/Bundeslaender (ohne landesweite Angaben); binaerer Vergleich auf kleingeschriebenen Texten (schnell)
    select cast(' ' + n.name_norm + ' ' as nvarchar(300)) collate Latin1_General_BIN2 as pat, n.name_norm, len(n.name_norm) as laenge
    from {{ ref('ref_lead_engine__ort_name') }} n
    where len(n.name_norm) >= 4 and n.bundesland is not null and n.bundesland <> 'mehrere'
),

einsatz_treffer as (
    select e.hk_stelle, n.name_norm, n.laenge,
           charindex(n.pat, cast(e.seg as nvarchar(200)) collate Latin1_General_BIN2) as pos
    from {{ ref('bv_stelle_einsatzort_text') }} e
    cross join einsatz_name n
),

einsatz as (   -- je Auftrag: Remote-Hinweis und der erste erkannte Ort/das erste Bundesland im Einsatzort-Text
    select e.hk_stelle,
           case when e.seg like '% remote %' or e.seg like '% homeoffice %' then 1 else 0 end as ist_remote,
           b.name_norm
    from {{ ref('bv_stelle_einsatzort_text') }} e
    left join (select hk_stelle, name_norm, row_number() over (partition by hk_stelle order by pos, laenge desc) as rn
               from einsatz_treffer where pos > 0) b on b.hk_stelle = e.hk_stelle and b.rn = 1
),

basis2 as (   -- Einsatzort aus dem Text hat Vorrang vor dem Feld "Ort" der Seite
    select b.hk_stelle, b.quelle, b.stelle_bk, b.titel, b.url, b.text, b.text_quelle, b.veroeffentlicht_roh, b.erste_sichtung, b.letzte_sichtung,
           b.ist_reposted, b.ist_online, b.vertrag_roh,
           case when e.ist_remote = 1 then 1 else b.ist_remote_roh end as ist_remote_roh,
           b.ist_hybrid_roh,
           case when e.name_norm is not null then upper(left(e.name_norm, 1)) + substring(e.name_norm, 2, 200) else b.ort_roh end as ort_roh,
           case when e.name_norm is not null then 'einsatzort_text' else b.ort_quelle end as ort_quelle,
           b.location_area,
           case when e.name_norm is not null then null else b.plz_roh end as plz_roh,
           b.land_roh, b.budget_text, b.stundensatz_min, b.reaktionen, b.aus_projektarbeit, b.aus_projekte_suche, b.buyer_name, b.hk_firma
    from basis b
    left join einsatz e on e.hk_stelle = b.hk_stelle
),

ort as (
    select b.*,
           -- Ortsname: Text vor dem ersten Komma/Klammer, klein
           lower(ltrim(rtrim(case when b.ort_roh is null then null
                                  when patindex('%[,(]%', b.ort_roh) > 1 then left(b.ort_roh, patindex('%[,(]%', b.ort_roh) - 1)
                                  else b.ort_roh end))) as ort_name0
    from basis2 b
),

ort_k as (   -- Ortsname normalisieren: "1010 wien" -> "wien", "wien 2. bezirk" -> "wien", ohne Vorsatz (Grossraum/Raum/Naehe/Bezirk) und Zusatz (Stadt/Umgebung)
    select o.*,
           ltrim(rtrim(case when o1.n like 'wien %' then 'wien' else
               replace(replace(replace(case when o1.n like 'großraum %' then substring(o1.n, 10, 200)
                                            when o1.n like 'raum %'      then substring(o1.n, 6, 200)
                                            when o1.n like 'nähe %'      then substring(o1.n, 6, 200)
                                            when o1.n like 'bezirk %'    then substring(o1.n, 8, 200)
                                            else o1.n end, ' und umgebung', ''), ' umgebung', ''), ' stadt', '') end)) as ort_name
    from ort o
    cross apply (select case when o.ort_name0 like '[1-9][0-9][0-9][0-9] %' then ltrim(substring(o.ort_name0, 6, 200)) else o.ort_name0 end as n) o1
),

region as (
    select o.*,
           coalesce(
               on1.bundesland,
               (select top 1 x.bundesland from (select distinct bundesland from {{ ref('ref_lead_engine__ort') }}) x
                 where o.location_area like '%' + x.bundesland + '%'),
               (select top 1 z.bundesland from {{ ref('ref_lead_engine__ort') }} z where z.plz = o.plz_roh),
               (select top 1 z.bundesland from {{ ref('ref_lead_engine__ort') }} z where z.plz = left(o.ort_name0, 4) and o.ort_name0 like '[1-9][0-9][0-9][0-9] %')) as bundesland,
           on1.bezirk, coalesce(on1.ist_remote, 0) as ist_remote_ort
    from ort_k o
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
    cast(coalesce(r.ist_remote_roh, nullif(r.ist_remote_ort, 0), 0) as int)                as ist_remote,
    cast(coalesce(r.ist_hybrid_roh, 0) as int)                                          as ist_hybrid,
    r.plz_roh                                                                           as plz,
    r.ort_roh                                                                           as ort,
    r.ort_quelle,
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
