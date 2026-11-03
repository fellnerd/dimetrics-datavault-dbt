{#
    Base-Tabelle (incremental, append): base_lead_engine__firmenbuch_jahresabschluss
    Quelle: landing.lead_engine_datei (source = 'firmenbuch', query_id = 'jahresabschluss'): Jahresabschluss einer Firma als XML (in JSON gewandelt, metadaten + inhalt_xml).
    Grain: eine Zeile je Lauf (run_id), FN (normalisiert) und Stichtag. Nur Kennzahlen; das Bilanz-XML (und der PDF-Anhang) wird nicht durchgereicht,
           ebenso keine Personen (Unterzeichner, aufstellende Personen).
    Layouts: modern (ALLGEMEINE_ANGABEN; Bilanz unter BILANZ bei mittleren/grossen Firmen, sonst unter ANLAGE1_/ANLAGE3_AUSZUG_AUS_DER_BILANZ) und
             alt (BILANZ_GLIEDERUNG/HGB_Form_2: Aktiva HGB_224_2, Eigenkapital HGB_224_3_A). Betraege BETRAG_GJ sind immer in Euro.
    Umsatzerloese und Jahresergebnis stehen nur in der Gewinn- und Verlustrechnung grosser/mittlerer Firmen (GUV_GKV), die durchschnittliche
    Mitarbeiterzahl nur im offenzulegenden Anhang (ANLAGE2); sonst NULL. groessenklasse_code = GKL der Metadaten (K klein, M mittel, G gross; W ungeklaert).
    Version: 2026-11-03 V1.0 Initialversion
    Version: 2026-11-03 Vorfilter auf file_path vor dem JSON-Parsen (ohne neue Daten nur noch Pfad-Scan)
#}
{{ config(materialized='incremental', incremental_strategy='append', as_columnstore=false) }}

with neu as (   -- erst die neuen Dateien bestimmen (nur Pfade), dann parsen: TOP + ORDER BY verhindert, dass der Optimierer das JSON aller Dateien vorab liest
    select top (2147483647) f.file_path
    from {{ source('lead_engine', 'lead_engine_datei') }} f
    where f.source = 'firmenbuch' and f.query_id = 'jahresabschluss'
      {{ lead_engine_lauf_filter('f') }}
    order by f.file_path
),

f as (
    select
        f.run_id, f.fetched_at, f.file_path,
        {{ lead_engine_fn_norm("json_value(f.payload, '$.metadaten.FNR')") }}                    as fn,
        try_cast(json_value(f.payload, '$.metadaten.STICHTAG') as date)                         as stichtag,
        try_cast(json_value(f.payload, '$.metadaten.EINGEREICHT') as date)                      as eingereicht_am,
        json_value(f.payload, '$.metadaten.GKL')                                                as groessenklasse_code,
        coalesce(json_value(f.payload, '$.inhalt_xml.BILANZ.AKTIVA.POSTENZEILE.BETRAG_GJ'),
                 json_value(f.payload, '$.inhalt_xml.ANLAGE1_AUSZUG_AUS_DER_BILANZ.AKTIVA.POSTENZEILE.BETRAG_GJ'),
                 json_value(f.payload, '$.inhalt_xml.ANLAGE3_AUSZUG_AUS_DER_BILANZ.AKTIVA.POSTENZEILE.BETRAG_GJ'),
                 json_value(f.payload, '$.inhalt_xml.BILANZ_GLIEDERUNG.HGB_Form_2.HGB_224_2.POSTENZEILE.BETRAG')) as bilanzsumme_roh,
        coalesce(json_value(f.payload, '$.inhalt_xml.BILANZ.PASSIVA.EIGENKAPITAL.POSTENZEILE.BETRAG_GJ'),
                 json_value(f.payload, '$.inhalt_xml.ANLAGE1_AUSZUG_AUS_DER_BILANZ.PASSIVA.EIGENKAPITAL.POSTENZEILE.BETRAG_GJ'),
                 json_value(f.payload, '$.inhalt_xml.ANLAGE3_AUSZUG_AUS_DER_BILANZ.PASSIVA.EIGENKAPITAL.POSTENZEILE.BETRAG_GJ'),
                 json_value(f.payload, '$.inhalt_xml.BILANZ_GLIEDERUNG.HGB_Form_2.HGB_224_3.HGB_224_3_A.POSTENZEILE.BETRAG')) as eigenkapital_roh,
        json_value(f.payload, '$.inhalt_xml.GUV_GKV.BILANZ_GEWINN_VERLUST.JAHRESUEBERSCHUSS_JAHRESFEHLBETRAG.ERGEBNIS_NACH_STEUERN.ERGEBNIS_VOR_STEUERN.ZWISCHENSUMME_BETRIEBSERFOLG.UMSATZERLOESE.POSTENZEILE.BETRAG_GJ') as umsatz_roh,
        json_value(f.payload, '$.inhalt_xml.GUV_GKV.BILANZ_GEWINN_VERLUST.JAHRESUEBERSCHUSS_JAHRESFEHLBETRAG.POSTENZEILE.BETRAG_GJ') as ergebnis_roh,
        json_value(f.payload, '$.inhalt_xml.ANLAGE2_OFFENZULEGENDER_ANHANG.DURCHSCHNITTLICHE_ANZAHL_ARBEITNEHMER.ANZAHL') as mitarbeiter_roh
    from neu n
    join {{ source('lead_engine', 'lead_engine_datei') }} f on f.file_path = n.file_path
),

ranked as (
    select f.*, row_number() over (partition by f.run_id, f.fn, f.stichtag order by f.fetched_at desc, f.file_path) as rn
    from f
    where f.fn is not null and f.stichtag is not null
)

select
    r.run_id, r.fetched_at, r.fn, r.stichtag, r.eingereicht_am, r.groessenklasse_code,
    case r.groessenklasse_code when 'K' then 'klein' when 'M' then 'mittel' when 'G' then 'gross' else 'unbekannt' end as groessenklasse,
    try_cast(r.bilanzsumme_roh as decimal(19, 2))                      as bilanzsumme,
    try_cast(r.umsatz_roh as decimal(19, 2))                           as umsatzerloese,
    try_cast(r.eigenkapital_roh as decimal(19, 2))                     as eigenkapital,
    try_cast(r.ergebnis_roh as decimal(19, 2))                         as jahresergebnis,
    try_cast(r.mitarbeiter_roh as decimal(10, 1))                      as mitarbeiter_durchschnitt
from ranked r
where r.rn = 1
