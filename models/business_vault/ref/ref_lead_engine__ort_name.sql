{#
    Referenz: ref_lead_engine__ort_name
    Ortsnamen -> Bundesland (und Bezirk) fuer den Abgleich von Ortsangaben ohne PLZ. Schluessel name_norm: klein, Ortschaft und
    Gemeinde sowie die Kurzform vor " am ", " im ", " bei ", " an der ", " in " ("klagenfurt am woerthersee" -> "klagenfurt").
    bundesland: das Bundesland mit mindestens 70 % der Eintraege des Namens, sonst NULL; bezirk nur bei eindeutigem Bezirk.
    Alias-Seed lead_engine_ort_alias: Schreibweisen, Regionen, Mehrfachangaben ('mehrere'), Remote-Angaben (ist_remote); gewinnt vor den Statistik-Austria-Namen.
    Version: 2026-10-26 V1.0 Initialversion
    Version: 2026-11-03 V1.1 Alias-Seed lead_engine_ort_alias, Spalte ist_remote
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
select name_norm, bundesland, bezirk, ist_remote
from (
    select a.name_norm, nullif(a.bundesland, '') as bundesland, cast(null as nvarchar(200)) as bezirk, cast(a.ist_remote as int) as ist_remote, 1 as prio
    from {{ ref('lead_engine_ort_alias') }} a
    union all
    select b.name_norm,
           -- Mehrdeutige Namen: das Bundesland mit mindestens 70 % der Eintraege, sonst NULL
           case when b.n * 1.0 / b.gesamt >= 0.7 then b.bundesland end as bundesland,
           z.bezirk, 0 as ist_remote, 2 as prio
    from bl b
    join bz z on z.name_norm = b.name_norm
    where b.rang = 1
) u
where u.prio = 1 or not exists (select 1 from {{ ref('lead_engine_ort_alias') }} a where a.name_norm = u.name_norm)
