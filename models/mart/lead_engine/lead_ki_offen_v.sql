{#
    Mart (publizierte View): lead_ki_offen_v
    Arbeitsliste fuer den Skill lead-bewertung (taeglich 06:30): Gelegenheiten, die ein KI-Urteil brauchen.
    Aufnahme: wie lead_gelegenheiten_v (30 Tage, nicht ausgeschlossen) und vorscore >= 40, Status nicht 'kein fit' oder 'erledigt', und
      grund 'neu'        : noch kein KI-Urteil
      grund 'geaendert'  : seit dem letzten Urteil hat ein Satellit einer Stelle des Clusters eine neue Zeile bekommen (Inhalt geaendert oder neue Quelle);
                           die Sichtungs-Satelliten zaehlen nicht (die aendern sich bei jedem Lauf). Vorberechnet in lead_gelegenheiten.inhalt_geaendert_am.
    Sortierung der Ausgabe: vorscore absteigend (ORDER BY im Abruf). Schluessel gelegenheit_id (varchar, erste Spalte).
    Duenne View auf lead_gelegenheiten und lead_firmen (Tageslauf). Live nur: Ausschluss bereits bewerteter Gelegenheiten ueber
    landing.lead_engine_ki_bewertung (juengstes Urteil je Gelegenheit).
    Quellen: lead_gelegenheiten, lead_firmen, landing.lead_engine_ki_bewertung (live)
    Version: 2026-11-03 V1.0 Erste Fassung
    Version: 2026-11-04 V1.1 Duenne View auf den Tabellen (MCP-Laufzeit), inhalt_geaendert_am vorberechnet
#}
{{ config(materialized='view', tags=['report']) }}

with ki as (   -- juengstes Urteil je Gelegenheit, live
    select x.gelegenheit_id, x.ki_einstufung, x.bewertet_am
    from (select k.*, row_number() over (partition by k.gelegenheit_id order by k.bewertet_am desc, k.bewertung_id desc) as rn
          from {{ source('lead_engine', 'lead_engine_ki_bewertung') }} k) x
    where x.rn = 1
)

select
    g.gelegenheit_id,
    g.vorscore, g.lead_typ,
    g.titel, g.url,
    g.text,
    g.firma_name,
    g.firma_id,
    g.ort, g.ort_quelle, g.bundesland, g.ist_remote, g.veroeffentlicht_am,
    g.begruendung_kurz,
    g.p_thema, g.p_typ, g.p_region, g.p_frische, g.p_passung, g.p_bonus, g.p_abzug,
    g.groesse,
    g.ist_konzern,
    f.groessenklasse, f.groessenklasse_code, f.abschluss_stichtag,
    f.bilanzsumme, f.umsatzerloese, f.eigenkapital, f.jahresergebnis, f.mitarbeiter_abschluss,
    f.fn, f.rechtsform, f.firmenbuch_sitz, f.firmenbuch_ereignisse,
    f.geschaeftsfuehrung, coalesce(f.anzahl_prokuristen, 0) as anzahl_prokuristen,
    case when ki.gelegenheit_id is null then 'neu' else 'geaendert' end            as grund,
    ki.ki_einstufung                                                               as ki_bisherige_einstufung,
    ki.bewertet_am                                                                 as ki_bewertet_am
from {{ ref('lead_gelegenheiten') }} g
left join ki on ki.gelegenheit_id = g.gelegenheit_id
left join {{ ref('lead_firmen') }} f on f.firma_id = g.firma_id
where g.vorscore >= 40
  and coalesce(g.status, '') not in ('kein fit', 'erledigt')
  and (ki.gelegenheit_id is null or g.inhalt_geaendert_am > ki.bewertet_am)
