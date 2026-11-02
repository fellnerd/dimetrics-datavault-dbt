{#
    Referenz: ref_lead_engine__ort_name
    Ortsnamen -> Bundesland (und Bezirk) fuer den Abgleich von Ortsangaben ohne PLZ. Schluessel name_norm: klein, Ortschaft und
    Gemeinde sowie die Kurzform vor " am ", " im ", " bei ", " an der ", " in " ("klagenfurt am woerthersee" -> "klagenfurt").
    bundesland: das Bundesland mit mindestens 70 % der Eintraege des Namens, sonst NULL; bezirk nur bei eindeutigem Bezirk.
    Version: 2026-10-26 V1.0 Initialversion
#}
{{ config(materialized='table', as_columnstore=false, tags=['business_vault']) }}

with namen as (
    select ortschaft_norm as name_norm, bundesland, bezirk from {{ ref('ref_lead_engine__ort') }}
    union all
    select gemeinde_norm, bundesland, bezirk from {{ ref('ref_lead_engine__ort') }}
),
kurz as (
    select name_norm, bundesland, bezirk from namen
    union all
    select case when charindex(' am ', name_norm) > 1 then left(name_norm, charindex(' am ', name_norm) - 1)
                when charindex(' im ', name_norm) > 1 then left(name_norm, charindex(' im ', name_norm) - 1)
                when charindex(' bei ', name_norm) > 1 then left(name_norm, charindex(' bei ', name_norm) - 1)
                when charindex(' an der ', name_norm) > 1 then left(name_norm, charindex(' an der ', name_norm) - 1)
                when charindex(' in ', name_norm) > 1 then left(name_norm, charindex(' in ', name_norm) - 1) end,
           bundesland, bezirk
    from namen
),
bl as (
    select name_norm, bundesland, count(*) as n,
           sum(count(*)) over (partition by name_norm) as gesamt,
           row_number() over (partition by name_norm order by count(*) desc, bundesland) as rang
    from kurz
    where name_norm is not null and name_norm <> ''
    group by name_norm, bundesland
),
bz as (
    select name_norm, case when count(distinct bezirk) = 1 then max(bezirk) end as bezirk
    from kurz where name_norm is not null and name_norm <> '' group by name_norm
)
select b.name_norm,
       -- Mehrdeutige Namen: das Bundesland mit mindestens 70 % der Eintraege, sonst NULL
       case when b.n * 1.0 / b.gesamt >= 0.7 then b.bundesland end as bundesland,
       z.bezirk
from bl b
join bz z on z.name_norm = b.name_norm
where b.rang = 1
