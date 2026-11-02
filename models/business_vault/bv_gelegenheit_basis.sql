{#
    Business Vault: bv_gelegenheit_basis
    Hilfstabelle fuer bv_gelegenheit_score: je Cluster (Repraesentant) die Merkmale, die Themen-Summe, der Negativ-Treffer und der Lead-Typ.
    Eigene Tabelle, damit die teure Berechnung einmal laeuft (der Score liest sie mehrfach, auch im Selbst-Join fuer den Bonus
    "zweite relevante Gelegenheit derselben Firma").
    Grain: 1 Zeile je cluster_key.
    Version: 2026-11-02 V1.0 Initialversion (aus bv_gelegenheit_score ausgelagert)
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
                when r.quelle = 'ted' then 'A3'
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
)

select * from basis
