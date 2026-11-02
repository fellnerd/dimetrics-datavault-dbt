{{ config(severity='warn') }}
{#- Wächter für lead_gelegenheiten_v (Warnungen laut Plan Bewertung v2):
    - mehr als 30 % der Gelegenheiten ohne Bundesland
    - mehr als 20 % der Typen A und B ohne Text
    - keine Zeile aus dem heutigen Lauf (juengste Sichtung aelter als heute)
    Jede Zeile des Ergebnisses ist eine Warnung. -#}
with g as (select * from {{ ref('lead_gelegenheiten_v') }}),
s as (select max(letzte_sichtung) as letzte from {{ ref('bv_gelegenheit_score') }} where ausgeschlossen = 0)
select 'bundesland_fehlt_ueber_30_prozent' as warnung,
       cast(round(100.0 * sum(case when bundesland is null then 1 else 0 end) / nullif(count(*), 0), 1) as varchar(20)) as wert
from g
having 100.0 * sum(case when bundesland is null then 1 else 0 end) / nullif(count(*), 0) > 30
union all
select 'text_fehlt_ueber_20_prozent_bei_A_und_B',
       cast(round(100.0 * sum(case when text is null or text = '' then 1 else 0 end) / nullif(count(*), 0), 1) as varchar(20))
from g where lead_typ like 'A%' or lead_typ like 'B%'
having 100.0 * sum(case when text is null or text = '' then 1 else 0 end) / nullif(count(*), 0) > 20
union all
select 'keine_zeile_aus_dem_heutigen_lauf', cast(s.letzte as varchar(20)) from s where s.letzte < cast(getdate() as date)
