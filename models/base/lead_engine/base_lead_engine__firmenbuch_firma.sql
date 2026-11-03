{#
    Sicht: base_lead_engine__firmenbuch_firma
    Nur sichere Zuordnungen (qualitaet = 'sicher') mit FN aus base_lead_engine__firmenbuch_zuordnung, ergaenzt um den juengsten Auszug der FN
    (base_lead_engine__firmenbuch_auszug: Anschrift, Homepage, EUID; fehlende Stammdaten der Zuordnung werden aus dem Auszug aufgefuellt).
    Eine Zeile je Firma und Ereignis (Lauf mit Zuordnung oder Auszug): so entsteht eine neue Satellitenzeile, wenn ein neuer Auszug etwas aendert.
    Unsichere und wahrscheinliche Zuordnungen bleiben in der Base-Tabelle (zur Pruefung), gehen aber nicht in den Vault.
#}
{{ config(materialized='view', post_hook=["EXEC sp_refreshview '{{ this.schema }}.{{ this.identifier }}'"]) }}
with z as (
    select * from {{ ref('base_lead_engine__firmenbuch_zuordnung') }}
    where qualitaet = 'sicher' and fn is not null
),

ev as (
    select firma_quelle, firma_bk, run_id, fetched_at from z
    union
    select zf.firma_quelle, zf.firma_bk, a.run_id, a.fetched_at
    from {{ ref('base_lead_engine__firmenbuch_auszug') }} a
    join (select distinct firma_quelle, firma_bk, fn from z) zf on zf.fn = a.fn
)

select
    ev.run_id, ev.fetched_at, ev.firma_quelle, ev.firma_bk, zz.fn,
    zz.qualitaet, zz.lead_name, zz.standort,
    coalesce(zz.firmenbuch_name, aa.firmenbuch_name)  as firmenbuch_name,
    coalesce(zz.sitz, aa.sitz)                        as sitz,
    coalesce(zz.rechtsform_code, aa.rechtsform_code)  as rechtsform_code,
    coalesce(zz.rechtsform, aa.rechtsform)            as rechtsform,
    coalesce(zz.gericht, aa.gericht)                  as gericht,
    zz.firmenbuch_status,
    aa.adresse_strasse, aa.adresse_plz, aa.adresse_ort, aa.adresse_staat, aa.homepage, aa.euid
from ev
cross apply (
    select top 1 z.* from z
    where z.firma_quelle = ev.firma_quelle and z.firma_bk = ev.firma_bk and z.run_id <= ev.run_id
    order by z.run_id desc
) zz
outer apply (
    select top 1 a.* from {{ ref('base_lead_engine__firmenbuch_auszug') }} a
    where a.fn = zz.fn and a.run_id <= ev.run_id
    order by a.run_id desc
) aa
