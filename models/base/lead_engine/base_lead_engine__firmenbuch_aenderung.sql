{#
    Base-Tabelle (incremental, append): base_lead_engine__firmenbuch_aenderung
    Quelle: landing.lead_engine_datei (source = 'firmenbuch', query_id = 'aenderungen'): Veraenderungen im Firmenbuch fuer einen Zeitraum (von-bis),
            alle Firmen Oesterreichs (FNR, VNR, VOLLZUGSDATUM, ARTDERVERAENDERUNG: Aenderung | Neueintragung | Loeschung)
    Grain: eine Zeile je Lauf (run_id), Zeitraum und FN (normalisiert, ohne fuehrende Nullen); nur Ereignistyp und Datum, aggregiert.
    Die Zuordnung zu Firmen der Lead-Engine erfolgt erst im Staging (base_lead_engine__firmenbuch_ereignis).
    Version: 2026-11-02 V1.0 Initialversion
    Version: 2026-11-03 Vorfilter auf file_path vor dem JSON-Parsen (ohne neue Daten nur noch Pfad-Scan)
#}
{{ config(materialized='incremental', incremental_strategy='append', as_columnstore=false) }}

with neu as (   -- erst die neuen Dateien bestimmen (nur Pfade), dann parsen: TOP + ORDER BY verhindert, dass der Optimierer das JSON aller Dateien vorab liest
    select top (2147483647) f.file_path
    from {{ source('lead_engine', 'lead_engine_datei') }} f
    where f.source = 'firmenbuch' and f.query_id = 'aenderungen'
      {{ lead_engine_lauf_filter('f') }}
    order by f.file_path
),

ev as (
    select
        f.run_id, f.fetched_at,
        json_value(f.payload, '$.antwort.VERAENDERUNGENFIRMARESPONSE.VON') as zeitraum_von,
        json_value(f.payload, '$.antwort.VERAENDERUNGENFIRMARESPONSE.BIS') as zeitraum_bis,
        {{ lead_engine_fn_norm('v.fnr') }}                                 as fn,
        v.vollzug, v.art
    from neu n
    join {{ source('lead_engine', 'lead_engine_datei') }} f on f.file_path = n.file_path
    cross apply openjson(f.payload, '$.antwort.VERAENDERUNGENFIRMARESPONSE.VERAENDERUNG') with (
        fnr    nvarchar(30)  '$.FNR',
        vollzug nvarchar(30) '$.VOLLZUGSDATUM',
        art    nvarchar(60)  '$.ARTDERVERAENDERUNG'
    ) v
),

letzte as (
    select e.*, row_number() over (partition by e.run_id, e.zeitraum_von, e.zeitraum_bis, e.fn order by e.vollzug desc, e.art) as rn
    from ev e
    where e.fn is not null
)

select
    l.run_id, max(l.fetched_at) as fetched_at, l.zeitraum_von, l.zeitraum_bis, l.fn,
    count(*)                                                   as anzahl_veraenderungen,
    try_cast(max(l.vollzug) as date)                           as letzte_veraenderung_am,
    max(case when l.rn = 1 then l.art end)                     as letzte_art,
    string_agg(l.art, ', ') within group (order by l.art)      as arten
from letzte l
group by l.run_id, l.zeitraum_von, l.zeitraum_bis, l.fn
