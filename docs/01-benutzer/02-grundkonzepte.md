---
title: "Grundkonzepte"
tags:
  - benutzer
---
[Dokumentation](../README.md) › [Data Vault 2.1 – Benutzer-Dokumentation](00-benutzerhandbuch.md)

# Grundkonzepte

## Die vier Schichten

```
Quellsysteme ─► Landing Zone ─► Staging (stg) ─► Raw Vault (vault*) ─► Business Vault ─► Information Mart (mart*) ─► Power BI / Excel
                (Parquet)       Hashes,          Hubs, Links,          Current Views,     Dimensionen, Fakten,
                                Metadaten        Satellites            PIT, Regeln         publizierte _v-Views
```

| Schicht | Aufgabe | Ändert Daten? | Für Berichte? |
|---------|---------|---------------|---------------|
| **Staging** | Quelldatei lesbar machen, Hash Keys und Metadaten berechnen | nein (nur Typ/Format) | nein |
| **Raw Vault** | Alles aus allen Quellen historisiert speichern — die einzige Wahrheit | nein | nein |
| **Business Vault** | Abgeleitetes: aktueller Stand, Stichtagssichten, fachliche Regeln | ja (Regeln) | nein |
| **Information Mart** | Berichtsgerechte Sterne mit Berechtigungen | ja (Aufbereitung) | **ja** |

## Die Bausteine des Raw Vault

### Hub — „die Visitenkarte“

Ein Hub hält jeden fachlichen Schlüssel (Business Key) **genau einmal** — z. B. jede Kundennummer. Er sagt: *dieses Objekt existiert*, seit wann und aus welcher Quelle.

```
hub_kunde
┌──────────────┬──────────┬───────────────────────┬────────────────────┐
│ hk_kunde     │ KUNDENNR │ dss_load_date         │ dss_record_source  │
├──────────────┼──────────┼───────────────────────┼────────────────────┤
│ 3f9a…c21     │ 4711     │ 2026-01-15 02:10      │ <mandant>_crm      │
└──────────────┴──────────┴───────────────────────┴────────────────────┘
```

### Satellite — „der Aktenordner“

Ein Satellite hält die beschreibenden Attribute und **jede Änderung als eigene Zeile**. Je Quellsystem gibt es einen eigenen Satellite am selben Hub (`sat_kunde__crm`, `sat_kunde__erp`).

```
sat_kunde__crm  (Kunde 4711)
  Version 1  2026-01-15   Name "Muster GmbH"   dss_is_current = N   dss_end_date = 2026-06-01
  Version 2  2026-06-01   Name "Muster AG"     dss_is_current = Y   dss_end_date = NULL   ← Umfirmierung
```

### Link — „die Verbindung“

Ein Link verbindet Hubs, z. B. welcher Auftrag zu welchem Kunden gehört. Er kennt keine Attribute; beschreibt eine Beziehung selbst etwas, bekommt sie einen eigenen Satellite.

```
hub_auftrag ──── link_auftrag_kunde ──── hub_kunde
   A-100                                    4711
```

### Weitere Bausteine

| Baustein | Bild | Wofür |
|----------|------|-------|
| **Transaction Link** | Kassenbon | Unveränderliche Ereignisse wie Buchungen oder Messwerte |
| **Effectivity Satellite** | Mietvertrag mit Laufzeit | Von wann bis wann eine Beziehung galt (z. B. Kunde ↔ Vertrag) |
| **Multi-Active Satellite** | Adressbuch | Mehrere gleichzeitig gültige Einträge je Schlüssel (mehrere Telefonnummern) |
| **Dependent-Child Satellite** | Positionen einer Rechnung | Zeilen, die nur zusammen mit einem Unterschlüssel eindeutig sind |
| **Reference Table** | Nachschlageliste | Codes und Zuordnungen (Status, Kategorien) |
| **PIT-Tabelle** | Lesezeichen im Kalender | Schnell den Stand aller Satellites zu einem Stichtag finden |
| **Current View** | Deckblatt | Nur die aktuelle Version je Schlüssel |
| **Ghost Record** | Platzhalter | Steht für „unbekannt“ (`0000…`) oder „fehlerhaft“ (`FFFF…`), damit Joins nie ins Leere laufen |

## Information Mart — der Stern

Für Berichte wird der Vault in **Dimensionen** (wer, was, wo, wann) und **Fakten** (Beträge, Mengen) übersetzt. Power BI verbindet sie über die Schlüssel `<dim>_key`.

```
              dim_kunde_v
                   │
dim_date_v ── fakt_umsatz_v ── dim_produkt_v
```

Wie Spalten heißen und was sie bedeuten: [Wichtige Spalten verstehen](03-wichtige-spalten-verstehen.md). Welche Objekte es konkret gibt: `dbt docs serve` bzw. die [projektspezifische Dokumentation](../04-mandant-architektur/00-mandant-architektur.md).

---

◀ [Einführung: Was ist Data Vault?](01-einfuehrung-was-ist-data-vault.md) · [Übersicht](00-benutzerhandbuch.md) · [Wichtige Spalten verstehen](03-wichtige-spalten-verstehen.md) ▶
