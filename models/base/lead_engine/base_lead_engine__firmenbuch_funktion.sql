{#
    Base-Tabelle (incremental, append): base_lead_engine__firmenbuch_funktion
    Quelle: landing.lead_engine_datei (source = 'firmenbuch', query_id = 'auszug'): Funktionen (FUN) mit den Personen (PER) des Auszugs.
    Grain: eine Zeile je Lauf (run_id), FN, Funktion (FKEN) und Personennummer (PNR, nur im Auszug eindeutig). Nur aufrechte Funktionen.
    Personen: Titel, Vor- und Nachname; bei juristischen Personen die Bezeichnung im Nachnamen (ist_person = 0).
    Nicht uebernommen: Geburtsdatum (PER/GEBURTSDATUM) und jede private Anschrift. seit = DATVON der Funktion.
    FUN und PER sind bei genau einem Eintrag ein Objekt, sonst ein Array.
    Version: 2026-11-03 V1.0 Initialversion
    Version: 2026-11-03 Vorfilter auf file_path vor dem JSON-Parsen (ohne neue Daten nur noch Pfad-Scan)
#}
{{ config(materialized='incremental', incremental_strategy='append', as_columnstore=false) }}

with neu as (   -- erst die neuen Dateien bestimmen (nur Pfade), dann parsen: TOP + ORDER BY verhindert, dass der Optimierer das JSON aller Dateien vorab liest
    select top (2147483647) f.file_path
    from {{ source('lead_engine', 'lead_engine_datei') }} f
    where f.source = 'firmenbuch' and f.query_id = 'auszug'
      {{ lead_engine_lauf_filter('f') }}
    order by f.file_path
),

f as (
    select
        f.run_id, f.fetched_at, f.file_path,
        {{ lead_engine_fn_norm("json_value(f.payload, '$.antwort.AUSZUG_V2_RESPONSE.FNR')") }}   as fn,
        json_query(f.payload, '$.antwort.AUSZUG_V2_RESPONSE.FUN') as fun_json,
        json_query(f.payload, '$.antwort.AUSZUG_V2_RESPONSE.PER') as per_json
    from neu n
    join {{ source('lead_engine', 'lead_engine_datei') }} f on f.file_path = n.file_path
),

c as (   -- Objekt bei genau einem Eintrag, sonst Array
    select f.run_id, f.fetched_at, f.file_path, f.fn,
           case when left(ltrim(f.fun_json), 1) = '[' then f.fun_json when f.fun_json is not null then concat('[', f.fun_json, ']') end as fun_arr,
           case when left(ltrim(f.per_json), 1) = '[' then f.per_json when f.per_json is not null then concat('[', f.per_json, ']') end as per_arr
    from f
    where f.fn is not null
),

e as (
    select c.run_id, c.fetched_at, c.file_path, c.fn,
           u.fken, u.fkentext, u.pnr, u.datvon, u.aufrecht,
           p.titelvor, p.titelnach, p.vorname, p.nachname, p.bezeichnung
    from c
    cross apply openjson(c.fun_arr) with (
        fken     nvarchar(20)  '$.FKEN',
        fkentext nvarchar(200) '$.FKENTEXT',
        pnr      nvarchar(20)  '$.PNR',
        datvon   nvarchar(20)  '$.FU_DKZ10.DATVON',
        aufrecht bit           '$.FU_DKZ10.AUFRECHT'
    ) u
    outer apply (
        select top 1 q.titelvor, q.titelnach, q.vorname, q.nachname, q.bezeichnung
        from openjson(c.per_arr) with (
            pnr        nvarchar(20)  '$.PNR',
            titelvor   nvarchar(100) '$.PE_DKZ02.TITELVOR',
            titelnach  nvarchar(100) '$.PE_DKZ02.TITELNACH',
            vorname    nvarchar(200) '$.PE_DKZ02.VORNAME',
            nachname   nvarchar(200) '$.PE_DKZ02.NACHNAME',
            bezeichnung nvarchar(500) '$.PE_DKZ02.BEZEICHNUNG'
        ) q
        where q.pnr = u.pnr
    ) p
    where u.fken is not null and u.pnr is not null
),

ranked as (
    select e.*, row_number() over (partition by e.run_id, e.fn, e.fken, e.pnr order by e.fetched_at desc, e.file_path) as rn
    from e
    where coalesce(e.aufrecht, 1) = 1
)

select
    r.run_id, r.fetched_at, r.fn, r.fken as funktion_code, r.fkentext as funktion, r.pnr,
    r.titelvor as titel, r.titelnach as titel_nach, r.vorname,
    coalesce(r.nachname, r.bezeichnung)                       as nachname,
    case when r.nachname is not null then 1 else 0 end         as ist_person,
    try_convert(date, r.datvon, 112)                           as seit
from ranked r
where r.rn = 1
