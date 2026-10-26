{#
    Base-Tabelle (incremental, append): base_lead_engine__freelancer_auftrag
    Quelle: landing.lead_engine_datei (source = 'freelancer', query_id = 'details')
    Grain: eine Zeile je Lauf (run_id) und Auftrags-ID (Detaildatei)
    Payload: $ (titel, beschreibung, kategorie_pfad, kategorie_slug, felder.*, anzahl_reaktionen)
    Die Auftrags-ID steht im Payload ($.auftrags_id), ersatzweise in query_params.
    Version: 2026-10-26 V1.0 Initialversion
    Version: 2026-10-26 V1.1 profil_ids aus profil_treffer der Detaildatei
#}
{{ config(materialized='incremental', incremental_strategy='append', as_columnstore=false) }}

with items as (
    select
        f.run_id, f.query_id, f.fetched_at, f.file_path, f.profil_treffer,
        coalesce(j.auftrags_id, json_value(f.query_params, '$.auftrags_id')) as auftrags_id,
        j.titel, j.url,
        j.beschreibung,   -- OPENJSON statt JSON_VALUE: JSON_VALUE liefert bei Texten ueber 4000 Zeichen NULL
        j.kategorie_pfad_json, j.kategorie_slug, j.budget, j.veroeffentlicht, j.ort,
        j.zuletzt_geaendert, j.status, j.anzahl_reaktionen
    from {{ source('lead_engine', 'lead_engine_datei') }} f
    cross apply openjson(f.payload) with (
        auftrags_id          nvarchar(40)   '$.auftrags_id',
        titel                nvarchar(500)  '$.titel',
        url                  nvarchar(1000) '$.url',
        beschreibung         nvarchar(max)  '$.beschreibung',
        kategorie_pfad_json  nvarchar(max)  '$.kategorie_pfad' as json,
        kategorie_slug       nvarchar(255)  '$.kategorie_slug',
        budget               nvarchar(200)  '$.felder.Budget',
        veroeffentlicht      nvarchar(50)   '$.felder."Veröffentlicht"',
        ort                  nvarchar(255)  '$.felder.Ort',
        zuletzt_geaendert    nvarchar(50)   '$.felder."Zuletzt geändert"',
        status               nvarchar(100)  '$.felder.Status',
        anzahl_reaktionen    int            '$.anzahl_reaktionen'
    ) j
    where f.source = 'freelancer'
      and f.query_id = 'details'
      -- nur abgeschlossene Laeufe: neueste Datei des Laufs (alle Quellen) ist mindestens 30 Minuten alt.
      and f.run_id in (select run_id from {{ source('lead_engine', 'lead_engine_datei') }}
                       group by run_id
                       having max(fetched_at) < dateadd(minute, -{{ var('lead_engine_ruhezeit_minuten', 30) }}, sysdatetimeoffset()))
      {% if is_incremental() %}
      and f.run_id > coalesce((select max(run_id) from {{ this }}), '')
      {% endif %}
),

ranked as (
    select i.*,
           row_number() over (partition by i.run_id, i.auftrags_id order by i.fetched_at desc, i.file_path) as rn
    from items i
    where i.auftrags_id is not null
)

select
    r.run_id,
    r.fetched_at,
    r.auftrags_id,
    r.titel, r.url, r.beschreibung,
    (select string_agg(p.[value], ' > ') within group (order by try_cast(p.[key] as int))
       from openjson(r.kategorie_pfad_json) p)                                  as kategorie_pfad,
    r.kategorie_slug, r.budget, r.ort, r.status,
    r.veroeffentlicht, r.zuletzt_geaendert,
    r.anzahl_reaktionen,
    -- Profile der Detaildatei: profil_treffer ist {"<auftrags_id>": ["<profil>", ...]}, Join ueber den OPENJSON-Schluessel
    (select string_agg(v.[value], ',') within group (order by v.[value])
       from (select distinct pv.[value]
               from openjson(case when isjson(r.profil_treffer) = 1 then r.profil_treffer else '{}' end) t
               cross apply openjson(t.[value]) pv
              where t.[key] collate database_default = r.auftrags_id) v)                                       as profil_ids,
    {{ lead_engine_freelancer_datum('r.veroeffentlicht', 'r.fetched_at') }}      as veroeffentlicht_am,
    {{ lead_engine_freelancer_datum('r.zuletzt_geaendert', 'r.fetched_at') }}    as zuletzt_geaendert_am
from ranked r
where r.rn = 1
