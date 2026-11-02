{#
    Sicht: base_lead_engine__firmenbuch_ereignis
    Veraenderungen im Firmenbuch (base_lead_engine__firmenbuch_aenderung) zugeordnet zu den Firmen der Lead-Engine ueber die FN:
    aus sicheren Firmenbuch-Zuordnungen und aus dem Impressum der Website (je firma_quelle/firma_bk die juengste Angabe).
    Quelle fuer das Staging des Signal-Satelliten.
#}
{{ config(materialized='view', post_hook=["EXEC sp_refreshview '{{ this.schema }}.{{ this.identifier }}'"]) }}
select a.run_id, a.fetched_at, z.firma_quelle, z.firma_bk, a.fn,
       a.zeitraum_von, a.zeitraum_bis, a.anzahl_veraenderungen, a.letzte_veraenderung_am, a.letzte_art, a.arten
from {{ ref('base_lead_engine__firmenbuch_aenderung') }} a
join (
    select firma_quelle, firma_bk, fn,
           row_number() over (partition by firma_quelle, firma_bk, fn order by prio, run_id desc) as rn
    from (
        select firma_quelle, firma_bk, fn, 1 as prio, run_id from {{ ref('base_lead_engine__firmenbuch_firma') }}
        union all
        select firma_quelle, firma_bk, {{ lead_engine_fn_norm('fn') }} as fn, 2 as prio, run_id from {{ ref('base_lead_engine__website_firma') }}
        where fn is not null
    ) m
    where fn is not null
) z on z.fn = a.fn and z.rn = 1
