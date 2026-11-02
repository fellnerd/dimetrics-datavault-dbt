{#
    Mart (publizierte View): lead_firmen_v
    Grain: 1 Zeile je Master-Firma (master_firma_bk aus bv_firma_same_as) mit mindestens einer Gelegenheit in den letzten 30 Tagen
           (veroeffentlicht oder zuletzt gesehen, nicht ausgeschlossen). Gelegenheiten ohne bekannte Firma (z. B. freelancer.at, TED)
           erscheinen nur in lead_gelegenheiten_v.
    Zweck: Firmenblick auf die Gelegenheiten: bester Vorscore, Zahl der Gelegenheiten (ab Vorscore 40), Themen, Region, Groesse, Konzern,
           Technologien. Ersetzt nach Umstellung des Skills lead_kandidaten_v.
    Schluessel: firma_id (varchar, Hash des Masters) statt bigint (das MCP-Blaettern scheitert an grossen bigint-Schluesseln).
    Offen: firmenbuch_ereignisse (Phase B b, wartet auf die Firmenbuch-Daten), status/status_am (Lead-Status, Phase B f).
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
    q.quellen,
    jf.erste_sichtung, jf.letzte_sichtung,
    t.gelegenheiten                                                                 as beste_gelegenheiten,
    cast(null as nvarchar(1000))                                                    as firmenbuch_ereignisse,
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
where b.rn = 1
