{#
    Base-Tabelle (incremental, append): base_lead_engine__firmenbuch_zuordnung
    Quelle: landing.lead_engine_datei (source = 'firmenbuch', query_id = 'zuordnen', Datei suche__<quelle>-<id>)
    Grain: eine Zeile je Lauf (run_id) und Firma der Lead-Engine (firmen_key = '<quelle>:<id>', z. B. karriere:3571)
    zuordnung: Bewertung des Collectors (qualitaet sicher | wahrscheinlich | unsicher | kein_treffer) mit der gewaehlten FN;
               Firmenbuch-Stammdaten (Name, Sitz, Rechtsform, Gericht, Status) aus dem Kandidaten der Antwort mit dieser FN.
    FN normalisiert (Macro lead_engine_fn_norm, ohne fuehrende Nullen). Ins Staging kommen nur sichere Zuordnungen (Sicht _firma).
    Version: 2026-11-02 V1.0 Initialversion
    Version: 2026-11-03 Vorfilter auf file_path vor dem JSON-Parsen (ohne neue Daten nur noch Pfad-Scan)
#}
{{ config(materialized='incremental', incremental_strategy='append', as_columnstore=false) }}

with neu as (   -- erst die neuen Dateien bestimmen (nur Pfade), dann parsen: TOP + ORDER BY verhindert, dass der Optimierer das JSON aller Dateien vorab liest
    select top (2147483647) f.file_path
    from {{ source('lead_engine', 'lead_engine_datei') }} f
    where f.source = 'firmenbuch' and f.query_id = 'zuordnen'
      {{ lead_engine_lauf_filter('f') }}
    order by f.file_path
),

f as (
    select
        f.run_id, f.fetched_at, f.file_path,
        z.firmen_key, z.name as lead_name, z.standort, z.qualitaet, z.fnr,
        json_query(f.payload, '$.antwort.SUCHEFIRMARESPONSE.ERGEBNIS') as erg
    from neu n
    join {{ source('lead_engine', 'lead_engine_datei') }} f on f.file_path = n.file_path
    cross apply openjson(f.payload, '$.zuordnung') with (
        firmen_key nvarchar(100) '$.firmen_key',
        name       nvarchar(500) '$.name',
        standort   nvarchar(255) '$.standort',
        qualitaet  nvarchar(30)  '$.qualitaet',
        fnr        nvarchar(30)  '$.fnr'
    ) z
),

c as (   -- ERGEBNIS ist bei genau einem Treffer ein Objekt, sonst ein Array
    select f.*,
           case when left(ltrim(f.erg), 1) = '[' then f.erg
                when f.erg is not null then concat('[', f.erg, ']') end as erg_arr
    from f
),

ranked as (
    select c.*,
           row_number() over (partition by c.run_id, c.firmen_key order by c.fetched_at desc, c.file_path) as rn
    from c
    where c.firmen_key is not null
)

select
    r.run_id, r.fetched_at,
    left(r.firmen_key, charindex(':', r.firmen_key + ':') - 1)                       as firma_quelle,
    substring(r.firmen_key, charindex(':', r.firmen_key + ':') + 1, 100)              as firma_bk,
    {{ lead_engine_fn_norm('r.fnr') }}                                                as fn,
    r.qualitaet, r.lead_name, r.standort,
    coalesce(k.name_text, (select string_agg(x.[value], ' ') from openjson(k.name_json) x)) as firmenbuch_name,
    k.sitz, k.rf_code as rechtsform_code, k.rf_text as rechtsform, k.gericht,
    k.status as firmenbuch_status
from ranked r
outer apply (
    select top 1 e.*
    from openjson(r.erg_arr) with (
        fnr       nvarchar(30)   '$.FNR',
        name_text nvarchar(500)  '$.NAME',
        name_json nvarchar(max)  '$.NAME' as json,
        sitz      nvarchar(255)  '$.SITZ',
        rf_code   nvarchar(20)   '$.RECHTSFORM.CODE',
        rf_text   nvarchar(255)  '$.RECHTSFORM.TEXT',
        gericht   nvarchar(255)  '$.GERICHT.TEXT',
        status    nvarchar(100)  '$.STATUS'
    ) e
    where {{ lead_engine_fn_norm('e.fnr') }} = {{ lead_engine_fn_norm('r.fnr') }}
) k
where r.rn = 1
