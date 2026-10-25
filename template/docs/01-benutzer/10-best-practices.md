---
title: "Best Practices"
tags:
  - benutzer
---
[Dokumentation](../README.md) › [Data Vault 2.1 – Benutzer-Dokumentation](00-benutzerhandbuch.md)

# Best Practices

## Abfragen und Berichte

- **Für Berichte nur `_v`-Views aus `mart*` verwenden.** Sie sind stabil benannt, berechtigt und tragen die Zeilenfilter. Vault-Tabellen ändern sich mit der Modellierung.
- **Aktuellen Stand über `dss_is_current = 'Y'` oder `…_current_v`**, nie über `MAX(dss_load_date)` je Schlüssel selbst nachbauen.
- **Stichtagsabfragen** über `dss_load_date`/`dss_end_date` (siehe [Daten prüfen](08-daten-pruefen.md)) oder eine PIT-Tabelle, nicht über das Änderungsdatum der Quelle.
- **Joins immer über `hk_*` bzw. `<dim>_key`**, nicht über Namen oder Texte.
- **Ghost Records** (Hash `0000…`/`FFFF…`, Key `-1`) nicht herausfiltern, ohne zu prüfen, wie viele Fakten daran hängen — sie zeigen fehlende Stammdaten an.

## Entwicklung

1. **Branch von `dev` anlegen** (`feat/<thema>`), nie direkt auf `test`/`main` arbeiten.
2. **Model First:** Entwurf und ER-Diagramm unter `design/` vor dem Code (Skill `dv-design-sync`).
3. **Business Key vor dem Hub prüfen** — Eindeutigkeit in der Quelle ([Daten prüfen → Eindeutigkeit](08-daten-pruefen.md)).
4. **Klein bauen:** `dbt build --select +<modell>+` statt `dbt run` über alles.
5. **Kompiliertes SQL lesen**, bevor es gegen Test geht (`target/compiled/…`).
6. **Jedes Modell dokumentieren und testen** (`_…__models.yml`: Beschreibung, Spalten, `unique`/`not_null`/`relationships`).
7. **Changelog und Design-Diagramm nachziehen**, dann Merge Request — die CI validiert Kompilierung und Tests ([Deployment Workflow](../02-entwickler/06-deployment-workflow.md)).

## Was man nicht tun sollte

| Nicht | Warum | Stattdessen |
|-------|-------|-------------|
| `--full-refresh` auf Hubs, Satellites, Links | Historie, die die Quelle nicht mehr liefert, ist weg | Neue Spalten kommen ohne Full Refresh; bei Hash-Änderungen Migration planen |
| Direkt in Datenbanktabellen schreiben (`UPDATE`, `DELETE`) | Umgeht Versionierung und Nachvollziehbarkeit | Änderung als dbt-Modell/Macro |
| Vault-Tabellen umbenennen | Bedeutet Neuaufbau samt Historienverlust | Neue Objekte richtig benennen ([Namenskonventionen](04-namenskonventionen.md)) |
| Lineage-Spalten in den Hashdiff | Jede neue Datei erzeugt eine neue Version | nur fachliche Attribute im Hashdiff |
| Schema-Grants (`GRANT … ON SCHEMA`) | geben auch ungefilterte Tabellen frei | View-Grants per Hook ([Security](../03-system/security/00-security.md)) |
| Zugangsdaten im Repository | `profiles.yml`, Tokens gehören in die lokale Umgebung bzw. CI-Variablen | `.gitignore` beachten |

## Änderungen nachvollziehen

```bash
git log --oneline -15 -- models/raw_vault/_common/satellites/sat_<entity>__<quelle>.sql
git diff dev -- models/
```

Fachliche und technische Änderungen der Plattform: [Changelog](../changelog.md).

---

◀ [Datenzugriff & Berechtigungen](09-datenzugriff-berechtigungen.md) · [Übersicht](00-benutzerhandbuch.md) · [Troubleshooting](11-troubleshooting.md) ▶
