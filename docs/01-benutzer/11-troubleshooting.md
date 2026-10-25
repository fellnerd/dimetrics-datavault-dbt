---
title: "Troubleshooting"
tags:
  - benutzer
  - typ/troubleshooting
---
[Dokumentation](../README.md) › [Data Vault 2.1 – Benutzer-Dokumentation](00-benutzerhandbuch.md)

# Troubleshooting

Symptom suchen, Ursache prüfen, Lösung anwenden. Entwicklerspezifische Fehler (Hashes, Modellierung, CI): [Troubleshooting Entwicklung](../02-entwickler/07-troubleshooting.md).

## Verbindung und Anmeldung

| Symptom | Ursache | Lösung |
|---------|---------|--------|
| `Login failed for user '<token-identified principal>'` | Entra-Token abgelaufen oder falscher Tenant | `az login` (ggf. `az login --tenant <tenant-id>`), `az account show`, dann `dbt debug` |
| `Login timeout expired` / `TCP Provider: Error code 0x2746` | Eigene IP nicht in der Firewall, VPN fehlt | Betrieb um Firewall-Freigabe bitten; `az sql server firewall-rule list --resource-group <rg> --server <sql-server>` |
| `Can't open lib 'ODBC Driver 18 for SQL Server'` | ODBC-Treiber fehlt | Treiber installieren ([Erste Schritte](05-erste-schritte.md)) |
| `Could not find profile named 'datavault'` | `profiles.yml` fehlt oder liegt woanders | Aus `profiles.yml.example` anlegen; Ablageort Projektordner oder `~/.dbt/` |
| `The target '…' is not found` | Target-Name im Profil anders | `dbt debug --target <name>`; Namen in `profiles.yml` prüfen |
| Datenbank nach Pause langsam / Fehler 40613 | Serverless-Datenbank wacht auf | 1 Minute warten, erneut ausführen |

## dbt-Aufrufe

| Symptom | Ursache | Lösung |
|---------|---------|--------|
| `dbt: command not found` | virtuelle Umgebung nicht aktiv | `source .venv/bin/activate` |
| `dbt found … package(s) specified … not installed` | Pakete fehlen | `dbt deps` |
| `Compilation Error … 'automate_dv' is undefined` | Pakete fehlen oder veraltet | `dbt clean && dbt deps` |
| `Nothing to do` / `does not match any enabled nodes` | Selektor trifft nichts | `dbt ls --select <selektor>` prüfen; Modellname = Dateiname ohne `.sql` |
| Modell läuft, Daten fehlen | Massendaten-Domäne per Tag ausgeschlossen | `dbt run --select tag:<domain>` |

## External Tables und Quelldaten

| Symptom | Ursache | Lösung |
|---------|---------|--------|
| `External table … is not accessible because location does not exist` | Datei/Ordner in der Landing Zone fehlt oder wird gerade neu geschrieben | Pfad im Storage prüfen; nach dem Quell-Load erneut ausführen |
| `Invalid column name` in einer Staging View | Spalte fehlt in `sources.yml` oder in der Datei | `get_parquet_schema` gegen die Datei, `sources.yml` abgleichen, `stage_external_sources` |
| Falsche Umlaute / Typfehler beim Lesen | Datentyp in `sources.yml` passt nicht zur Parquet-Datei | Typ angleichen, External Table mit `ext_full_refresh: true` neu anlegen |

## Daten

| Symptom | Ursache | Lösung |
|---------|---------|--------|
| Bericht zeigt 0 Zeilen | Zeilenrecht fehlt (oft auf der zweiten Achse) | [Datenzugriff](09-datenzugriff-berechtigungen.md) |
| Werte zeigen `***` | Spaltenmaskierung | Freigabe beantragen |
| Zahlen weichen von der Quelle ab | Letzter Load noch nicht verarbeitet oder Stichtag verschieden | `vault.load_status` und `MAX(dss_load_date)` prüfen ([Daten prüfen](08-daten-pruefen.md)) |
| Fakten unter „(leer)“ / Key `-1` | Stammdatensatz fehlt in der Dimension | Waisen-Abfrage aus [Daten prüfen](08-daten-pruefen.md) |
| Doppelte Zeilen im Bericht | Join über einen Link mit falschem Grain | Eindeutigkeitsprüfungen je Objekt |

## Logs und Artefakte

```bash
less logs/dbt.log                                     # vollständiges Log des letzten Laufs
cat target/compiled/datavault/models/<pfad>/<modell>.sql   # erzeugtes SELECT
cat target/run/datavault/models/<pfad>/<modell>.sql        # tatsächlich ausgeführtes DDL/DML
jq '.results[] | {model: .unique_id, status: .status, time: .execution_time}' target/run_results.json
```

---

◀ [Best Practices](10-best-practices.md) · [Übersicht](00-benutzerhandbuch.md) · [Häufige Fragen (FAQ)](12-haeufige-fragen-faq.md) ▶
