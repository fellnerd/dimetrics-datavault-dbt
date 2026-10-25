---
title: "Raw Vault"
aliases:
  - "Raw Vault"
tags:
  - architektur/raw-vault
  - typ/inhaltsverzeichnis
---
[Dokumentation](../../README.md) › [Mandanten-Architektur & Projekt](../00-mandant-architektur.md)

# Raw Vault

Hubs, Links und Satelliten, gegliedert nach dem Information Mart, den sie beliefern. Jedes Konzept hat einen Ordner `mart_<konzept>/` mit der Übersicht `00-mart-<konzept>.md` (Allgemein, Beladung Datenquelle, Objekte, Datenmodell, Modellierung, Datenqualität, Security), einer Beladungsseite je Quelle sowie Betrieb, Entscheidungen und offenen Punkten. Vorlagen: [Konzept Raw Vault](../../vorlagen/konzept-raw-vault.md), [Beladung Quelle](../../vorlagen/beladung-quelle.md). Muster je Objekttyp: [Objekte anlegen → Raw Vault](../../02-entwickler/04-objekte-anlegen/raw-vault/00-raw-vault.md).

| Konzept | Schemas | Quellen | Doku |
|---------|---------|---------|------|
| *(Konzept verlinken)* | `vault` | | offen |

## Quellen

Je Quelle eine Beladungsseite im Konzeptordner (Lieferung, Landing Zone, Felder, Staging, Business Keys, Hash Keys, Ladestand). Besonderheiten und offene Fragen an den Fachbereich stehen auf den Seiten Entscheidungen und Befunde bzw. Offene Punkte des Konzepts.

| Quelle | Record Source | Konzept | Beladung | Stand |
|--------|---------------|---------|----------|-------|
| <Quelle> | `<mandant>_<quelle>` | `mart_<konzept>` | *(Link auf 0N-beladung-<quelle>.md)* | geplant |

## Konzeptübergreifend

Hubs, die mehrere Konzepte nutzen (z. B. Kunde, Adresse), und Gesamtdiagramme liegen unter `common/`.

## ER-Diagramme

Die `er-*.md`-Notizen sind Kopien aus `design/raw-vault/` (Model First), erzeugt mit `python3 scripts/sync_design_to_vault.py` (Skill `dv-design-sync`), nie von Hand ändern.

| Konzept | Diagramme |
|---------|-----------|
| *(Konzept)* | *(Links auf `mart_<konzept>/er-*.md`)* |
