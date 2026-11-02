{#
    Sicht: base_lead_engine__firmenbuch_jahresabschluss_firma
    Jahresabschluss-Kennzahlen (base_lead_engine__firmenbuch_jahresabschluss) zugeordnet zu den Firmen der Lead-Engine ueber die FN:
    aus sicheren Firmenbuch-Zuordnungen und aus dem Impressum der Website (je firma_quelle/firma_bk die juengste Angabe).
    Je FN zaehlt nur der juengste Stichtag (bei Gleichstand der juengste Lauf): so erzeugt erst ein neuer Abschluss eine neue Satellitenzeile.
    Quelle fuer das Staging von sat_firma__jahresabschluss.
#}
{{ config(materialized='view', post_hook=["EXEC sp_refreshview '{{ this.schema }}.{{ this.identifier }}'"]) }}
select a.run_id, a.fetched_at, z.firma_quelle, z.firma_bk, a.fn,
       a.stichtag, a.eingereicht_am, a.groessenklasse_code, a.groessenklasse,
       a.bilanzsumme, a.umsatzerloese, a.eigenkapital, a.jahresergebnis, a.mitarbeiter_durchschnitt
from (
    select j.*, row_number() over (partition by j.fn order by j.stichtag desc, j.run_id desc) as rn
    from {{ ref('base_lead_engine__firmenbuch_jahresabschluss') }} j
    where j.bilanzsumme is not null or j.eigenkapital is not null   -- reine PDF-Abschluesse (alte Jahre) ohne Kennzahlen entfallen
) a
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
where a.rn = 1
