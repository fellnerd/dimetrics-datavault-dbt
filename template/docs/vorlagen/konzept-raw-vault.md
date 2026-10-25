---
title: "Raw Vault <Konzept>"
aliases:
  - "Raw Vault mart_<konzept>"
tags:
  - architektur/raw-vault
  - typ/inhaltsverzeichnis
konzept: mart_<konzept>
schicht: Raw Vault
schema:
  - vault
quellsysteme:
  - <Quellsystem>
dokumentation: offen
stand: {{date}}
---
[Dokumentation](../../../README.md) › [<Mandant> — Architektur & Projekt](../../00-<mandant>-architektur.md) › [Raw Vault](../00-raw-vault.md)

# Raw Vault <Konzept>

Ein Satz: welche Vault-Objekte hinter dem [Information Mart <Konzept>](../../information-mart/mart_<konzept>/00-mart-<konzept>.md) stehen.

## Allgemein

Fachlicher Hintergrund, Schemas, Detailquellen in `design/`. Stand je Schicht als Tabelle.

## Beladung Datenquelle

Mermaid-Flowchart Quelle → ADF → ADLS → External Table → Staging → Vault, danach Tabelle:

| Quelle | Lieferung | Staging | Ziel im Vault | Details |
|--------|-----------|---------|---------------|---------|
| | | | | [Beladung <Quelle>](01-beladung-<quelle>.md) |

## Objekte

| Objekt | Schema | Art | Schlüssel | Zeilen |
|--------|--------|-----|-----------|-------:|
| | | | | |

## Datenmodell

Mermaid-erDiagram nur mit Beziehungen, dann Links auf die generierten ER-Diagramme und Canvas.

## Modellierung

Warum so modelliert: Business Keys, Satelliten-Schnitt, Sonderobjekte.

## Datenqualität

Bekannte Abweichungen mit Zahlen.

## Security

Grants, personenbezogene Spalten, Verschlüsselung.

## Weitere Seiten

| Seite | Inhalt |
|-------|--------|
| [Beladung <Quelle>](01-beladung-<quelle>.md) | Quelle, Lieferung, Felder, Staging, Hash Keys, Ladestand |
| [Betrieb](02-betrieb.md) | Jobs, Reihenfolge, Nachladen, Full Refresh |
| [Entscheidungen und Befunde](03-entscheidungen-und-befunde.md) | Beschlüsse, Tests, Befunde |
| [Offene Punkte](04-offene-punkte.md) | |

---

◀ [Raw Vault](../00-raw-vault.md) · [Beladung <Quelle>](01-beladung-<quelle>.md) ▶

<!--
Vorlage "Konzept Raw Vault" — Datei 00-mart-<konzept>.md im Ordner raw-vault/mart_<konzept>/
- Alle Abschnitte bleiben stehen. Fehlt etwas: "nicht vorhanden" oder > [!todo] Noch nicht dokumentiert.
- Je Quelle eine Seite 0N-beladung-<quelle>.md; danach Betrieb, Entscheidungen und Befunde, Offene Punkte.
- Betrieb, Entscheidungen und offene Punkte gelten für das ganze Konzept (Raw Vault und Mart).
- ER-Diagramme kommen aus design/ (scripts/sync_design_to_vault.py), nie von Hand ändern.
-->
