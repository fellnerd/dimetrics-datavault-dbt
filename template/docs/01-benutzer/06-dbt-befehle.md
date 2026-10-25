---
title: "dbt-Befehle"
tags:
  - benutzer
  - typ/nachschlagen
---
[Dokumentation](../README.md) › [Data Vault 2.1 – Benutzer-Dokumentation](00-benutzerhandbuch.md)

# dbt-Befehle

Alle Befehle im Projektordner mit aktivierter virtueller Umgebung (`source .venv/bin/activate`). Ohne `--target` läuft alles gegen die Entwicklung (Standard-Target im Profil).

## Grundbefehle

| Befehl | Was passiert | Schreibt in die DB? |
|--------|--------------|:---:|
| `dbt debug` | Profil, Pakete und Verbindung prüfen | — |
| `dbt deps` | Pakete aus `packages.yml` installieren/aktualisieren | — |
| `dbt parse` | Projekt einlesen und validieren (schnell, ohne DB) | — |
| `dbt ls --select <selektor>` | Welche Modelle trifft ein Selektor? | — |
| `dbt compile --select <modell>` | SQL erzeugen → `target/compiled/datavault/models/…` | — |
| `dbt show --select <modell> --limit 10` | Ergebnis eines Modells ansehen | — |
| `dbt show --inline "SELECT TOP 5 * FROM vault.hub_<entity>"` | Ad-hoc-Abfrage | — |
| `dbt run` | Modelle bauen (Standardlauf ohne getaggte Massendaten-Domänen) | ✅ |
| `dbt test` | Tests ausführen | — |
| `dbt build` | `seed` + `run` + `test` + `snapshot` in Abhängigkeitsreihenfolge | ✅ |
| `dbt seed` | CSV-Referenzdaten aus `seeds/` laden | ✅ |
| `dbt docs generate` / `dbt docs serve` | Modelldokumentation mit Lineage-Graph erzeugen / im Browser öffnen | — |
| `dbt clean` | `target/` und `dbt_packages/` löschen (danach `dbt deps`) | — |

## Selektion

| Selektor | Trifft | Beispiel |
|----------|--------|----------|
| `<modell>` | ein Modell (Name ist projektweit eindeutig) | `--select hub_kunde` |
| `+<modell>` | Modell und alles davor (Staging, Hubs …) | `--select +sat_kunde__crm` |
| `<modell>+` | Modell und alles danach (Satellites, Marts …) | `--select crm_kunde+` |
| `+<modell>+` | vollständige Kette | |
| `path:models/<pfad>` | ein Ordner oder eine Datei | `--select path:models/raw_vault/crm` |
| `raw_vault.<concept>` | alle Raw-Vault-Modelle eines Concepts | `--select raw_vault.crm` |
| `staging.<concept>_*` | alle Staging Views einer Quelle | |
| `tag:<tag>` | Modelle mit Tag | `--select tag:dimension` |
| `state:modified` | geänderte Modelle gegenüber einem Manifest | `--select state:modified --state <pfad>` |
| mehrere, Leerzeichen getrennt | Vereinigung | `--select hub_kunde sat_kunde__crm` |
| `--exclude <selektor>` | ausschließen | `--exclude tag:nightly` |

## Täglich

```bash
# Verbindung/Anmeldung prüfen (nach Neustart, abgelaufenem Token)
az login && dbt debug

# Geänderte Modelle samt Abhängigkeiten bauen und testen
dbt build --select +<modell>+

# Nur ein Modell neu bauen
dbt run --select <modell>

# Tests eines Modells
dbt test --select <modell>

# Neue oder geänderte Quelldateien: External Tables aktualisieren
dbt run-operation stage_external_sources
```

## External Tables

```bash
# Alle External Tables aus sources.yml anlegen/aktualisieren (idempotent)
dbt run-operation stage_external_sources

# Nur eine Tabelle
dbt run-operation stage_external_sources --args 'select: staging.ext_<concept>_<entity>'

# Neu anlegen (DROP + CREATE), z. B. nach geänderten Spalten
dbt run-operation stage_external_sources --args 'select: staging.ext_<concept>_<entity>' --vars 'ext_full_refresh: true'

# Schnell eine einzelne neue Tabelle anlegen
dbt run-operation create_external_table --args '{"table_name": "ext_<concept>_<entity>"}'

# Parquet-Datei untersuchen (benötigt STAGE_FS_SAS)
dbt run-operation get_parquet_schema --args '{"folder_path": "<concept>/<quelle>", "file_name": "<datei>.parquet"}'
dbt run-operation get_parquet_data   --args '{"folder_path": "<concept>/<quelle>", "file_name": "<datei>.parquet", "limit": 5}'
```

## Andere Umgebungen

```bash
dbt run  --target <mandant>-test --select <modell>
dbt test --target <mandant>-test --select <modell>
```

Test und Produktion werden regulär von der Pipeline beliefert ([Deployment Workflow](../02-entwickler/06-deployment-workflow.md)); manuelle Läufe gegen Produktion nur im abgestimmten Ausnahmefall.

## Massendaten-Domänen

Domänen mit eigenem Ladefenster (Massendaten, z. B. Logs, Events, Sensordaten) tragen ein Tag (z. B. `iot`) und sind vom Standardlauf ausgeschlossen:

```bash
dbt run --select tag:<domain>
dbt test --select tag:<domain>
```

## Betrieb und Diagnose

```bash
dbt run-operation log_row_counts                                  # Zeilen je Vault-Objekt
dbt run-operation insert_ghost_records                            # Ghost Records in allen Hubs
dbt run-operation run_sql --args '{"sql": "SELECT COUNT(*) FROM vault.hub_<entity>"}'
dbt run-operation measure_rls_overhead --args '{relation: mart_<domain>.fakt_<inhalt>_v}'
```

Logs: `logs/dbt.log`, Ergebnisse des letzten Laufs: `target/run_results.json`.

## Full Refresh

> [!WARNING]
> `--full-refresh` löscht eine inkrementelle Tabelle und baut sie aus den aktuell verfügbaren Quelldaten neu. **Bei Hubs, Satellites und Links geht dabei die Historie verloren**, die in der Quelle nicht mehr vorhanden ist. Nur nach Absprache, nie auf Produktion ohne Freigabe, nie „zur Sicherheit“.

```bash
dbt run --full-refresh --select <modell>
```

Nötig ist er nur, wenn sich die Berechnung bestehender Zeilen ändert (Hash-Input, Datentyp, Business Key). Neue Spalten kommen ohne Full Refresh dazu (`on_schema_change: append_new_columns`).

---

◀ [Erste Schritte](05-erste-schritte.md) · [Übersicht](00-benutzerhandbuch.md) · [Neue Entity hinzufügen](07-neue-entity-hinzufuegen.md) ▶
