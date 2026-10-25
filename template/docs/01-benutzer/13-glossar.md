---
title: "Glossar"
tags:
  - benutzer
  - typ/glossar
---
[Dokumentation](../README.md) › [Data Vault 2.1 – Benutzer-Dokumentation](00-benutzerhandbuch.md)

# Glossar

## Data Vault

| Begriff | Erklärung |
|---------|-----------|
| **Data Vault 2.1** | Modellierungsmethode für historisierte, quellübergreifende Data Warehouses: Hubs (Schlüssel), Links (Beziehungen), Satellites (Attribute + Historie) |
| **Raw Vault** | Vault-Schicht mit den Quelldaten ohne fachliche Umrechnung (Hard Rules: Typ, Format, Hash) |
| **Business Vault** | Abgeleitete Objekte auf dem Raw Vault: Current Views, PIT, Bridges, fachliche Regeln (Soft Rules) |
| **Information Mart** | Berichtsschicht als Star Schema (Dimensionen, Fakten) für BI-Tools |
| **Hub** | Liste der eindeutigen Business Keys einer Entität |
| **Satellite** | Beschreibende Attribute eines Hubs oder Links mit vollständiger Historie |
| **Link** | Beziehung zwischen zwei oder mehr Hubs |
| **Transaction Link** | Link für unveränderliche Ereignisse (Buchung, Messwert, Log-Eintrag) |
| **Link Satellite** | Satellite mit Attributen einer Beziehung |
| **Effectivity Satellite** | Satellite, der festhält, von wann bis wann eine Beziehung gültig war |
| **Multi-Active Satellite** | Satellite mit mehreren gleichzeitig gültigen Zeilen je Schlüssel (z. B. mehrere Telefonnummern) |
| **Dependent-Child Satellite** | Satellite, dessen Zeilen zusätzlich über ein abhängiges Attribut unterschieden werden |
| **Reference Table** | Code- und Zuordnungsliste ohne eigene Historie (`ref_*`, Seeds) |
| **PIT (Point-in-Time)** | Hilfstabelle, die je Schlüssel und Stichtag die gültigen Satellite-Versionen referenziert |
| **Bridge** | Hilfstabelle, die mehrstufige Link-Pfade vorberechnet |
| **Current View** | View mit nur der aktuellen Version je Schlüssel (`…_current_v`) |
| **PSA (Persistent Staging Area)** | Inkrementell gespeicherte Kopie einer Quelle, um teure Dateizugriffe zu vermeiden |
| **Ghost Record** | Platzhalter-Zeile mit Hash `0000…` (unbekannt) bzw. `FFFF…` (Fehler) |

## Schlüssel und Hashes

| Begriff | Erklärung |
|---------|-----------|
| **Business Key (BK)** | Fachlicher Schlüssel aus der Quelle (Kundennummer, Belegnummer) |
| **Hash Key (`hk_`)** | SHA2-256 des Business Keys, 64 Hex-Zeichen — technischer Primärschlüssel im Vault |
| **Hash Diff (`hd_`, `hashdiff`)** | Hash aller beschreibenden Attribute; ändert er sich, entsteht eine neue Satellite-Version |
| **Composite Key** | Business Key aus mehreren Spalten, im Hash mit `\|\|` verkettet |
| **`dss_business_key`** | Lesbare Klartext-Form des Business Keys im Hub |
| **Driving Key** | Schlüssel, der in einem Effectivity Satellite bestimmt, welche Beziehung endet, wenn eine neue beginnt |
| **Surrogate Key (`<dim>_key`)** | Deterministischer BIGINT-Schlüssel der Mart-Dimensionen |
| **Record Source** | Normierte Kennung des Quellsystems (`dss_record_source`) |
| **Load Date** | Ladezeitpunkt einer Zeile (`dss_load_date`) |

## Mart und BI

| Begriff | Erklärung |
|---------|-----------|
| **Star Schema** | Faktentabelle in der Mitte, Dimensionen außen, verbunden über Surrogate Keys |
| **Dimension (`dim_`)** | Beschreibende Sicht (Kunde, Konto, Datum) |
| **Fakt (`fakt_`)** | Messwerte (Betrag, Menge, Stunden) mit Schlüsseln auf die Dimensionen |
| **SCD1 / SCD2** | Slowly Changing Dimension: Typ 1 zeigt nur den aktuellen Stand, Typ 2 je Version eine Zeile mit Gültigkeit |
| **Publizierte View (`_v`)** | Einziger Zugang für BI-Tools, trägt Berechtigungen und Filter |
| **DirectQuery** | Power BI fragt bei jeder Interaktion live die Datenbank ab (Voraussetzung für RLS per SSO) |

## Security

| Begriff | Erklärung |
|---------|-----------|
| **OLS** | Object Level Security — wer welche View lesen darf |
| **RLS** | Row Level Security — welche Zeilen jemand sieht |
| **CLS** | Column Level Security — Maskierung sensibler Spalten |
| **`dss_sec_value_key`** | Hierarchischer Berechtigungsschlüssel einer Zeile |
| **Security-Kontext** | Achse eines Zeilenrechts, z. B. `finance_kst` (Kostenstellen) |
| **Data Owner** | Fachlich verantwortliche Person, die Zeilen- und PII-Rechte freigibt |
| **PII** | Personenbezogene Daten |

## Werkzeuge und Betrieb

| Begriff | Erklärung |
|---------|-----------|
| **dbt** | data build tool — erzeugt aus SQL-/Jinja-Modellen die Datenbankobjekte |
| **automate_dv** | dbt-Paket mit den Data-Vault-Makros (`stage`, `hub`, `sat`, `link` …) |
| **Modell** | Eine `.sql`-Datei in `models/` = ein Datenbankobjekt |
| **Macro** | Wiederverwendbare Jinja-Funktion (`macros/`) |
| **Seed** | CSV-Datei, die dbt als Tabelle lädt |
| **Target** | Zielumgebung eines dbt-Aufrufs (Dev, Test, Produktion) |
| **Materialisierung** | Wie dbt ein Modell anlegt: `view`, `table`, `incremental` |
| **Incremental** | Nur neue bzw. geänderte Zeilen werden angehängt |
| **Full Refresh** | Tabelle wird gelöscht und komplett neu gebaut — bei Vault-Tabellen mit Historienverlust |
| **External Table** | Tabelle in Azure SQL, die Parquet-Dateien im Storage liest |
| **Landing Zone** | Storage-Bereich, in den die Quellsysteme (z. B. per ADF) Dateien ablegen |
| **ADF** | Azure Data Factory — lädt Quelldaten in die Landing Zone |
| **CI/CD** | Automatische Prüfung (CI) und Auslieferung (CD) über die Pipeline |
| **Merge Request / Pull Request** | Antrag, Änderungen eines Branches zu übernehmen — mit Review und CI-Prüfung |
| **Model First** | Erst Entwurf und ER-Diagramm in `design/`, dann Code |

---

◀ [Häufige Fragen (FAQ)](12-haeufige-fragen-faq.md) · [Übersicht](00-benutzerhandbuch.md)
