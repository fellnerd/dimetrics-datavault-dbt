---
title: "Wichtige Spalten verstehen"
tags:
  - benutzer
---
[Dokumentation](../README.md) › [Data Vault 2.1 – Benutzer-Dokumentation](00-benutzerhandbuch.md)

# Wichtige Spalten verstehen

Jede Vault-Tabelle hat neben den fachlichen Spalten der Quelle technische Spalten mit festen Präfixen: `hk_` (Hash Key), `hd_` (Hash Diff) und `dss_` (Data Store Service, Metadaten). Welche davon eine Tabelle trägt, hängt vom Objekttyp ab.

## Schlüssel (`hk_…`, `hd_…`)

| Spalte | Wo | Bedeutung |
|--------|----|-----------|
| `hk_<entity>` | Hub (PK), Satellite (FK/PK), Link (FK) | Hash Key: SHA2-256 über den Business Key, 64 Hex-Zeichen (`CHAR(64)`). Verbindet Hub, Satellites und Links |
| `hk_link_<e1>_<e2>` | Link (PK), Link-Satellite | Hash über die Business Keys aller beteiligten Hubs |
| `hd_<entity>__<quelle>` | Staging View | Hash Diff: Fingerabdruck aller beschreibenden Attribute. Ändert sich ein Attribut, ändert sich der Hash |
| `hashdiff` | Satellite | Derselbe Hash Diff, im Satellite unter diesem Namen gespeichert (automate_dv-Alias) |
| `<business_key>` | Hub, Staging | Der fachliche Schlüssel im Original, z. B. `BELNR`, `LOHNNR` |

Hash Keys sind deterministisch: gleicher Business Key → gleicher Hash, in jeder Umgebung. Zwei Sonderwerte kennzeichnen [Ghost Records](02-grundkonzepte.md): `0000…0000` (64 × `0`, unbekannt) und `FFFF…FFFF` (64 × `F`, fehlerhaft).

## Metadaten, die jede Vault-Tabelle hat

| Spalte | Typ | Bedeutung | Beispiel |
|--------|-----|-----------|----------|
| `dss_load_date` | DATETIME2 | Wann wurde die Zeile in den Vault geladen (ein Wert je Ladelauf) | `2026-09-14 02:10:00` |
| `dss_record_source` | NVARCHAR | Aus welchem Quellsystem stammt sie (systemweit normiert) | `<mandant>_<quellsystem>` |

## Hubs

| Spalte | Typ | Bedeutung | Beispiel |
|--------|-----|-----------|----------|
| `dss_business_key` | NVARCHAR | Business Key im Klartext, normiert und lesbar — für Prüfungen und Fehlersuche. Aufbau `default\|\|default\|\|<BK 1>\|\|<BK 2>…`, NULL wird `-1` | `default\|\|default\|\|4711` |
| `dss_create_datetime` | DATETIME2 | Technischer Zeitpunkt, zu dem die Zeile geschrieben wurde | `2026-09-14 02:11:37` |

Ein Hub enthält jeden Business Key **genau einmal** — die erste Sichtung. Er wird nie aktualisiert. Details zum Aufbau: [Datenmodell → dss_business_key](../03-system/allgemein/03-datenmodell.md).

## Satellites (Historie)

| Spalte | Typ | Bedeutung | Beispiel |
|--------|-----|-----------|----------|
| `dss_is_current` | CHAR(1) | Ist das die aktuelle Version des Schlüssels? | `Y` / `N` |
| `dss_end_date` | DATETIME2 | Bis wann war die Version gültig; `NULL` = noch gültig | `2026-06-15 02:10:00` |
| `dss_create_datetime` | DATETIME2 | Technischer Insert-Zeitpunkt | |
| `dss_version_rank` | INT | Nur in `…_current_v`-Views: Rang der Version (1 = neueste), nicht gespeichert | `1` |

**Aktuellen Stand abfragen:** `WHERE dss_is_current = 'Y'` oder direkt die View `sat_<entity>__<quelle>_current_v`. **Stand zu einem Stichtag:** `dss_load_date <= @stichtag AND (dss_end_date > @stichtag OR dss_end_date IS NULL)`.

## Effectivity Satellites (Gültigkeit von Beziehungen)

| Spalte | Typ | Bedeutung |
|--------|-----|-----------|
| `dss_eff_date` | DATETIME2 | Beginn der fachlichen Gültigkeit |
| `dss_start_date` | DATETIME2 | Beginn der Beziehung |
| `dss_end_date` | DATETIME2 | Ende der Beziehung; `NULL` = besteht noch |
| `dss_is_active` | CHAR(1) | `Y` = Beziehung aktiv, `N` = beendet |

## Herkunft bei dateibasierten Quellen (Lineage)

| Spalte | Bedeutung |
|--------|-----------|
| `dss_source_file_name` | Datei, aus der die Zeile stammt (ältere Objekte: `dss_source_filename`) |
| `dss_stage_timestamp` | Zeitstempel der Landing Zone |
| `dss_run_id` | Kennung des Lade-/Pipeline-Laufs |
| `dss_source_feed` | Rohwert der Quelle (z. B. Ordnerpfad) vor der Normierung zu `dss_record_source` |
| `dss_export_datum` | Exportzeitpunkt aus dem Dateinamen — bei Mehrfachlieferungen gewinnt der letzte Export |

Lineage-Spalten beschreiben die Lieferung, nicht den Inhalt: Sie ändern sich bei jeder Datei, lösen aber keine neue Satellite-Version aus.

## Security

| Spalte | Wo | Bedeutung | Beispiel |
|--------|----|-----------|----------|
| `dss_sec_value_key` | Mart-Dimensionen, die Zeilen filtern (Kostenstelle, Konto …) | Hierarchischer Berechtigungsschlüssel für die Zeilenfilter (RLS). Ein Recht auf einen Präfix gilt für alles darunter | `<mandant>\|\|3 Vertrieb\|\|2030` |

Wie Berechtigungen wirken: [Datenzugriff & Berechtigungen](09-datenzugriff-berechtigungen.md).

## Mart (Dimensionen und Fakten)

| Spalte | Typ | Bedeutung |
|--------|-----|-----------|
| `<dim>_key` | BIGINT | Surrogate Key der Dimension; in Fakten derselbe Wert als Fremdschlüssel |
| `<dim>_id` | NVARCHAR | Technische ID aus dem Quellsystem |
| `<dim>_code` | NVARCHAR | Sprechender Schlüssel; fehlt er, steht die ID darin |
| `<dim>_name` | NVARCHAR | Bezeichnung; fehlt sie, der Code bzw. `UNKNOWN` |
| `datum_key` | INT | Datumsschlüssel `JJJJMMTT` gegen `dim_date` |

Negative Schlüssel (`-1`, `-2` …) sind Platzhalter-Zeilen, z. B. für „unbekannt“ oder Zwischensummen in Berichten.

---

◀ [Grundkonzepte](02-grundkonzepte.md) · [Übersicht](00-benutzerhandbuch.md) · [Namenskonventionen](04-namenskonventionen.md) ▶
