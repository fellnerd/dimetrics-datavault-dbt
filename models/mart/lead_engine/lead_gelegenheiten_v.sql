{#
    Mart (publizierte View): lead_gelegenheiten_v
    Grain: 1 Zeile je Gelegenheit (Cluster derselben Stelle ueber mehrere Quellen; Repraesentant mit dem besten Text), veroeffentlicht oder
           zuletzt gesehen in den letzten 30 Tagen, ohne ausgeschlossene (Festanstellung ueber Vermittler). Zweck: Tagesliste der besten
           Gelegenheiten per MCP/Skill lesen.
    Schluessel: gelegenheit_id (erste Spalte, Schluessel zum Blaettern) und gelegenheit_key als varchar (das MCP-Blaettern scheitert an grossen bigint-Schluesseln).
    Bewertung: lead_typ, vorscore und alle Bausteine (p_*), begruendung_kurz, themen. Punkte aus ref_lead_engine__gewicht
               (Seed-Startwerte, ueberschrieben durch die Gewichte aus der Landing-Quelle suchprofil).
    Status: Lead-Status aus dem Suchprofil (juengster Eintrag zur gelegenheit_id); beworben/kontaktiert/kein Fit/erledigt und
            Sperrliste schliessen die Gelegenheit aus (bleibt mit Grund in bv_gelegenheit_score).
    KI-Urteil: ki_* aus landing.lead_engine_ki_bewertung (juengstes Urteil je gelegenheit_id, live gelesen).
    Noch offen: Firmenbuch, Website-Detailtexte; Website-Stellen haben noch keinen Ort.
    Quellen: bv_gelegenheit_score
    Version: 2026-10-26 V1.0 Erste Fassung
#}
{{ config(materialized='view', tags=['report']) }}

with ki as (   -- juengstes KI-Urteil je Gelegenheit, live aus der Eingangstabelle (nicht materialisiert: Urteile von 06:30 sofort sichtbar)
    select x.*
    from (select k.*, row_number() over (partition by k.gelegenheit_id order by k.bewertet_am desc, k.bewertung_id desc) as rn
          from {{ source('lead_engine', 'lead_engine_ki_bewertung') }} k) x
    where x.rn = 1
)

select
    s.cluster_key                                                                as gelegenheit_id,
    cast(abs(convert(bigint, hashbytes('MD5', s.cluster_key))) as varchar(20))   as gelegenheit_key,
    s.lead_typ, s.vorscore,
    s.p_thema, s.p_typ, s.p_region, s.p_frische, s.p_passung, s.p_bonus, s.p_abzug,
    s.begruendung_kurz, s.themen,
    s.titel,
    left(s.text, 4000)                                                           as text,
    s.url,
    s.quellen_im_cluster                                                         as quellen,
    s.firma_name, s.ist_konzern,
    case when s.mitarbeiter is null then null
         when s.mitarbeiter < 20 then 'unter 20'
         when s.mitarbeiter <= 500 then '20-500'
         when s.mitarbeiter <= 2500 then '501-2500'
         else 'ueber 2500' end                                                   as groesse,
    s.mitarbeiter, s.technologien,
    s.ort, s.ort_quelle, s.plz, s.bundesland, s.ist_remote, s.ist_hybrid,
    s.vertragsart, s.veroeffentlicht_am, s.datum_geschaetzt, s.tage_online, s.reaktionen,
    s.budget_text                                                                as budget,
    s.status, s.status_am,
    ki.ki_einstufung, ki.ki_score, ki.ki_begruendung, ki.ki_anlass, ki.ki_naechster_schritt, ki.ki_baustein,
    ki.bewertet_am                                                               as ki_bewertet_am
from {{ ref('bv_gelegenheit_score') }} s
left join ki on ki.gelegenheit_id = s.cluster_key collate database_default
where s.ausgeschlossen = 0
  and (s.veroeffentlicht_am >= dateadd(day, -30, cast(getdate() as date))
       or s.letzte_sichtung >= dateadd(day, -30, cast(getdate() as date)))
