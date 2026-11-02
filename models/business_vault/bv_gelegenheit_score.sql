{#
    Business Vault (virtuell): bv_gelegenheit_score
    Grain: 1 Zeile je Cluster (bv_stelle_cluster, Repraesentant) = eine Gelegenheit. Alle Bausteine einzeln, Punkte aus ref_lead_engine__gewicht
           (Seed-Startwerte, ueberschrieben durch die Gewichte aus der Landing-Quelle suchprofil).
    Lead-Typen: A1 freelancer.at | A2 Vermittler mit Vertragsart freiberuflich/projekt/befristet, karriere Projektarbeit, TheirStack __projekte |
                C Partner (IT-Dienstleister/Beratung mit Themen-Treffer) | B1 Firmenstelle im Thema mit Interim/Karenz/Elternzeit/befristet,
                > 45 Tage online oder neu ausgeschrieben | B2 sonst. A3 (TED) folgt mit Phase B.
    Ausgeschlossen (bleibt mit Kennzeichen in der Tabelle): Festanstellung ueber Vermittler. Lead-Status und Sperrliste folgen mit Phase B.
    Negativbegriff im Titel: Typ- und Region-Punkte entfallen (zusaetzlich zum Abzug).
    Bausteine: p_thema (0-35), p_typ, p_region (0-20), p_frische (0-15), p_passung (0-5), p_bonus (bis +15), p_abzug (bis -25); vorscore = Summe.
    Version: 2026-10-26 V1.0 Erste Fassung
#}
{{ config(materialized='view', tags=['business_vault']) }}

with par as (   -- skalare Parameter aus den Gewichten
    select
        max(case when bereich = 'thema'   and schluessel = 'deckel'              then punkte end) as thema_deckel,
        max(case when bereich = 'thema'   and schluessel = 'titel_faktor'        then punkte end) as titel_faktor,
        max(case when bereich = 'thema'   and schluessel = 'ohne_kernthema_max'  then punkte end) as ohne_kern_max,
        max(case when bereich = 'passung' and schluessel = 'stundensatz_ab_60'   then punkte end) as p_stundensatz,
        max(case when bereich = 'passung' and schluessel = 'firmengroesse_20_500' then punkte end) as p_groesse,
        max(case when bereich = 'bonus'   and schluessel = 'lange_offen'         then punkte end) as b_lange_offen,
        max(case when bereich = 'bonus'   and schluessel = 'reaktionen_max_3'    then punkte end) as b_reaktionen,
        max(case when bereich = 'bonus'   and schluessel = 'zweite_gelegenheit'  then punkte end) as b_zweite,
        max(case when bereich = 'abzug'   and schluessel = 'konzern'             then punkte end) as a_konzern,
        max(case when bereich = 'abzug'   and schluessel = 'negativ_titel'       then punkte end) as a_negativ,
        max(case when bereich = 'schwelle' and schluessel = 'lange_offen_tage'   then punkte end) as s_lange_offen,
        max(case when bereich = 'schwelle' and schluessel = 'konzern_mitarbeiter' then punkte end) as s_konzern,
        max(case when bereich = 'region'  and schluessel = 'hybrid_bonus'        then punkte end) as r_hybrid
    from {{ ref('ref_lead_engine__gewicht') }}
),

rep as (   -- Repraesentant je Cluster mit seinen Merkmalen
    select c.cluster_key, c.anzahl_stellen_im_cluster, c.quellen_im_cluster, m.*
    from {{ ref('bv_stelle_cluster') }} c
    join {{ ref('bv_stelle_merkmale') }} m on m.hk_stelle = c.hk_stelle
    where c.ist_repraesentant = 1
),

treffer as (   -- Themen-Treffer ueber alle Stellen des Clusters; je Thema der staerkste Begriff
    select c.cluster_key, t.thema, t.begriff, t.gewicht, t.fundort
    from {{ ref('bv_stelle_cluster') }} c
    join {{ ref('bv_stelle_thema') }} t on t.hk_stelle = c.hk_stelle
),

je_thema as (
    select tr.cluster_key, tr.thema,
           max(case when tr.fundort = 'titel' then tr.gewicht * p.titel_faktor else tr.gewicht end) as punkte,
           max(case when tr.fundort = 'titel' then 1 else 0 end) as im_titel,
           max(tr.begriff) as begriff
    from treffer tr cross join par p
    where tr.thema <> 'Negativ'
    group by tr.cluster_key, tr.thema
),

thema_summe as (
    select jt.cluster_key,
           sum(jt.punkte) as roh,
           max(case when jt.im_titel = 1 and jt.thema in ('Datenplattform', 'BI und Reporting', 'KI', 'Controlling') then 1 else 0 end) as kern_im_titel,
           string_agg(jt.thema + ': ' + jt.begriff + case when jt.im_titel = 1 then ' (Titel)' else '' end, ' | ') within group (order by jt.punkte desc) as themen,
           max(jt.thema + ': ' + jt.begriff + case when jt.im_titel = 1 then ' (Titel)' else '' end) as top_thema_text
    from je_thema jt
    group by jt.cluster_key
),

negativ as (
    select distinct cluster_key from treffer where thema = 'Negativ' and fundort = 'titel'
),

basis as (
    select r.*,
           coalesce(ts.roh, 0) as thema_roh, coalesce(ts.kern_im_titel, 0) as kern_im_titel, ts.themen,
           case when ng.cluster_key is not null then 1 else 0 end as negativ_titel,
           case when r.quelle = 'freelancer' then 'A1'
                when r.ist_vermittler = 1 and r.vertragsart in ('freiberuflich', 'projekt', 'befristet') then 'A2'
                when r.aus_projektarbeit = 1 or r.aus_projekte_suche = 1 then 'A2'
                when r.ist_vermittler = 1 then null
                when coalesce(ts.roh, 0) > 0 and (lower(coalesce(r.branche, '')) like '%consult%' or lower(coalesce(r.branche, '')) like '%it services%'
                       or lower(coalesce(r.branche, '')) like '%information technology%' or lower(coalesce(r.firma_name, '')) like '%consult%'
                       or lower(coalesce(r.firma_name, '')) like '%beratung%') then 'C'
                when lower(coalesce(r.titel, '')) like '%interim%' or lower(coalesce(r.titel, '')) like '%karenz%' or lower(coalesce(r.titel, '')) like '%elternzeit%'
                       or lower(coalesce(left(r.text, 4000), '')) like '%karenz%' or lower(coalesce(left(r.text, 4000), '')) like '%elternzeit%'
                       or r.vertragsart = 'befristet' or r.tage_online > (select s_lange_offen from par) or r.ist_reposted = 1 then 'B1'
                else 'B2' end as lead_typ
    from rep r
    left join thema_summe ts on ts.cluster_key = r.cluster_key
    left join negativ ng on ng.cluster_key = r.cluster_key
),

zweite as (   -- weitere relevante Gelegenheit derselben Master-Firma in den letzten 60 Tagen
    select b1.cluster_key, count(*) as andere
    from basis b1
    join basis b2 on b2.master_firma_bk = b1.master_firma_bk and b2.cluster_key <> b1.cluster_key
    where b1.master_firma_bk is not null and b2.thema_roh > 0 and b2.letzte_sichtung >= dateadd(day, -60, cast(getdate() as date))
    group by b1.cluster_key
),

punkte as (
    select b.*,
           -- Thema: je Thema der staerkste Begriff (Titel zaehlt doppelt), gedeckelt; ohne Kernthema im Titel hoechstens ohne_kern_max
           cast(case when b.kern_im_titel = 1 then case when b.thema_roh > p.thema_deckel then p.thema_deckel else b.thema_roh end
                     else case when b.thema_roh > p.ohne_kern_max then p.ohne_kern_max else b.thema_roh end end as int) as p_thema,
           -- Negativbegriff im Titel: Typ- und Region-Punkte entfallen (der Abzug bleibt)
           cast(case when b.negativ_titel = 1 then 0 else (select g.punkte from {{ ref('ref_lead_engine__gewicht') }} g where g.bereich = 'typ' and g.schluessel = b.lead_typ) end as int) as p_typ,
           cast(case when b.negativ_titel = 1 then 0 when b.ist_remote = 1 then (select g.punkte from {{ ref('ref_lead_engine__gewicht') }} g where g.bereich = 'region' and g.schluessel = 'remote')
                     else coalesce((select g.punkte from {{ ref('ref_lead_engine__gewicht') }} g where g.bereich = 'region' and g.schluessel = b.region_gruppe), 0)
                          + case when b.ist_hybrid = 1 and b.region_gruppe in ('Wien', 'Niederoesterreich', 'Burgenland', 'Vorarlberg') then p.r_hybrid else 0 end
                end as int) as p_region,
           cast(coalesce((select g.punkte from {{ ref('ref_lead_engine__gewicht') }} g where g.bereich = 'frische' and g.schluessel =
                    case when datediff(day, b.veroeffentlicht_am, cast(getdate() as date)) <= 3 then 'tage_3'
                         when datediff(day, b.veroeffentlicht_am, cast(getdate() as date)) <= 7 then 'tage_7'
                         when datediff(day, b.veroeffentlicht_am, cast(getdate() as date)) <= 14 then 'tage_14'
                         when datediff(day, b.veroeffentlicht_am, cast(getdate() as date)) <= 30 then 'tage_30' else 'aelter' end), 0) as int) as p_frische,
           cast(case when b.stundensatz_min >= 60 or b.budget_text is not null then p.p_stundensatz else 0 end
              + case when b.mitarbeiter between 20 and 500 then p.p_groesse else 0 end as int) as p_passung,
           cast(case when b.tage_online > p.s_lange_offen or b.ist_reposted = 1 then p.b_lange_offen else 0 end
              + case when b.reaktionen is not null and b.reaktionen <= 3 then p.b_reaktionen else 0 end
              + case when coalesce(z.andere, 0) > 0 and b.thema_roh > 0 then p.b_zweite else 0 end as int) as p_bonus,
           cast(case when b.mitarbeiter > p.s_konzern then p.a_konzern else 0 end
              + case when b.negativ_titel = 1 then p.a_negativ else 0 end as int) as p_abzug,
           cast(case when b.mitarbeiter > p.s_konzern then 1 else 0 end as int) as ist_konzern
    from basis b
    cross join par p
    left join zweite z on z.cluster_key = b.cluster_key
)

select
    cluster_key, hk_stelle, quelle, stelle_bk, anzahl_stellen_im_cluster, quellen_im_cluster,
    lead_typ,
    case when lead_typ is null then 1 else 0 end as ausgeschlossen,
    case when lead_typ is null then 'Festanstellung ueber Vermittler' end as ausschluss_grund,
    p_thema, coalesce(p_typ, 0) as p_typ, p_region, p_frische, p_passung, p_bonus, p_abzug,
    p_thema + coalesce(p_typ, 0) + p_region + p_frische + p_passung + p_bonus + p_abzug as vorscore,
    themen, kern_im_titel, negativ_titel, ist_konzern,
    concat_ws(' · ',
        case when p_thema > 0 then 'Thema: ' + coalesce(left(themen, 120), '') end,
        case when ist_remote = 1 then 'remote' else coalesce(nullif(region_gruppe, 'unbekannt'), 'Region unbekannt') end,
        case when veroeffentlicht_am is not null then
             case when datediff(day, veroeffentlicht_am, cast(getdate() as date)) <= 0 then 'heute' else 'vor ' + cast(datediff(day, veroeffentlicht_am, cast(getdate() as date)) as varchar(10)) + ' Tagen' end end,
        case when reaktionen is not null then cast(reaktionen as varchar(10)) + ' Reaktionen' end,
        case when ist_konzern = 1 then 'Konzern' end,
        case when negativ_titel = 1 then 'Negativbegriff im Titel' end) as begruendung_kurz,
    titel, text, text_quelle, url, veroeffentlicht_am, datum_geschaetzt, erste_sichtung, letzte_sichtung, tage_online,
    vertragsart, ist_remote, ist_hybrid, ort, bundesland, land, region_gruppe, plz,
    master_firma_bk, firma_name, ist_vermittler, mitarbeiter, branche, technologien, budget_text, stundensatz_min, reaktionen, ist_online
from punkte
