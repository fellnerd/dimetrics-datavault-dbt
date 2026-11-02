{#
    Business Vault (virtuell): bv_gelegenheit_score
    Grain: 1 Zeile je Cluster (bv_stelle_cluster, Repraesentant) = eine Gelegenheit. Alle Bausteine einzeln, Punkte aus ref_lead_engine__gewicht
           (Seed-Startwerte, ueberschrieben durch die Gewichte aus der Landing-Quelle suchprofil).
    Lead-Typen: A1 freelancer.at | A3 TED-Ausschreibung | A2 Vermittler mit Vertragsart freiberuflich/projekt/befristet, karriere Projektarbeit, TheirStack __projekte |
                C Partner (IT-Dienstleister/Beratung mit Themen-Treffer) | B1 Firmenstelle im Thema mit Interim/Karenz/Elternzeit/befristet,
                > 45 Tage online oder neu ausgeschrieben | B2 sonst.
    ist_konzern: Mitarbeiter > Schwelle, Konzernhinweis oder fremde Jobdomain aus dem Impressum.
    Ausgeschlossen (bleibt mit Kennzeichen in der Tabelle): Festanstellung ueber Vermittler. Lead-Status und Sperrliste folgen mit Phase B.
    Typ- und Region-Punkte gibt es nur, wenn ein Kernthema (Datenplattform, BI und Reporting, KI, Controlling) im Titel trifft; ein
    Negativbegriff im Titel nimmt sie ebenfalls (zusaetzlich zum Abzug).
    Hybrid-Bonus: wenn hybrid und die Region unter 10 Punkten liegt (Gewichte-Blatt).
    Bausteine: p_thema (0-35), p_typ, p_region (0-20), p_frische (0-15), p_passung (0-5), p_bonus (bis +15), p_abzug (bis -25); vorscore = Summe.
    Materialisierung: Tabelle (statt View): lead_gelegenheiten_v und lead_firmen_v lesen sie mehrfach, als View waere jede Abfrage zu teuer.
    Version: 2026-10-26 V1.0 Erste Fassung
#}
{{ config(materialized='table', as_columnstore=false, tags=['business_vault']) }}

with par as (   -- skalare Parameter aus den Gewichten
    select
        max(case when bereich = 'thema'   and schluessel = 'deckel'              then punkte end) as thema_deckel,
        max(case when bereich = 'thema'   and schluessel = 'titel_faktor'        then punkte end) as titel_faktor,
        max(case when bereich = 'thema'   and schluessel = 'max_ohne_kern_im_titel' then punkte end) as ohne_kern_max,
        max(case when bereich = 'passung' and schluessel = 'satz_ab_60_eur_h'      then punkte end) as p_stundensatz,
        max(case when bereich = 'passung' and schluessel = 'groesse_20_500'        then punkte end) as p_groesse,
        max(case when bereich = 'bonus'   and schluessel = 'lange_offen_45_tage'  then punkte end) as b_lange_offen,
        max(case when bereich = 'bonus'   and schluessel = 'wenig_reaktionen_max_3' then punkte end) as b_reaktionen,
        max(case when bereich = 'bonus'   and schluessel = 'zweites_signal_60_tage' then punkte end) as b_zweite,
        max(case when bereich = 'abzug'   and schluessel = 'konzern'             then punkte end) as a_konzern,
        max(case when bereich = 'abzug'   and schluessel = 'negativ_im_titel'      then punkte end) as a_negativ,
        max(case when bereich = 'parameter' and schluessel = 'lange_offen_tage'   then punkte end) as s_lange_offen,
        max(case when bereich = 'parameter' and schluessel = 'konzern_mitarbeiter' then punkte end) as s_konzern,
        max(case when bereich = 'region'  and schluessel = 'hybrid_bonus'        then punkte end) as r_hybrid
    from {{ ref('ref_lead_engine__gewicht') }}
),

basis as (
    select * from {{ ref('bv_gelegenheit_basis') }}
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
           cast(case when b.negativ_titel = 1 or b.kern_im_titel = 0 then 0 else (select g.punkte from {{ ref('ref_lead_engine__gewicht') }} g where g.bereich = 'typ' and g.schluessel = b.lead_typ) end as int) as p_typ,
           cast(case when b.negativ_titel = 1 or b.kern_im_titel = 0 then 0 when b.ist_remote = 1 then (select g.punkte from {{ ref('ref_lead_engine__gewicht') }} g where g.bereich = 'region' and g.schluessel = 'remote')
                     else coalesce((select g.punkte from {{ ref('ref_lead_engine__gewicht') }} g where g.bereich = 'region' and g.schluessel = b.region_gruppe), 0)
                          + case when b.ist_hybrid = 1 and coalesce((select g.punkte from {{ ref('ref_lead_engine__gewicht') }} g where g.bereich = 'region' and g.schluessel = b.region_gruppe), 0) < 10 then p.r_hybrid else 0 end
                end as int) as p_region,
           cast(coalesce((select g.punkte from {{ ref('ref_lead_engine__gewicht') }} g where g.bereich = 'frische' and g.schluessel =
                    case when datediff(day, b.veroeffentlicht_am, cast(getdate() as date)) <= 3 then 'bis_3_tage'
                         when datediff(day, b.veroeffentlicht_am, cast(getdate() as date)) <= 7 then 'bis_7_tage'
                         when datediff(day, b.veroeffentlicht_am, cast(getdate() as date)) <= 14 then 'bis_14_tage'
                         when datediff(day, b.veroeffentlicht_am, cast(getdate() as date)) <= 30 then 'bis_30_tage' else 'aelter' end), 0) as int) as p_frische,
           cast(case when b.stundensatz_min >= 60 or b.budget_text is not null then p.p_stundensatz else 0 end
              + case when b.mitarbeiter between 20 and 500 then p.p_groesse else 0 end as int) as p_passung,
           cast(case when b.tage_online > p.s_lange_offen or b.ist_reposted = 1 then p.b_lange_offen else 0 end
              + case when b.reaktionen is not null and b.reaktionen <= 3 then p.b_reaktionen else 0 end
              + case when coalesce(z.andere, 0) > 0 and b.thema_roh > 0 then p.b_zweite else 0 end as int) as p_bonus,
           cast(case when b.mitarbeiter > p.s_konzern or b.konzern_hinweis is not null or b.fremde_jobdomain is not null then p.a_konzern else 0 end
              + case when b.negativ_titel = 1 then p.a_negativ else 0 end as int) as p_abzug,
           cast(case when b.mitarbeiter > p.s_konzern or b.konzern_hinweis is not null or b.fremde_jobdomain is not null then 1 else 0 end as int) as ist_konzern
    from basis b
    cross join par p
    left join zweite z on z.cluster_key = b.cluster_key
),

markiert as (
    select p.*,
           ls.status                                                   as status_roh,
           ls.datum                                                    as status_am,
           sp.sperr_grund,
           case when p.lead_typ is null then 'Festanstellung ueber Vermittler'
                when sp.master_firma_bk is not null then 'Sperrliste: ' + coalesce(sp.sperr_grund, 'gesperrt')
                when ls.status in ('beworben', 'kontaktiert', 'kein fit', 'erledigt') then 'Lead-Status: ' + ls.status
           end                                                         as ausschluss_grund_neu
    from punkte p
    left join {{ ref('bv_firma_sperre') }} sp on sp.master_firma_bk = p.master_firma_bk
    left join {{ ref('ref_lead_engine__lead_status') }} ls
           on ls.gelegenheit_id = p.cluster_key
           or (ls.gelegenheit_id is null and p.master_firma_bk is not null
               and ls.firma_norm = (select top 1 f.name_norm from {{ ref('bv_firma_same_as') }} f where f.master_firma_bk = p.master_firma_bk and f.name_norm <> ''))
)

select
    cluster_key, hk_stelle, quelle, stelle_bk, anzahl_stellen_im_cluster, quellen_im_cluster,
    lead_typ,
    case when ausschluss_grund_neu is not null then 1 else 0 end as ausgeschlossen,
    ausschluss_grund_neu as ausschluss_grund,
    status_roh as status, status_am,
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
from markiert
