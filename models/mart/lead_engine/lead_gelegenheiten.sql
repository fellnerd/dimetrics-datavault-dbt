{#
    Mart (Tabelle, Tageslauf): lead_gelegenheiten
    Grain: 1 Zeile je Gelegenheit (Cluster derselben Stelle aus mehreren Quellen; Repraesentant mit dem besten Text), veroeffentlicht oder
           zuletzt gesehen in den letzten 30 Tagen, ohne ausgeschlossene (Festanstellung ueber Vermittler, Sperrliste, Lead-Status).
    Zweck: materialisierte Grundlage der publizierten Views lead_gelegenheiten_v (plus KI-Urteil live) und lead_ki_offen_v. Die Views allein waren
           fuer den MCP (Data API builder) zu langsam. Alle Spalten wie bisher in lead_gelegenheiten_v, ohne ki_*.
    Zusaetzlich (nicht in den Views): master_firma_bk, firma_id (Verbindung zu lead_firmen) und inhalt_geaendert_am (juengste Ladezeit einer Zeile in den
           Satelliten der Stellen des Clusters, ohne die Sichtungs-Satelliten; Grundlage fuer 'geaendert' in lead_ki_offen_v).
    Zusaetzlich: ist_personalvermittlung (Merkmal der Firma/des Textes, Seed lead_engine_regel) und ist_dublette (1 = gleicher Titel vom gleichen Auftraggeber, innerhalb
           von 30 Tagen schon frueher veroeffentlicht; lead_ki_offen_v zeigt nur die erste).
    Schluessel: gelegenheit_id (char(32)); PK-Index, dazu Index auf vorscore absteigend.
    Quellen: bv_gelegenheit_score, bv_stelle_cluster, Stellen-Satelliten
    Version: 2026-11-04 V1.0 Aus lead_gelegenheiten_v (V1.0) als Tabelle materialisiert
    Version: 2026-11-04 V1.1 ist_personalvermittlung, ist_dublette
#}
{{ config(materialized='table', as_columnstore=false, tags=['report'],
          post_hook=["{{ lead_engine_tabelle_schluessel('gelegenheit_id', 'char(32)', 'vorscore', 1) }}", "{{ lead_engine_tabelle_schluessel('gelegenheit_id', 'char(32)', 'vorscore', 2) }}", "{{ lead_engine_tabelle_schluessel('gelegenheit_id', 'char(32)', 'vorscore', 3) }}"]) }}

with s as (
    select x.*
    from {{ ref('bv_gelegenheit_score') }} x
    where x.ausgeschlossen = 0
      and (x.veroeffentlicht_am >= dateadd(day, -30, cast(getdate() as date))
           or x.letzte_sichtung >= dateadd(day, -30, cast(getdate() as date)))
),

dublette as (   -- gleicher Titel (klein, getrimmt) und gleicher Auftraggeber, Veroeffentlichung innerhalb von 30 Tagen: nur die fruehere zaehlt
    select a.cluster_key
    from s a
    where exists (select 1 from s b
                  where b.cluster_key <> a.cluster_key
                    and lower(ltrim(rtrim(b.titel))) = lower(ltrim(rtrim(a.titel)))
                    and coalesce(b.firma_name, '') = coalesce(a.firma_name, '')
                    and abs(datediff(day, b.veroeffentlicht_am, a.veroeffentlicht_am)) <= 30
                    and (b.veroeffentlicht_am < a.veroeffentlicht_am
                         or (b.veroeffentlicht_am = a.veroeffentlicht_am and b.cluster_key < a.cluster_key)))
),

geaendert as (   -- Inhaltsaenderung: juengste Zeile in einem Satelliten einer Stelle des Clusters (Sichtungs-Satelliten zaehlen nicht)
    select c.cluster_key, max(x.dss_load_date) as inhalt_geaendert_am
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
    where c.cluster_key in (select cluster_key from s)
    group by c.cluster_key
)

select
    s.cluster_key                                                                as gelegenheit_id,
    cast(abs(convert(bigint, hashbytes('MD5', s.cluster_key))) as varchar(20))   as gelegenheit_key,
    s.lead_typ, s.vorscore,
    s.p_thema, s.p_typ, s.p_region, s.p_frische, s.p_passung, s.p_bonus, s.p_abzug,
    s.begruendung_kurz, s.themen,
    s.titel,
    left(s.text, 4000)                                                           as text,
    s.url,
    s.quellen_im_cluster                                                         as quellen,
    s.firma_name, s.ist_konzern,
    case when s.mitarbeiter is null then null
         when s.mitarbeiter < 20 then 'unter 20'
         when s.mitarbeiter <= 500 then '20-500'
         when s.mitarbeiter <= 2500 then '501-2500'
         else 'ueber 2500' end                                                   as groesse,
    s.mitarbeiter, s.technologien,
    s.ort, s.ort_quelle, s.plz, s.bundesland, s.ist_remote, s.ist_hybrid,
    s.vertragsart, s.veroeffentlicht_am, s.datum_geschaetzt, s.tage_online, s.reaktionen,
    s.budget_text                                                                as budget,
    s.status, s.status_am,
    s.master_firma_bk,
    case when s.master_firma_bk is not null then convert(varchar(32), hashbytes('MD5', s.master_firma_bk), 2) end as firma_id,
    g.inhalt_geaendert_am,
    s.ist_personalvermittlung,
    cast(case when d.cluster_key is not null then 1 else 0 end as int)         as ist_dublette,
    cast(getdate() as datetime2(6))                                              as dss_load_date,
    cast('bv_gelegenheit_score' as varchar(50))                                  as dss_record_source
from s
left join geaendert g on g.cluster_key = s.cluster_key
left join dublette d on d.cluster_key = s.cluster_key
