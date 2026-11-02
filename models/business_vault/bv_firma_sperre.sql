{#
    Business Vault (virtuell): bv_firma_sperre
    Master-Firmen, die auf der Sperrliste stehen. Abgleich je Firma aus bv_firma_same_as ueber FN, Domain oder normalisierten Namen
    gegen ref_lead_engine__sperrliste; gesperrt gilt fuer den ganzen Master.
    Grain: 1 Zeile je master_firma_bk mit Treffer.
    Version: 2026-11-02 V1.0 Initialversion
#}
{{ config(materialized='view', tags=['business_vault']) }}

select f.master_firma_bk,
       min(s.grund)                                   as sperr_grund,
       min(coalesce(s.firma, s.domain, s.fn))         as sperr_eintrag
from {{ ref('bv_firma_same_as') }} f
join {{ ref('ref_lead_engine__sperrliste') }} s
  on (s.fn is not null and s.fn = f.fn)
  or (s.domain is not null and s.domain = f.domain)
  or (s.firma_norm <> '' and s.firma_norm = f.name_norm)
group by f.master_firma_bk
