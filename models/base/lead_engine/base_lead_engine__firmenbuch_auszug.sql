{#
    Base-Tabelle (incremental, append): base_lead_engine__firmenbuch_auszug
    Quelle: landing.lead_engine_datei (source = 'firmenbuch', query_id = 'auszug'): Auszug aus dem Firmenbuch (AUSZUG_V2, UMFANG Kurzinformation) je FN.
    Grain: eine Zeile je Lauf (run_id) und FN (normalisiert, ohne fuehrende Nullen).
    Uebernommen: Firmenname (FI_DKZ02), Geschaeftsanschrift (FI_DKZ03: Strasse, Hausnummer, PLZ, Ort, Staat), Sitz (FI_DKZ06), Rechtsform (FI_DKZ07),
                 Gericht (FI_DKZ09), Homepage (FI_DKZ25), EUID der Hauptfirma (ZNR 000). Funktionen: base_lead_engine__firmenbuch_funktion.
    Nicht uebernommen: Geburtsdaten der Personen (PER/GEBURTSDATUM), Zweigniederlassungen (ZWL), Vollzuege, Unternehmensgegenstand.
    Version: 2026-11-03 V1.0 Initialversion
#}
{{ config(materialized='incremental', incremental_strategy='append', as_columnstore=false) }}

with f as (
    select
        f.run_id, f.fetched_at, f.file_path,
        {{ lead_engine_fn_norm("json_value(f.payload, '$.antwort.AUSZUG_V2_RESPONSE.FNR')") }}    as fn,
        try_cast(json_value(f.payload, '$.antwort.AUSZUG_V2_RESPONSE.STICHTAG') as date)         as stichtag,
        json_value(f.payload, '$.antwort.AUSZUG_V2_RESPONSE.FIRMA.FI_DKZ02.BEZEICHNUNG')          as name_text,
        json_query(f.payload, '$.antwort.AUSZUG_V2_RESPONSE.FIRMA.FI_DKZ02.BEZEICHNUNG')          as name_json,
        json_value(f.payload, '$.antwort.AUSZUG_V2_RESPONSE.FIRMA.FI_DKZ03.STRASSE')              as strasse,
        json_value(f.payload, '$.antwort.AUSZUG_V2_RESPONSE.FIRMA.FI_DKZ03.HAUSNUMMER')           as hausnummer,
        json_value(f.payload, '$.antwort.AUSZUG_V2_RESPONSE.FIRMA.FI_DKZ03.PLZ')                  as plz,
        json_value(f.payload, '$.antwort.AUSZUG_V2_RESPONSE.FIRMA.FI_DKZ03.ORT')                  as ort,
        json_value(f.payload, '$.antwort.AUSZUG_V2_RESPONSE.FIRMA.FI_DKZ03.STAAT')                as staat,
        json_value(f.payload, '$.antwort.AUSZUG_V2_RESPONSE.FIRMA.FI_DKZ06.SITZ')                 as sitz,
        json_value(f.payload, '$.antwort.AUSZUG_V2_RESPONSE.FIRMA.FI_DKZ07.RECHTSFORM.CODE')      as rechtsform_code,
        json_value(f.payload, '$.antwort.AUSZUG_V2_RESPONSE.FIRMA.FI_DKZ07.RECHTSFORM.TEXT')      as rechtsform,
        json_value(f.payload, '$.antwort.AUSZUG_V2_RESPONSE.FIRMA.FI_DKZ09.HGALT.TEXT')           as gericht,
        json_value(f.payload, '$.antwort.AUSZUG_V2_RESPONSE.FIRMA.FI_DKZ25.HOMEPAGE')             as homepage,
        json_query(f.payload, '$.antwort.AUSZUG_V2_RESPONSE.EUID')                                as euid_json
    from {{ source('lead_engine', 'lead_engine_datei') }} f
    where f.source = 'firmenbuch' and f.query_id = 'auszug'
      {{ lead_engine_lauf_filter('f') }}
),

ranked as (
    select f.*, row_number() over (partition by f.run_id, f.fn order by f.fetched_at desc, f.file_path) as rn
    from f
    where f.fn is not null
)

select
    r.run_id, r.fetched_at, r.fn, r.stichtag,
    coalesce(r.name_text, (select string_agg(x.[value], ' ') from openjson(r.name_json) x))      as firmenbuch_name,
    nullif(ltrim(rtrim(concat_ws(' ', r.strasse, r.hausnummer))), '')                              as adresse_strasse,
    r.plz                                                                                          as adresse_plz,
    r.ort                                                                                          as adresse_ort,
    r.staat                                                                                        as adresse_staat,
    r.sitz, r.rechtsform_code, r.rechtsform, r.gericht,
    r.homepage,
    (select top 1 e.euid
     from openjson(case when left(ltrim(r.euid_json), 1) = '[' then r.euid_json when r.euid_json is not null then concat('[', r.euid_json, ']') end)
          with (znr nvarchar(10) '$.ZNR', euid nvarchar(60) '$.EUID') e
     order by case when e.znr = '000' then 0 else 1 end, e.znr)                                    as euid
from ranked r
where r.rn = 1
