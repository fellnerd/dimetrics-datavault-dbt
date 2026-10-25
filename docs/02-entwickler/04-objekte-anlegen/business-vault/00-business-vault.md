---
title: "Business Vault"
aliases:
  - "Business Vault"
tags:
  - entwickler/business-vault
  - typ/inhaltsverzeichnis
---
[Dokumentation](../../../README.md) › [Data Vault 2.1 – Developer Guide](../../00-entwicklerhandbuch.md) › [Objekte anlegen](../00-objekte-anlegen.md)

# Business Vault

Der Business Vault enthält **abgeleitete** Objekte auf dem Raw Vault: Sichten auf den aktuellen Stand, Stichtagshilfen und fachliche Regeln (Soft Rules). Er speichert keine eigenen Quelldaten und ist jederzeit aus dem Raw Vault neu baubar — deshalb überwiegend Views.

| # | Objekt | Name | Materialisierung | Wofür |
|---|--------|------|------------------|-------|
| 1 | [Current View](01-current-view.md) | `sat_<…>_current_v` | View (Macro `satellite_current_view`) | aktuelle Version je Schlüssel — Standardquelle der Dimensionen (SCD1) |
| 2 | [PIT Table](02-pit-table.md) | `pit_<entity>` | Table | Stichtagsabfragen über mehrere Satellites eines Hubs ohne teure Range-Joins |
| — | Bridge | `bridge_<thema>` | Table | mehrstufige Link-Pfade vorberechnen (bei Bedarf, Vorlage `design/business-vault/_template_bridge.md`) |
| — | Business-Regel | `<thema>_v` | View | fachliche Ableitungen, Zuordnungen, Klassifizierungen (Soft Rules) |

## Wo Business-Regeln hingehören

| Regel | Ort |
|-------|-----|
| Typ, Format, Trimmen, NULL-Platzhalter (Hard Rules) | Staging View |
| Fachliche Ableitung, die mehrere Marts brauchen (z. B. Kontogruppen-Zuordnung, Kategorisierung) | Business-Vault-View `<thema>_v`, Ordner `models/business_vault/`, dokumentiert in `_business_vault__models.yml` |
| Berichtsspezifische Aufbereitung (Umbenennen, Formatieren, Sortierschlüssel) | Mart |
| Pflegbare Zuordnungstabellen | Seed (`seeds/seed_<thema>.csv`) → Business-Vault-View mit DV-Metadaten |

Business-Vault-Views führen `dss_load_date` und `dss_record_source` weiter bzw. setzen sie (`'business_rule'`), damit die Herkunft nachvollziehbar bleibt.
