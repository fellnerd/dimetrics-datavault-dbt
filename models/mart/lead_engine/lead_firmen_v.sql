{#
    Mart (publizierte View): lead_firmen_v
    Grain: 1 Zeile je Master-Firma (master_firma_bk aus bv_firma_same_as) mit mindestens einer Gelegenheit in den letzten 30 Tagen
           (veroeffentlicht oder zuletzt gesehen, nicht ausgeschlossen). Gelegenheiten ohne bekannte Firma (z. B. freelancer.at, TED)
           erscheinen nur in lead_gelegenheiten_v.
    Zweck: Firmenblick auf die Gelegenheiten: bester Vorscore, Zahl der Gelegenheiten (ab Vorscore 40), Themen, Region, Groesse, Konzern,
           Technologien. Ersetzt nach Umstellung des Skills lead_kandidaten_v.
    Duenne View: Tabelle lead_firmen (Tageslauf) + KI-Kennzahlen live aus landing.lead_engine_ki_bewertung (juengstes Urteil je Gelegenheit).
    Schluessel: firma_id (varchar, Hash des Masters) statt bigint (das MCP-Blaettern scheitert an grossen bigint-Schluesseln).
    Firmenbuch: fn, rechtsform, firmenbuch_sitz und firmenbuch_ereignisse (juengste Veraenderung im Firmenbuch) aus sat_firma__firmenbuch(_ereignis).
    Funktionstraeger: geschaeftsfuehrung (GF, Vorstand, Geschaeftsleiter, Komplementaere mit Funktion und seit) und anzahl_prokuristen aus sat_firma__firmenbuch_funktion.
    Jahresabschluss: groessenklasse, abschluss_stichtag, bilanzsumme, umsatzerloese, eigenkapital, jahresergebnis, mitarbeiter_abschluss (nur Kennzahlen; Umsatz,
    Ergebnis und Mitarbeiter nur wenn offengelegt) aus sat_firma__jahresabschluss.
    Quellen: lead_firmen, lead_gelegenheiten, landing.lead_engine_ki_bewertung
    Version: 2026-11-02 V1.0 Erste Fassung
    Version: 2026-11-04 V1.1 Duenne View auf der Tabelle lead_firmen (MCP-Laufzeit)
#}
{{ config(materialized='view', tags=['report']) }}

with ki_firma as (   -- KI-Urteile der Gelegenheiten der Firma (juengstes Urteil je Gelegenheit), ausgehend von der kleinen Eingangstabelle
    select g.firma_id, min(k.ki_einstufung) as ki_einstufung_beste, sum(case when k.ki_einstufung = 'A' then 1 else 0 end) as ki_anzahl_a
    from (select x.gelegenheit_id, x.ki_einstufung
          from (select k0.*, row_number() over (partition by k0.gelegenheit_id order by k0.bewertet_am desc, k0.bewertung_id desc) as rn
                from {{ source('lead_engine', 'lead_engine_ki_bewertung') }} k0) x
          where x.rn = 1) k
    join {{ ref('lead_gelegenheiten') }} g on g.gelegenheit_id = k.gelegenheit_id
    where g.firma_id is not null
    group by g.firma_id
)

select
    f.firma_id, f.master_firma_bk, f.firma_name,
    f.bester_vorscore, f.bester_lead_typ,
    f.anzahl_gelegenheiten, f.anzahl_ab_40,
    f.themen,
    f.regionen, f.region_beste,
    f.groesse, f.mitarbeiter, f.ist_konzern, f.ist_vermittler,
    f.branche, f.technologien,
    f.fn, f.rechtsform, f.firmenbuch_sitz,
    f.geschaeftsfuehrung, f.anzahl_prokuristen,
    f.groessenklasse, f.abschluss_stichtag,
    f.bilanzsumme, f.umsatzerloese, f.eigenkapital, f.jahresergebnis,
    f.mitarbeiter_abschluss,
    f.quellen,
    f.erste_sichtung, f.letzte_sichtung,
    f.beste_gelegenheiten,
    f.firmenbuch_ereignisse,
    kf.ki_einstufung_beste, coalesce(kf.ki_anzahl_a, 0)                             as ki_anzahl_a,
    f.status, f.status_am
from {{ ref('lead_firmen') }} f
left join ki_firma kf on kf.firma_id = f.firma_id
