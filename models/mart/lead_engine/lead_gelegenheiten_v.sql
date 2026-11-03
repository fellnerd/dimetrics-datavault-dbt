{#
    Mart (publizierte View): lead_gelegenheiten_v
    Grain: 1 Zeile je Gelegenheit (Cluster derselben Stelle aus mehreren Quellen; Repraesentant mit dem besten Text), veroeffentlicht oder
           zuletzt gesehen in den letzten 30 Tagen, ohne ausgeschlossene (Festanstellung ueber Vermittler). Zweck: Tagesliste der besten
           Gelegenheiten per MCP/Skill lesen.
    Duenne View: Tabelle lead_gelegenheiten (Tageslauf) + juengstes KI-Urteil live aus landing.lead_engine_ki_bewertung (Urteile von 06:30 sofort sichtbar).
    Schluessel: gelegenheit_id (erste Spalte, Schluessel zum Blaettern) und gelegenheit_key als varchar (das MCP-Blaettern scheitert an grossen bigint-Schluesseln).
    Bewertung: lead_typ, vorscore und alle Bausteine (p_*), begruendung_kurz, themen. Punkte aus ref_lead_engine__gewicht
               (Seed-Startwerte, ueberschrieben durch die Gewichte aus der Landing-Quelle suchprofil).
    Status: Lead-Status aus dem Suchprofil (juengster Eintrag zur gelegenheit_id); beworben/kontaktiert/kein Fit/erledigt und
            Sperrliste schliessen die Gelegenheit aus (bleibt mit Grund in bv_gelegenheit_score).
    KI-Urteil: ki_* (juengstes Urteil je gelegenheit_id).
    Quellen: lead_gelegenheiten, landing.lead_engine_ki_bewertung
    Version: 2026-10-26 V1.0 Erste Fassung
    Version: 2026-11-04 V1.1 Duenne View auf der Tabelle lead_gelegenheiten (MCP-Laufzeit)
#}
{{ config(materialized='view', tags=['report']) }}

with ki as (   -- juengstes KI-Urteil je Gelegenheit, live aus der Eingangstabelle (Index gelegenheit_id, bewertet_am desc)
    select x.*
    from (select k.*, row_number() over (partition by k.gelegenheit_id order by k.bewertet_am desc, k.bewertung_id desc) as rn
          from {{ source('lead_engine', 'lead_engine_ki_bewertung') }} k) x
    where x.rn = 1
)

select
    t.gelegenheit_id, t.gelegenheit_key,
    t.lead_typ, t.vorscore,
    t.p_thema, t.p_typ, t.p_region, t.p_frische, t.p_passung, t.p_bonus, t.p_abzug,
    t.begruendung_kurz, t.themen,
    t.titel, t.text, t.url,
    t.quellen,
    t.firma_name, t.ist_konzern,
    t.groesse, t.mitarbeiter, t.technologien,
    t.ort, t.ort_quelle, t.plz, t.bundesland, t.ist_remote, t.ist_hybrid,
    t.vertragsart, t.veroeffentlicht_am, t.datum_geschaetzt, t.tage_online, t.reaktionen,
    t.budget,
    t.status, t.status_am,
    ki.ki_einstufung, ki.ki_score, ki.ki_begruendung, ki.ki_anlass, ki.ki_naechster_schritt, ki.ki_baustein,
    ki.bewertet_am                                                               as ki_bewertet_am
from {{ ref('lead_gelegenheiten') }} t
left join ki on ki.gelegenheit_id = t.gelegenheit_id
