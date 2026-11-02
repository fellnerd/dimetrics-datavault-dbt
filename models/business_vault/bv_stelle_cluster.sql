{#
    Business Vault (virtuell): bv_stelle_cluster
    Zweck: dieselbe Stelle ueber mehrere Quellen zusammenfassen (Adzuna sammelt auch Anzeigen von karriere.at, Websites usw.).
    Cluster-Schluessel: master_firma_bk (bv_firma_same_as) + normalisierter Titel (klein, ohne (m/w/d)-Varianten, ohne Satzzeichen).
    Stellen ohne bekannte Firma (z. B. freelancer.at) oder ohne Titel bilden ein eigenes Cluster.
    Repraesentant: die Stelle mit dem besten Text (laengster Text, dann Quellen-Reihenfolge TheirStack, freelancer, Adzuna, karriere, website).
    Grain: 1 Zeile je hk_stelle mit cluster_key; ist_repraesentant = 1 genau einmal je Cluster.
    Version: 2026-10-26 V1.0 Erste Fassung
#}
{{ config(materialized='view', tags=['business_vault']) }}

with m as (
    select hk_stelle, quelle, stelle_bk, master_firma_bk, titel,
           len(coalesce(text, '')) as text_laenge,
           {{ lead_engine_titel_norm('titel') }} as titel_norm
    from {{ ref('bv_stelle_merkmale') }}
),

k as (
    select m.*,
           case when m.master_firma_bk is not null and m.titel_norm <> ''
                then m.master_firma_bk + '|' + m.titel_norm
                else 'einzeln:' + m.quelle + ':' + m.stelle_bk end as cluster_text
    from m
),

r as (
    select k.*,
           convert(char(32), hashbytes('MD5', k.cluster_text), 2) as cluster_key,
           row_number() over (partition by k.cluster_text
                              order by k.text_laenge desc,
                                       case k.quelle when 'theirstack' then 1 when 'freelancer' then 2 when 'adzuna' then 3
                                                     when 'karriere' then 4 else 5 end,
                                       k.hk_stelle) as rn,
           count(*) over (partition by k.cluster_text) as anzahl_stellen
    from k
)

select r.hk_stelle, r.cluster_key, case when r.rn = 1 then 1 else 0 end as ist_repraesentant,
       r.anzahl_stellen as anzahl_stellen_im_cluster,
       (select string_agg(q.quelle, ', ') within group (order by q.quelle)
          from (select distinct r2.quelle from r r2 where r2.cluster_text = r.cluster_text) q) as quellen_im_cluster,
       r.titel_norm
from r
