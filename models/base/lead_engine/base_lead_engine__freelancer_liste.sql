{#
    Base-Tabelle (incremental, append): base_lead_engine__freelancer_liste
    Quelle: landing.lead_engine_datei (source = 'freelancer', query_id = 'liste')
    Grain: eine Zeile je Lauf (run_id) und Auftrags-ID
    Payload: $.items[*] (auftrags_id, url, titel, beschreibung_kurz, felder.*)
    Profile: profil_treffer ist JSON {"<auftrags_id>": ["<profil>", ...]} je Datei -> profil_ids
    Datumsangaben ohne Jahr: Jahr aus fetched_at (Macro lead_engine_freelancer_datum); Budget bleibt Rohtext.
    Version: 2026-10-26 V1.0 Initialversion
#}
{{ config(materialized='incremental', incremental_strategy='append', as_columnstore=false) }}

with items as (
    select
        f.run_id, f.query_id, f.fetched_at, f.file_path, f.profil_treffer,
        j.*
    from {{ source('lead_engine', 'lead_engine_datei') }} f
    cross apply openjson(f.payload, '$.items') with (
        auftrags_id        nvarchar(40)   '$.auftrags_id',
        url                nvarchar(1000) '$.url',
        titel              nvarchar(500)  '$.titel',
        beschreibung_kurz  nvarchar(max)  '$.beschreibung_kurz',
        budget             nvarchar(200)  '$.felder.Budget',
        platziert          nvarchar(50)   '$.felder.Platziert',
        antworten          nvarchar(20)   '$.felder.Antworten',
        ort                nvarchar(255)  '$.felder.Ort',
        zuletzt_geaendert  nvarchar(50)   '$.felder."Zuletzt geändert"',
        status             nvarchar(100)  '$.felder.Status'
    ) j
    where f.source = 'freelancer'
      and f.query_id = 'liste'
      -- nur abgeschlossene Laeufe: neueste Datei des Laufs (alle Quellen) ist mindestens 30 Minuten alt.
      -- (Das Laufprotokoll taugt nicht: seit Collector 0.3.0/Dagster hat es eine andere run_id als die Dateien.)
      and f.run_id in (select run_id from {{ source('lead_engine', 'lead_engine_datei') }}
                       group by run_id
                       having max(fetched_at) < dateadd(minute, -{{ var('lead_engine_ruhezeit_minuten', 30) }}, sysdatetimeoffset()))
      {% if is_incremental() %}
      and f.run_id > coalesce((select max(run_id) from {{ this }}), '')
      {% endif %}
),

queries as (
    select run_id, auftrags_id,
           string_agg(query_id, ',') within group (order by query_id) as query_ids
    from (select distinct run_id, auftrags_id, query_id from items) d
    group by run_id, auftrags_id
),

treffer as (   -- Profile je Lauf und Auftrag aus dem JSON-Objekt profil_treffer
    select run_id, auftrags_id,
           string_agg(profil_id, ',') within group (order by profil_id) as profil_ids
    from (
        select distinct i.run_id, t.[key] as auftrags_id, p.[value] as profil_id
        from (select distinct run_id, file_path, profil_treffer from items) i
        cross apply openjson(i.profil_treffer) t
        cross apply openjson(t.[value]) p
        where isjson(i.profil_treffer) = 1
    ) d
    group by run_id, auftrags_id
),

ranked as (
    select i.*,
           row_number() over (partition by i.run_id, i.auftrags_id order by i.fetched_at, i.file_path) as rn
    from items i
)

select
    r.run_id,
    r.fetched_at,
    r.auftrags_id,
    r.titel, r.url, r.beschreibung_kurz, r.budget, r.ort, r.status,
    r.platziert, r.zuletzt_geaendert,
    try_cast(r.antworten as int) as antworten,
    {{ lead_engine_freelancer_datum('r.platziert', 'r.fetched_at') }}         as platziert_am,
    {{ lead_engine_freelancer_datum('r.zuletzt_geaendert', 'r.fetched_at') }} as zuletzt_geaendert_am,
    q.query_ids,
    t.profil_ids
from ranked r
join queries q on q.run_id = r.run_id and q.auftrags_id = r.auftrags_id
left join treffer t on t.run_id = r.run_id and t.auftrags_id = r.auftrags_id
where r.rn = 1
