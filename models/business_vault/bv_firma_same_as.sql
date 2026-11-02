{#
    Business Vault (virtuell): bv_firma_same_as
    Zweck: jeder Firma (hub_firma, je Quelle getrennt) einen Master zuordnen, damit dieselbe Firma aus karriere, TheirStack,
           website, Firmenprofil und Adzuna zusammenfindet.
    Reihenfolge der Regeln: FN (Impressum; Firmenbuch folgt) -> Domain ohne www. -> normalisierter Name
           (klein, Rechtsformen und Sonderzeichen entfernt). Hat eine Firma nur einen Namen, ein anderer Eintrag mit demselben
           Namen aber eine Domain, uebernimmt sie diese Domain (abgleich_regel 'name>domain').
    Grain: 1 Zeile je hk_firma (ohne firma_bk '-1').
    Hat eine Firma keine FN, aber dieselbe Domain wie eine Firma mit FN, uebernimmt sie deren FN ('domain>fn').
    Ausgabe: master_firma_bk ('fn:<fn>' | 'd:<domain>' | 'n:<name>' | '<quelle>:<bk>'), abgleich_regel (fn, domain>fn, domain, name>domain, name, keine).
    Quellen: hub_firma, sat_firma__karriere, __theirstack, __firmenprofil, __adzuna, __website (jeweils aktueller Stand)
    Version: 2026-10-26 V1.0 Initialversion (ohne FN)
    Version: 2026-11-02 V1.1 FN aus sat_firma__impressum
#}
{{ config(materialized='view', tags=['business_vault']) }}

with f as (
    select
        h.hk_firma, h.collision_code, h.firma_bk,
        coalesce(k.company_name, t.company_name, fp.firma_name, ad.firma_name, wf.firma_name) as firma_name,
        coalesce({{ lead_engine_domain('t.company_domain') }},
                 {{ lead_engine_domain('fp.website_url') }},
                 case when h.collision_code = 'website' and h.firma_bk <> '-1' then lower(h.firma_bk) end) as domain,
        nullif(lower(replace(replace(replace(imp.fn, ' ', ''), '-', ''), 'fn', '')), '') as fn
    from {{ ref('hub_firma') }} h
    left join {{ ref('sat_firma__karriere') }} k   on k.hk_firma = h.hk_firma  and k.dss_is_current = 'Y'
    left join {{ ref('sat_firma__theirstack') }} t on t.hk_firma = h.hk_firma  and t.dss_is_current = 'Y'
    left join {{ ref('sat_firma__firmenprofil') }} fp on fp.hk_firma = h.hk_firma and fp.dss_is_current = 'Y'
    left join {{ ref('sat_firma__adzuna') }} ad    on ad.hk_firma = h.hk_firma and ad.dss_is_current = 'Y'
    left join {{ ref('sat_firma__website') }} wf   on wf.hk_firma = h.hk_firma and wf.dss_is_current = 'Y'
    left join {{ ref('sat_firma__impressum') }} imp on imp.hk_firma = h.hk_firma and imp.dss_is_current = 'Y'
    where h.firma_bk <> '-1'
),

n as (
    select f.*, {{ lead_engine_name_norm('f.firma_name') }} as name_norm
    from f
),

domain_fn as (
    select domain, min(fn) as fn
    from n
    where domain is not null and fn is not null
    group by domain
),

name_domain as (
    select name_norm, min(domain) as domain
    from n
    where domain is not null and name_norm <> ''
    group by name_norm
)

select
    n.hk_firma, n.collision_code, n.firma_bk, n.firma_name, n.domain, n.name_norm, coalesce(n.fn, df.fn) as fn,
    case when coalesce(n.fn, df.fn) is not null then 'fn:' + coalesce(n.fn, df.fn)
         when coalesce(n.domain, nd.domain) is not null then 'd:' + coalesce(n.domain, nd.domain)
         when n.name_norm <> '' then 'n:' + n.name_norm
         else n.collision_code + ':' + n.firma_bk end as master_firma_bk,
    case when n.fn is not null then 'fn'
         when df.fn is not null then 'domain>fn'
         when n.domain is not null then 'domain'
         when nd.domain is not null then 'name>domain'
         when n.name_norm <> '' then 'name'
         else 'keine' end as abgleich_regel
from n
left join name_domain nd on nd.name_norm = n.name_norm
left join domain_fn df on df.domain = n.domain
