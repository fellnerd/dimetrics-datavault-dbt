{#
    Mart (publizierte View): lead_kandidaten_v
    Grain: 1 Zeile je Firma (firma_key) mit Sichtung in den letzten 60 Tagen. Zweck: Bewertung von Lead-Kandidaten
           (z. B. per MCP/Skill) ohne die Sichtungen seitenweise lesen und selbst mit Firma, Stelle und Quelle verbinden zu muessen.
    Filter: nur Firmen mit bekannter Firma (firma_key <> -1), Sichtungen mit Suchprofil-Treffer (profil_id <> 'ohne-treffer'),
            Vermittler (dim_firma.ist_vermittler = 1) ausgeschlossen. Vermittler markiert nur TheirStack.
    Firma: dim_firma ist je Quelle getrennt (karriere, theirstack, website ueber ID, adzuna ueber Namen). Dieselbe Firma aus
           mehreren Quellen erscheint daher mehrfach, bis ein Same-as-Link im Business Vault existiert.
    Offen: ist_gesperrt (Sperrliste, kommt aus dem Suchprofil), Firmenbuch-Felder (Mitarbeiter, Umsatz, Rechtsform).
    Frische: View, wird bei jeder Abfrage gegen die Mart-Tabellen berechnet (Zeitfenster relativ zu heute).
    Quellen: fakt_stelle_sichtung, dim_stelle, dim_firma, dim_quelle
#}
{{ config(materialized='view', tags=['report']) }}

with s as (
    select fs.firma_key, fs.stelle_key, fs.quelle_key, fs.profil_id,
           convert(date, convert(char(8), fs.datum_key)) as datum
    from {{ ref('fakt_stelle_sichtung') }} fs
    where fs.firma_key <> -1
      and fs.profil_id <> 'ohne-treffer'
      and fs.datum_key >= convert(int, format(dateadd(day, -60, getdate()), 'yyyyMMdd'))
),

je_stelle as (
    select firma_key, stelle_key, min(datum) as erste, max(datum) as letzte
    from s
    group by firma_key, stelle_key
),

agg as (
    select firma_key,
           count(distinct stelle_key) as anzahl_stellen_60t,
           count(distinct case when datum >= dateadd(day, -30, cast(getdate() as date))
                               then stelle_key end) as anzahl_stellen_30t,
           count(distinct quelle_key) as anzahl_quellen,
           min(datum) as erste_sichtung,
           max(datum) as letzte_sichtung
    from s
    group by firma_key
),

quellen as (
    select firma_key, string_agg(quelle_code, ', ') as quellen
    from (select distinct s.firma_key, q.quelle_code
          from s join {{ ref('dim_quelle') }} q on q.quelle_key = s.quelle_key) x
    group by firma_key
),

profile as (
    select firma_key, string_agg(profil_id, ', ') as profile
    from (select distinct firma_key, profil_id from s) x
    group by firma_key
),

titel as (
    select js.firma_key,
           left(string_agg(cast(ds.stelle_name + ' [' + ds.quelle_code + ', '
                   + convert(char(10), js.erste, 23) + ']' as nvarchar(max)), ' | ')
                within group (order by js.erste desc), 3000) as stellen
    from je_stelle js
    join {{ ref('dim_stelle') }} ds on ds.stelle_key = js.stelle_key
    group by js.firma_key
)

select f.firma_key, f.firma_name, f.domain, f.website, f.hauptsitz, f.branche,
       f.groesse_klasse, f.mitarbeiter_anzahl,
       a.anzahl_stellen_30t, a.anzahl_stellen_60t, a.anzahl_quellen,
       q.quellen, p.profile, a.erste_sichtung, a.letzte_sichtung,
       t.stellen
from agg a
join {{ ref('dim_firma') }} f on f.firma_key = a.firma_key
left join quellen q on q.firma_key = a.firma_key
left join profile p on p.firma_key = a.firma_key
left join titel   t on t.firma_key = a.firma_key
where coalesce(f.ist_vermittler, 0) = 0
