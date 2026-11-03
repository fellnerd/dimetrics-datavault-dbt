{#
    Mart (publizierte View): lead_firmen_v
    Grain: 1 Zeile je Master-Firma (master_firma_bk aus bv_firma_same_as) mit mindestens einer Gelegenheit in den letzten 30 Tagen
           (veroeffentlicht oder zuletzt gesehen, nicht ausgeschlossen). Gelegenheiten ohne bekannte Firma (z. B. freelancer.at, TED)
           erscheinen nur in lead_gelegenheiten_v.
    Zweck: Firmenblick auf die Gelegenheiten: bester Vorscore, Zahl der Gelegenheiten (ab Vorscore 40), Themen, Region, Groesse, Konzern,
           Technologien. Ersetzt nach Umstellung des Skills lead_kandidaten_v.
    Schluessel: firma_id (varchar, Hash des Masters) statt bigint (das MCP-Blaettern scheitert an grossen bigint-Schluesseln).
    Firmenbuch: fn, rechtsform, firmenbuch_sitz und firmenbuch_ereignisse (juengste Veraenderung im Firmenbuch) aus sat_firma__firmenbuch(_ereignis).
    Funktionstraeger: geschaeftsfuehrung (GF, Vorstand, Geschaeftsleiter, Komplementaere mit Funktion und seit) und anzahl_prokuristen aus sat_firma__firmenbuch_funktion.
    Jahresabschluss: groessenklasse, abschluss_stichtag, bilanzsumme, umsatzerloese, eigenkapital, jahresergebnis, mitarbeiter_abschluss (nur Kennzahlen; Umsatz,
    Ergebnis und Mitarbeiter nur wenn offengelegt) aus sat_firma__jahresabschluss.
    Quellen: bv_gelegenheit_score, bv_stelle_cluster, bv_stelle_thema
    Version: 2026-11-02 V1.0 Erste Fassung
#}
{{ config(materialized='view', tags=['report']) }}

with g as (
    select s.*,
           row_number() over (partition by s.master_firma_bk order by s.vorscore desc, s.veroeffentlicht_am desc, s.cluster_key) as rn
    from {{ ref('bv_gelegenheit_score') }} s
    where s.ausgeschlossen = 0
      and s.master_firma_bk is not null
      and (s.veroeffentlicht_am >= dateadd(day, -30, cast(getdate() as date))
           or s.letzte_sichtung >= dateadd(day, -30, cast(getdate() as date)))
),

themen as (   -- verschiedene Themen ueber alle Stellen der Gelegenheiten der Firma
    select x.master_firma_bk, string_agg(x.thema, ', ') within group (order by x.thema) as themen
    from (select distinct g2.master_firma_bk, t.thema
          from g g2
          join {{ ref('bv_stelle_cluster') }} c on c.cluster_key = g2.cluster_key
          join {{ ref('bv_stelle_thema') }} t on t.hk_stelle = c.hk_stelle
          where t.thema <> 'Negativ') x
    group by x.master_firma_bk
),

je_firma as (
    select
        g.master_firma_bk,
        count(*)                                                                    as anzahl_gelegenheiten,
        sum(case when g.vorscore >= 40 then 1 else 0 end)                           as anzahl_ab_40,
        max(g.vorscore)                                                             as bester_vorscore,
        max(g.ist_konzern)                                                          as ist_konzern,
        max(g.ist_vermittler)                                                       as ist_vermittler,
        min(g.erste_sichtung)                                                       as erste_sichtung,
        max(g.letzte_sichtung)                                                      as letzte_sichtung
    from g
    group by g.master_firma_bk
),

quellen as (
    select x.master_firma_bk, string_agg(x.q, ', ') within group (order by x.q) as quellen
    from (select distinct g.master_firma_bk, ltrim(rtrim(sp.[value])) as q
          from g cross apply string_split(g.quellen_im_cluster, ',') sp) x
    group by x.master_firma_bk
),

regionen as (
    select x.master_firma_bk, string_agg(x.bundesland, ', ') within group (order by x.bundesland) as regionen
    from (select distinct g.master_firma_bk, g.bundesland from g where g.bundesland is not null) x
    group by x.master_firma_bk
),

firmenbuch as (   -- FN, Rechtsform, Sitz und juengstes Firmenbuch-Signal je Master (ueber alle Firmen des Masters)
    select f.master_firma_bk,
           min(fb.fn) as fn, min(fb.rechtsform) as rechtsform, min(fb.sitz) as sitz,
           max(ev.letzte_veraenderung_am) as letzte_veraenderung_am,
           max(case when ev.letzte_veraenderung_am is not null then concat(ev.letzte_art, ' am ', convert(varchar(10), ev.letzte_veraenderung_am, 23), ' (', ev.anzahl_veraenderungen, ' im Zeitraum ', ev.zeitraum_von, ' bis ', ev.zeitraum_bis, ')') end) as ereignis_text
    from {{ ref('bv_firma_same_as') }} f
    left join {{ ref('sat_firma__firmenbuch') }} fb on fb.hk_firma = f.hk_firma and fb.dss_is_current = 'Y'
    left join {{ ref('sat_firma__firmenbuch_ereignis') }} ev on ev.hk_firma = f.hk_firma and ev.dss_is_current = 'Y'
    where f.master_firma_bk in (select master_firma_bk from je_firma)
    group by f.master_firma_bk
),

ki_firma as (   -- KI-Urteile der Gelegenheiten der Firma (juengstes Urteil je Gelegenheit, live aus der Eingangstabelle)
    select g.master_firma_bk, min(k.ki_einstufung) as ki_einstufung_beste, sum(case when k.ki_einstufung = 'A' then 1 else 0 end) as ki_anzahl_a
    from g
    join (select x.gelegenheit_id, x.ki_einstufung
          from (select k0.*, row_number() over (partition by k0.gelegenheit_id order by k0.bewertet_am desc, k0.bewertung_id desc) as rn
                from {{ source('lead_engine', 'lead_engine_ki_bewertung') }} k0) x
          where x.rn = 1) k on k.gelegenheit_id = g.cluster_key collate database_default
    group by g.master_firma_bk
),

funktion as (   -- Geschaeftsfuehrung und Prokura laut Firmenbuch-Auszug je Master (jeweils aktueller Stand)
    select x.master_firma_bk,
           left(string_agg(case when x.funktion_code in ('GF', 'VM', 'GL', 'KP') then x.anzeige end, ' | ') within group (order by x.seit, x.nachname), 1500) as geschaeftsfuehrung,
           sum(case when x.funktion_code = 'PR' then 1 else 0 end) as anzahl_prokuristen
    from (select distinct f.master_firma_bk, fu.funktion_code, fu.pnr, fu.nachname, fu.seit,
                 concat(concat_ws(' ', fu.titel, fu.vorname, fu.nachname), case when fu.titel_nach is not null then ', ' + fu.titel_nach else '' end,
                        ' (', fu.funktion, case when fu.seit is not null then concat(', seit ', convert(varchar(10), fu.seit, 23)) else '' end, ')') as anzeige
          from {{ ref('bv_firma_same_as') }} f
          join {{ ref('sat_firma__firmenbuch_funktion') }} fu on fu.hk_firma = f.hk_firma and fu.dss_is_current = 'Y'
          where f.master_firma_bk in (select master_firma_bk from je_firma)) x
    group by x.master_firma_bk
),

abschluss as (   -- Kennzahlen des juengsten Jahresabschlusses je Master (ueber alle Firmen des Masters)
    select x.*
    from (select f.master_firma_bk, ja.stichtag, ja.groessenklasse, ja.bilanzsumme, ja.umsatzerloese, ja.eigenkapital, ja.jahresergebnis,
                 ja.mitarbeiter_durchschnitt,
                 row_number() over (partition by f.master_firma_bk order by ja.stichtag desc, f.hk_firma) as rn
          from {{ ref('bv_firma_same_as') }} f
          join {{ ref('sat_firma__jahresabschluss') }} ja on ja.hk_firma = f.hk_firma and ja.dss_is_current = 'Y'
          where f.master_firma_bk in (select master_firma_bk from je_firma)) x
    where x.rn = 1
),

titel as (   -- die besten Gelegenheiten der Firma als Text
    select x.master_firma_bk,
           left(string_agg(cast(concat(x.titel, ' [', x.lead_typ, ' ', x.vorscore, ']') as nvarchar(max)), ' | ')
                within group (order by x.vorscore desc), 2000) as gelegenheiten
    from (select top (100) percent g.master_firma_bk, g.titel, g.lead_typ, g.vorscore from g where g.rn <= 5 order by g.vorscore desc) x
    group by x.master_firma_bk
)

select
    convert(varchar(32), hashbytes('MD5', b.master_firma_bk), 2)                    as firma_id,
    b.master_firma_bk,
    b.firma_name,
    jf.bester_vorscore, b.lead_typ                                                  as bester_lead_typ,
    jf.anzahl_gelegenheiten, jf.anzahl_ab_40,
    th.themen,
    rg.regionen, b.bundesland                                                       as region_beste,
    case when b.mitarbeiter is null then null
         when b.mitarbeiter < 20 then 'unter 20'
         when b.mitarbeiter <= 500 then '20-500'
         when b.mitarbeiter <= 2500 then '501-2500'
         else 'ueber 2500' end                                                      as groesse,
    b.mitarbeiter, jf.ist_konzern, jf.ist_vermittler,
    b.branche, b.technologien,
    fbk.fn, fbk.rechtsform, fbk.sitz                                                as firmenbuch_sitz,
    fu.geschaeftsfuehrung, coalesce(fu.anzahl_prokuristen, 0)                       as anzahl_prokuristen,
    ab.groessenklasse, ab.stichtag                                                  as abschluss_stichtag,
    ab.bilanzsumme, ab.umsatzerloese, ab.eigenkapital, ab.jahresergebnis,
    ab.mitarbeiter_durchschnitt                                                     as mitarbeiter_abschluss,
    q.quellen,
    jf.erste_sichtung, jf.letzte_sichtung,
    t.gelegenheiten                                                                 as beste_gelegenheiten,
    fbk.ereignis_text                                                               as firmenbuch_ereignisse,
    kf.ki_einstufung_beste, coalesce(kf.ki_anzahl_a, 0)                             as ki_anzahl_a,
    (select top 1 s2.status from {{ ref('ref_lead_engine__lead_status') }} s2
      where s2.firma_norm <> '' and s2.firma_norm = (select top 1 f.name_norm from {{ ref('bv_firma_same_as') }} f where f.master_firma_bk = b.master_firma_bk and f.name_norm <> '')
      order by s2.datum desc)                                                       as status,
    (select top 1 s2.datum from {{ ref('ref_lead_engine__lead_status') }} s2
      where s2.firma_norm <> '' and s2.firma_norm = (select top 1 f.name_norm from {{ ref('bv_firma_same_as') }} f where f.master_firma_bk = b.master_firma_bk and f.name_norm <> '')
      order by s2.datum desc)                                                       as status_am
from g b
join je_firma jf on jf.master_firma_bk = b.master_firma_bk
left join themen th on th.master_firma_bk = b.master_firma_bk
left join quellen q on q.master_firma_bk = b.master_firma_bk
left join regionen rg on rg.master_firma_bk = b.master_firma_bk
left join titel t on t.master_firma_bk = b.master_firma_bk
left join firmenbuch fbk on fbk.master_firma_bk = b.master_firma_bk
left join abschluss ab on ab.master_firma_bk = b.master_firma_bk
left join funktion fu on fu.master_firma_bk = b.master_firma_bk
left join ki_firma kf on kf.master_firma_bk = b.master_firma_bk
where b.rn = 1
