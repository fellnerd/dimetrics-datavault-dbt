{#
    Business Vault: bv_gelegenheit_basis
    Hilfstabelle fuer bv_gelegenheit_score: je Cluster (Repraesentant) die Merkmale, die Themen-Summe, der Negativ-Treffer und der Lead-Typ.
    Eigene Tabelle, damit die teure Berechnung einmal laeuft (der Score liest sie mehrfach, auch im Selbst-Join fuer den Bonus
    "zweite relevante Gelegenheit derselben Firma").
    Grain: 1 Zeile je cluster_key.
    Version: 2026-11-02 V1.0 Initialversion (aus bv_gelegenheit_score ausgelagert)
    Version: 2026-11-04 V1.1 Vorscore nachgeschaerft (Befund KI-Lauf ki-20261104T0532): Merkmale ist_personalvermittlung, einsteiger_titel, fremdsystem,
                 daten_signal, ki_ohne_daten; Controlling zaehlt nur mit Daten-/Reporting-Signal als Kernthema im Titel. Begriffe im Seed lead_engine_regel.
    Daten-Signal: Treffer im Titel (Thema Datenplattform oder BI und Reporting, oder Microsoft-Stack-Begriff aus ms_signal) oder mindestens zwei verschiedene
    solche Begriffe im Text (ein einzelnes Wort wie "reporting" in einem Vertriebstext zaehlt nicht).
    Personalvermittlung: Firmenname oder Textmuster aus dem Seed (Regeln vermittler_firma, vermittler_text) oder TheirStack-Kennzeichen ist_vermittler.
    Fremdsystem: Begriff der Regel fremd_system im Titel, oder mindestens zwei verschiedene im Text ohne Microsoft-Stack-Begriff.
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
           max(case when jt.im_titel = 1 and jt.thema in ('Datenplattform', 'BI und Reporting', 'KI') then 1 else 0 end) as kern_titel_daten_ki,
           max(case when jt.im_titel = 1 and jt.thema = 'Controlling' then 1 else 0 end) as kern_titel_controlling,
           max(case when jt.thema in ('Datenplattform', 'BI und Reporting') then 1 else 0 end) as hat_daten,
           max(case when jt.thema = 'KI' then 1 else 0 end) as hat_ki,
           string_agg(jt.thema + ': ' + jt.begriff + case when jt.im_titel = 1 then ' (Titel)' else '' end, ' | ') within group (order by jt.punkte desc) as themen,
           max(jt.thema + ': ' + jt.begriff + case when jt.im_titel = 1 then ' (Titel)' else '' end) as top_thema_text
    from je_thema jt
    group by jt.cluster_key
),

regel as (
    select regel, modus, cast(begriff as nvarchar(200)) collate Latin1_General_BIN2 as b
    from {{ ref('lead_engine_regel') }}
),

regel_treffer as (   -- Seed-Begriffe gegen Titel, Text und Firmenname des Repraesentanten (normalisierte Texte aus bv_stelle_text)
    select r.cluster_key, g.regel, g.b,
           g.treffer_titel, g.treffer_text, g.treffer_firma
    from rep r
    join {{ ref('bv_stelle_text') }} t on t.hk_stelle = r.hk_stelle
    cross apply (select g1.regel, g1.b,
                        case g1.modus when 'wort' then case when charindex(' ' + g1.b + ' ', t.titel_n) > 0 then 1 else 0 end
                                      when 'prefix' then case when charindex(' ' + g1.b, t.titel_n) > 0 then 1 else 0 end
                                      else case when charindex(g1.b, t.titel_n) > 0 then 1 else 0 end end as treffer_titel,
                        case g1.modus when 'wort' then case when charindex(' ' + g1.b + ' ', t.titel_n + t.text_n) > 0 then 1 else 0 end
                                      when 'prefix' then case when charindex(' ' + g1.b, t.titel_n + t.text_n) > 0 then 1 else 0 end
                                      else case when charindex(g1.b, t.titel_n + t.text_n) > 0 then 1 else 0 end end as treffer_text,
                        case when charindex(g1.b, cast(lower(coalesce(r.firma_name, '')) as nvarchar(400)) collate Latin1_General_BIN2) > 0 then 1 else 0 end as treffer_firma
                 from regel g1) g
    where g.treffer_titel = 1 or g.treffer_text = 1 or g.treffer_firma = 1
),

