{#
    Mart (publizierte View): lead_ki_offen_v
    Arbeitsliste fuer den Skill lead-bewertung (taeglich 06:30): Gelegenheiten, die ein KI-Urteil brauchen.
    Aufnahme: wie lead_gelegenheiten_v (30 Tage, nicht ausgeschlossen) und vorscore >= 40, Status nicht 'kein fit' oder 'erledigt', und
      grund 'neu'        : noch kein KI-Urteil
      grund 'geaendert'  : seit dem letzten Urteil hat ein Satellit einer Stelle des Clusters eine neue Zeile bekommen (Inhalt geaendert oder neue Quelle);
                           die Sichtungs-Satelliten zaehlen nicht (die aendern sich bei jedem Lauf).
    Sortierung der Ausgabe: vorscore absteigend (ORDER BY im Abruf). Schluessel gelegenheit_id (varchar, erste Spalte).
    Firma, Firmenbuch und Jahresabschluss je Master-Firma, nur fuer die Gelegenheiten dieser Liste berechnet.
    Quellen: bv_gelegenheit_score, bv_stelle_cluster, bv_firma_same_as, Satelliten, landing.lead_engine_ki_bewertung (live)
    Version: 2026-11-03 V1.0 Erste Fassung
#}
{{ config(materialized='view', tags=['report']) }}

with s as (
    select x.*
    from {{ ref('bv_gelegenheit_score') }} x
    where x.ausgeschlossen = 0
      and x.vorscore >= 40
      and coalesce(x.status, '') not in ('kein fit', 'erledigt')
      and (x.veroeffentlicht_am >= dateadd(day, -30, cast(getdate() as date))
           or x.letzte_sichtung >= dateadd(day, -30, cast(getdate() as date)))
),

ki as (   -- juengstes Urteil je Gelegenheit, live
    select x.gelegenheit_id, x.ki_einstufung, x.bewertet_am
    from (select k.*, row_number() over (partition by k.gelegenheit_id order by k.bewertet_am desc, k.bewertung_id desc) as rn
          from {{ source('lead_engine', 'lead_engine_ki_bewertung') }} k) x
    where x.rn = 1
),

offen as (
    select s.*, ki.ki_einstufung as ki_bisher, ki.bewertet_am as ki_bewertet_am,
           case when ki.gelegenheit_id is null then 'neu' else 'geaendert' end as grund
    from s
    left join ki on ki.gelegenheit_id = s.cluster_key collate database_default
    where ki.gelegenheit_id is null
       or exists (select 1
                  from {{ ref('bv_stelle_cluster') }} c
                  join (select hk_stelle, dss_load_date from {{ ref('sat_stelle__karriere') }}
                        union all select hk_stelle, dss_load_date from {{ ref('sat_stelle__karriere_text') }}
                        union all select hk_stelle, dss_load_date from {{ ref('sat_stelle__karriere_detail') }}
                        union all select hk_stelle, dss_load_date from {{ ref('sat_stelle__theirstack') }}
                        union all select hk_stelle, dss_load_date from {{ ref('sat_stelle__theirstack_detail') }}
                        union all select hk_stelle, dss_load_date from {{ ref('sat_stelle__freelancer') }}
                        union all select hk_stelle, dss_load_date from {{ ref('sat_stelle__freelancer_detail') }}
                        union all select hk_stelle, dss_load_date from {{ ref('sat_stelle__adzuna') }}
                        union all select hk_stelle, dss_load_date from {{ ref('sat_stelle__website') }}
                        union all select hk_stelle, dss_load_date from {{ ref('sat_stelle__ted') }}) x on x.hk_stelle = c.hk_stelle
                  where c.cluster_key = s.cluster_key and x.dss_load_date > ki.bewertet_am)
),

masters as (select distinct master_firma_bk from offen where master_firma_bk is not null),

firma as (   -- Firmenbuch und Jahresabschluss je Master (ueber alle Firmen des Masters)
    select f.master_firma_bk,
           min(fb.fn) as fn, min(fb.rechtsform) as rechtsform, min(fb.sitz) as firmenbuch_sitz,
           max(case when ev.letzte_veraenderung_am is not null then concat(ev.letzte_art, ' am ', convert(varchar(10), ev.letzte_veraenderung_am, 23), ' (', ev.anzahl_veraenderungen, ' im Zeitraum ', ev.zeitraum_von, ' bis ', ev.zeitraum_bis, ')') end) as firmenbuch_ereignisse
    from {{ ref('bv_firma_same_as') }} f
    left join {{ ref('sat_firma__firmenbuch') }} fb on fb.hk_firma = f.hk_firma and fb.dss_is_current = 'Y'
    left join {{ ref('sat_firma__firmenbuch_ereignis') }} ev on ev.hk_firma = f.hk_firma and ev.dss_is_current = 'Y'
    where f.master_firma_bk in (select master_firma_bk from masters)
    group by f.master_firma_bk
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
          where f.master_firma_bk in (select master_firma_bk from masters)) x
    group by x.master_firma_bk
),

abschluss as (
    select x.*
    from (select f.master_firma_bk, ja.stichtag, ja.groessenklasse, ja.groessenklasse_code, ja.bilanzsumme, ja.umsatzerloese, ja.eigenkapital,
                 ja.jahresergebnis, ja.mitarbeiter_durchschnitt,
                 row_number() over (partition by f.master_firma_bk order by ja.stichtag desc, f.hk_firma) as rn
          from {{ ref('bv_firma_same_as') }} f
          join {{ ref('sat_firma__jahresabschluss') }} ja on ja.hk_firma = f.hk_firma and ja.dss_is_current = 'Y'
          where f.master_firma_bk in (select master_firma_bk from masters)) x
    where x.rn = 1
)

select
    o.cluster_key                                                                  as gelegenheit_id,
    o.vorscore, o.lead_typ,
    o.titel, o.url,
    left(o.text, 4000)                                                             as text,
    o.firma_name,
    case when o.master_firma_bk is not null then convert(varchar(32), hashbytes('MD5', o.master_firma_bk), 2) end as firma_id,
    o.ort, o.ort_quelle, o.bundesland, o.ist_remote, o.veroeffentlicht_am,
    o.begruendung_kurz,
    o.p_thema, o.p_typ, o.p_region, o.p_frische, o.p_passung, o.p_bonus, o.p_abzug,
    case when o.mitarbeiter is null then null
         when o.mitarbeiter < 20 then 'unter 20'
         when o.mitarbeiter <= 500 then '20-500'
         when o.mitarbeiter <= 2500 then '501-2500'
         else 'ueber 2500' end                                                     as groesse,
    o.ist_konzern,
    ab.groessenklasse, ab.groessenklasse_code, ab.stichtag                         as abschluss_stichtag,
    ab.bilanzsumme, ab.umsatzerloese, ab.eigenkapital, ab.jahresergebnis, ab.mitarbeiter_durchschnitt as mitarbeiter_abschluss,
    fi.fn, fi.rechtsform, fi.firmenbuch_sitz, fi.firmenbuch_ereignisse,
    fu.geschaeftsfuehrung, coalesce(fu.anzahl_prokuristen, 0) as anzahl_prokuristen,
    o.grund, o.ki_bisher                                                           as ki_bisherige_einstufung, o.ki_bewertet_am
from offen o
left join firma fi on fi.master_firma_bk = o.master_firma_bk
left join abschluss ab on ab.master_firma_bk = o.master_firma_bk
left join funktion fu on fu.master_firma_bk = o.master_firma_bk
