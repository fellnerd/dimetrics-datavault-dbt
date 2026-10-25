---
title: "Checklisten"
tags:
  - entwickler
  - typ/checkliste
---
[Dokumentation](../README.md) › [Data Vault 2.1 – Developer Guide](00-entwicklerhandbuch.md)

# Checklisten

Zum Kopieren in den Merge Request. Obsidian: Kästchen direkt abhaken.

## Neue Quelle / neue Entität

- [ ] Ticket mit fachlicher Anforderung und Akzeptanzkriterien vorhanden
- [ ] Business Key bestimmt und **in der Quelle eindeutig** geprüft
- [ ] Entwurf und ER-Diagramm unter `design/` (Model First)
- [ ] External Table in `sources.yml` (Typen per `get_parquet_schema`, `NVARCHAR`)
- [ ] Staging View mit `automate_dv.stage()`
  - [ ] `dss_record_source`, `dss_load_date`, `dss_create_datetime`, `dss_business_key`
  - [ ] Hash Keys für Primär- und FK-Hubs, Link-Hash aus allen Business Keys
  - [ ] Hash Diff nur mit fachlichen Attributen (keine Lineage-/`dss_`-Spalten)
  - [ ] reservierte Wörter in `_escape`
- [ ] FK-Staging-View je Fremdschlüssel-Hub
- [ ] Hub(s): `src_extra_columns` mit `dss_business_key`, `dss_create_datetime`; `create_hash_index`
- [ ] Satellite(s): Payload = Hash-Diff-Spalten, `alias: "hashdiff"`, beide Post-Hooks
- [ ] Link(s): richtige `src_fk`-Reihenfolge, Grain geprüft
- [ ] Current View je Satellite
- [ ] Richtiges Schema/Ordner (`_common` oder `<concept>`), Tag bei Massendaten
- [ ] YAML mit Beschreibung, Spalten, Pflichttests
- [ ] `dbt build --select +<modelle>+` grün
- [ ] Prüfabfragen ausgeführt: Zeilenzahlen, Eindeutigkeit, Waisen ([Daten prüfen](../01-benutzer/08-daten-pruefen.md))
- [ ] Changelog-Eintrag, projektspezifische Doku (Quellsystem) ergänzt

## Attribut hinzufügen

- [ ] Weg entschieden (neuer Satellite / erweitern) — [Attribut hinzufügen](04-objekte-anlegen/raw-vault/09-attribut-hinzufuegen.md)
- [ ] External Table erweitert und neu angelegt (`ext_full_refresh: true`)
- [ ] Hash Diff und Payload identisch erweitert bzw. neuer Satellite angelegt
- [ ] Datenwirkung im MR beschrieben (neue Versionen je Schlüssel, ab welchem Load gefüllt)
- [ ] Kein Full Refresh auf historisierten Satellites
- [ ] YAML, Mart, Changelog nachgezogen

## Mart-Objekt

- [ ] `dim_*`/`fakt_*` als Tabelle, publiziert nur über `_v`-View
- [ ] Surrogate Keys über `surrogate_key()`, gleiche Aufrufe in Dimension und Fakt
- [ ] Pflichtspalten mit NULL-Fallbacks, Unbekannt-Zeile für fehlende Bezüge
- [ ] SCD1 oder SCD2 bewusst entschieden
- [ ] Träger-Dimension führt `dss_sec_value_key` + `rls_filter`; Fakt-View joint sie
- [ ] PII-Spalten mit `cls_mask`, keine Tier-1-Spalten
- [ ] Schema in `ols_view_grants` für die zuständige Gruppe
- [ ] `unique`/`not_null` auf Keys, `relationships` Fakt → Dimension
- [ ] Mart-Diagramm `design/mart/er-mart-<domain>.mmd`
- [ ] Mit Test-User verifiziert ([Security → Verifizieren](../03-system/security/07-verifizieren.md))

## Pre-Merge (jeder Merge Request)

- [ ] Branch aktuell mit `dev` (`git pull origin dev`)
- [ ] `dbt parse` fehlerfrei, keine neuen Deprecation-Warnungen
- [ ] `dbt test --exclude tag:nightly path:models/staging` grün
- [ ] Keine hartkodierten Datenbanknamen (`{{ target.database }}`), keine Zugangsdaten
- [ ] `as_columnstore=false` auf allen Tabellen
- [ ] Breaking Change (Full Refresh, entfallene Spalte) im Titel mit `!` und im MR begründet
- [ ] Changelog, Design, Doku aktualisiert
- [ ] MR-Beschreibung mit Datenwirkung und Prüfergebnissen

## Release nach Produktion

- [ ] Fachliche Abnahme in Test im Ticket dokumentiert
- [ ] Freigabe fachlich und technisch im MR `test` → `main`
- [ ] Versionsnummer nach SemVer bestimmt, Tag gesetzt
- [ ] Produktions-Pipeline grün, `vault.load_status` = `completed`
- [ ] Stichprobe in Produktion (Zeilenzahlen, ein Bericht)
- [ ] Changelog-Einträge mit Version versehen

## Pipeline-Störungen

| Problem | Prüfen / Lösung |
|---------|-----------------|
| Pipeline startet nicht | Änderung außerhalb der Pfadfilter (`models/`, `macros/`, `seeds/`, `dbt_project.yml`, `packages.yml`)? Job manuell starten |
| `Could not find profile` | CI-Variablen für Server/DB/Auth; `DBT_PROFILES_DIR` |
| `Login failed` | Dienstprinzipal-Secret abgelaufen? CI-Variable erneuern |
| Job wartet ewig („Waiting for resource“) | anderer Deploy-Job derselben Umgebung läuft oder hängt |
| Timeout | Massendaten-Domäne im Standardlauf? Über Domänen-Job laden |
| Tests nur in Test/Prod rot | Seeds nicht geladen (`dbt seed --target …`), Rechte des Testbenutzers |
| Runner offline | Runner-Dienst auf dem CI-Host neu starten |

---

◀ [Troubleshooting](07-troubleshooting.md) · [Übersicht](00-entwicklerhandbuch.md)