regel_flag as (
    select cluster_key,
           max(case when regel = 'titel_abschlag'   and treffer_titel = 1 then 1 else 0 end) as einsteiger_titel,
           max(case when regel = 'fremd_system'     and treffer_titel = 1 then 1 else 0 end) as fremd_titel,
           count(distinct case when regel = 'fremd_system' and treffer_text = 1 then b end)  as fremd_text_anzahl,
           max(case when regel = 'ms_signal'        and treffer_text = 1 then 1 else 0 end) as ms_signal,
           max(case when regel = 'ms_signal'        and treffer_titel = 1 then 1 else 0 end) as ms_titel,
           max(case when regel = 'vermittler_firma' and treffer_firma = 1 then 1 else 0 end) as vermittler_name,
           max(case when regel = 'vermittler_text'  and treffer_text = 1 then 1 else 0 end) as vermittler_text
    from regel_treffer
    group by cluster_key
),

daten_signal as (   -- starkes Daten-Signal: Treffer im Titel (Thema Datenplattform/BI oder Microsoft-Stack) oder mindestens zwei verschiedene Begriffe (Themen + Stack) im Text
    select u.cluster_key,
           max(u.im_titel) as im_titel,
           count(distinct u.begriff) as anzahl
    from (select tr.cluster_key, cast(tr.begriff as nvarchar(200)) collate Latin1_General_BIN2 as begriff, case when tr.fundort = 'titel' then 1 else 0 end as im_titel
          from treffer tr where tr.thema in ('Datenplattform', 'BI und Reporting')
          union all
          select rt.cluster_key, rt.b, rt.treffer_titel from regel_treffer rt where rt.regel = 'ms_signal' and rt.treffer_text = 1) u
    group by u.cluster_key
),

negativ as (
    select distinct cluster_key from treffer where thema = 'Negativ' and fundort = 'titel'
),

basis as (
    select r.*,
           coalesce(ts.roh, 0) as thema_roh, ts.themen,
           -- Kernthema im Titel: Daten/BI/KI immer; Controlling nur mit Daten-/Reporting-Signal (reine Controlling-Stellen zaehlen nicht wie BI)
           case when coalesce(ts.kern_titel_daten_ki, 0) = 1
                  or (coalesce(ts.kern_titel_controlling, 0) = 1 and (coalesce(ds.im_titel, 0) = 1 or coalesce(ds.anzahl, 0) >= 2)) then 1 else 0 end as kern_im_titel,
           cast(case when coalesce(ds.im_titel, 0) = 1 or coalesce(ds.anzahl, 0) >= 2 then 1 else 0 end as int) as daten_signal,
           cast(coalesce(ds.im_titel, 0) as int) as daten_titel, cast(coalesce(ds.anzahl, 0) as int) as daten_anzahl,
           cast(case when coalesce(ts.hat_ki, 0) = 1 and coalesce(ds.im_titel, 0) = 0 and coalesce(ds.anzahl, 0) < 2 then 1 else 0 end as int) as ki_ohne_daten,
           cast(case when coalesce(rf.vermittler_name, 0) = 1 or coalesce(rf.vermittler_text, 0) = 1 or r.ist_vermittler = 1 then 1 else 0 end as int) as ist_personalvermittlung,
           cast(coalesce(rf.einsteiger_titel, 0) as int) as einsteiger_titel,
           cast(case when coalesce(rf.fremd_titel, 0) = 1 or (coalesce(rf.fremd_text_anzahl, 0) >= 2 and coalesce(rf.ms_signal, 0) = 0) then 1 else 0 end as int) as fremdsystem,
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
    left join regel_flag rf on rf.cluster_key = r.cluster_key
    left join daten_signal ds on ds.cluster_key = r.cluster_key
    left join negativ ng on ng.cluster_key = r.cluster_key
)

select * from basis
