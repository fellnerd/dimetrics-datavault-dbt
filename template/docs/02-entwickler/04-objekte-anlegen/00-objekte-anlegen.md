---
title: "Objekte anlegen"
aliases:
  - "Objekte anlegen"
  - "Neue Entity erstellen"
tags:
  - entwickler/objekte
  - typ/inhaltsverzeichnis
---
[Dokumentation](../../README.md) › [Data Vault 2.1 – Developer Guide](../00-entwicklerhandbuch.md)

# Objekte anlegen

Vorlagen und Regeln für jedes Objekt vom Quelldatei-Anschluss bis zur publizierten Mart-View. Welches Objekt wann passt: [Data Vault 2.1 Leitfaden](../01-data-vault-leitfaden.md).

## Ablauf für eine neue Entität

| # | Schritt | Datei | Anleitung |
|---|---------|-------|-----------|
| 0 | Quelle analysieren: Business Key (eindeutig?), Beziehungen, Änderungsverhalten, Datenmenge | `design/raw-vault/<concept>/` | [Daten prüfen → Eindeutigkeit](../../01-benutzer/08-daten-pruefen.md) |
| 1 | Entwurf und ER-Diagramm (Model First) | `design/…/er-diagram.mmd` | Skill `dv-design-sync` |
| 2 | External Table definieren | `models/staging/sources.yml` | [External Table](staging/01-external-table.md) |
| 3 | Staging View mit Hashes und Metadaten | `models/staging/<concept>_<entity>.sql` | [Staging View](staging/02-staging-view.md) |
| 3a | optional PSA bei großen/teuren Dateien | `models/staging/psa_<concept>_<entity>.sql` | [PSA](staging/03-psa.md) |
| 4 | Hub(s) — Primär- und FK-Hubs | `models/raw_vault/<_common\|concept>/hubs/` | [Hub](raw-vault/01-hub.md) |
| 5 | Satellite(s) je Quelle | `…/satellites/` | [Satellite](raw-vault/02-satellite.md) und Sondertypen |
| 6 | Link(s) für Beziehungen | `…/links/` | [Link](raw-vault/03-link.md), [Transaction Link](raw-vault/04-transaction-link.md) |
| 7 | Current View je Satellite | `…/satellites/sat_…_current_v.sql` | [Current View](business-vault/01-current-view.md) |
| 8 | Mart: Dimension/Fakt + `_v`-View mit Security | `models/mart/<domain>/` | [Mart](mart/00-mart.md) |
| 9 | Doku + Tests in `_…__models.yml` | im jeweiligen Ordner | [Tests](../05-tests.md) |
| 10 | Bauen, prüfen, Merge Request | — | [Deployment Workflow](../06-deployment-workflow.md), [Checklisten](../08-checklisten.md) |

`_common` (Schema `vault`) für Entitäten, die aus mehreren Quellen gespeist werden oder quellübergreifend genutzt werden; `<concept>` (Schema `vault_<concept>`) für Domänen mit eigenem Ladefenster. Kurzfassung mit durchgehendem Beispiel: [Neue Entity hinzufügen](../../01-benutzer/07-neue-entity-hinzufuegen.md).

## Objekttypen

| Schicht | Objekt | Wann | Anleitung |
|---------|--------|------|-----------|
| Staging | External Table | jede Quelldatei | [01](staging/01-external-table.md) |
| | Staging View | jede Quelltabelle, die in den Vault geht | [02](staging/02-staging-view.md) |
| | PSA | große Dateien, mehrere Konsumenten, instabile Landing Zone | [03](staging/03-psa.md) |
| Raw Vault | Hub | eigenständiger, stabiler Business Key | [01](raw-vault/01-hub.md) |
| | Satellite | beschreibende Attribute, die sich ändern | [02](raw-vault/02-satellite.md) |
| | Link | Beziehung zwischen Hubs | [03](raw-vault/03-link.md) |
| | Transaction Link | unveränderliche Ereignisse, Massendaten | [04](raw-vault/04-transaction-link.md) |
| | Effectivity Satellite | Gültigkeit einer Beziehung (Driving Key) | [05](raw-vault/05-effectivity-satellite.md) |
| | Dependent-Child Satellite | Zeilen nur mit Unterschlüssel eindeutig | [06](raw-vault/06-dependent-child-satellite.md) |
| | Multi-Active Satellite | mehrere gleichzeitig gültige Zeilen je Key | [07](raw-vault/07-multi-active-satellite.md) |
| | Reference Table | Codes, Zuordnungen, Seeds | [08](raw-vault/08-reference-table.md) |
| | Attribut hinzufügen | neue Quellspalte zu bestehendem Satellite | [09](raw-vault/09-attribut-hinzufuegen.md) |
| Business Vault | Current View | aktueller Stand je Satellite | [01](business-vault/01-current-view.md) |
| | PIT | Stichtagsabfragen über mehrere Satellites performant | [02](business-vault/02-pit-table.md) |
| Mart | Dimension, Fakt, `_v`-View | jede BI-Anforderung | [01](mart/01-dimensionale-modellierung.md) |
| | Persistierte Marts | große/teure Marts, DirectQuery | [02](mart/02-persistierte-marts.md) |
| | Security | jede publizierte View | [03](mart/03-security-rls-cls.md) |

## Regeln, die für alle Objekte gelten

- **Dateiname = Objektname**, Namen nach [Namenskonventionen](../../01-benutzer/04-namenskonventionen.md).
- **Kopfkommentar** in jedem Modell: Objekt, Quelle, Business Key/FKs, Version mit Datum.
- **automate_dv-Makros** statt handgeschriebenem SQL für Hub, Satellite, Link, Stage; Konfiguration im `yaml_metadata`-Block, der an das Makro übergeben wird.
- **`as_columnstore=false`** und **`create_hash_index`** als Post-Hook auf jedem inkrementellen Vault-Objekt.
- **Jedes Modell in `_…__models.yml`** mit Beschreibung, Spalten, Datentyp und Tests.
- **Kein `--full-refresh`** auf Vault-Tabellen ohne Absprache — Historienverlust.
- Der Lint-Hook des Plugins `dv-toolkit` prüft Pflichtspalten und Namensregeln nach jedem Speichern.

## Schema-YAML (Vorlage)

```yaml
version: 2
models:
  - name: hub_<entity>
    description: "Hub <Entität> — Business Key <BK> aus <Quelle>."
    columns:
      - name: hk_<entity>
        data_type: char(64)
        data_tests: [unique, not_null]
      - name: <bk>
        data_tests: [not_null]
      - name: dss_business_key
        data_tests: [not_null]
  - name: sat_<entity>__<quelle>
    description: "Attribute <Entität> aus <Quelle>, historisiert."
    columns:
      - name: hk_<entity>
        data_tests:
          - not_null
          - relationships: {to: ref('hub_<entity>'), field: hk_<entity>}
      - name: dss_is_current
        data_tests:
          - accepted_values: {values: ['Y', 'N']}
```

Spaltenliste einer bestehenden View für die YAML ermitteln:

```sql
SELECT c.name, t.name AS data_type, c.max_length, c.is_nullable
FROM sys.columns c JOIN sys.types t ON c.user_type_id = t.user_type_id
WHERE c.object_id = OBJECT_ID('stg.<view>') ORDER BY c.column_id;
```
