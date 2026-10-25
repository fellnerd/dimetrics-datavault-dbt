---
title: "Information Mart <Konzept>"
aliases:
  - "mart_<konzept>"
tags:
  - architektur/information-mart
  - typ/inhaltsverzeichnis
konzept: mart_<konzept>
schicht: Information Mart
schema: mart_<konzept>
quellsysteme:
  - <Quellsystem>
dokumentation: offen
stand: {{date}}
---
[Dokumentation](../../../README.md) › [<Mandant> — Architektur & Projekt](../../00-<mandant>-architektur.md) › [Information Marts](../00-information-mart.md)

# Information Mart <Konzept>

Ein Satz: was der Mart abbildet. Schema `mart_<konzept>`, Modelle unter [`models/mart/<konzept>/`](../../../../models/mart/<konzept>/). Beladung: [Raw Vault <Konzept>](../../raw-vault/mart_<konzept>/00-mart-<konzept>.md).

## Allgemein

Fachlicher Zweck, Zielgruppe, Konsumenten (Power BI, Export). Stand je Umgebung als Tabelle: Objekt, Zeilen, Zustand.

## Datenquelle

Mermaid-Flowchart Vault-Objekte → Mart-Objekte, danach Tabelle:

| Mart-Objekt | liest aus | Verknüpfung |
|-------------|-----------|-------------|
| | | |

## Objekte und Logik

| Objekt | Art | Grain | Materialisierung | Zeilen |
|--------|-----|-------|------------------|-------:|
| | | | | |

Regeln für den ganzen Mart: Schlüssel, Datum, Filter, Statuslogik, welche Objekte Power BI liest.

## Security

| Ebene | Umsetzung |
|-------|-----------|
| OLS | |
| RLS | nicht vorhanden |
| CLS, Verschlüsselung | nicht vorhanden |

## Datenmodell

Mermaid-Übersicht des Sterns.

Dimensionen

- [dim_<x>_v](objekte/dim_<x>_v.md): Kurzbeschreibung

Fakten

- [fakt_<x>_v](objekte/fakt_<x>_v.md): Kurzbeschreibung

Alle Spalten und Beziehungen: [ER-Diagramm Mart <Konzept>](er-mart-<konzept>.md).

---

◀ [Information Marts](../00-information-mart.md) · [erstes Objekt](objekte/dim_<x>_v.md) ▶

<!--
Vorlage "Konzept Information Mart" — Datei 00-mart-<konzept>.md im Ordner information-mart/mart_<konzept>/
- Alle fünf Abschnitte bleiben stehen. Fehlt etwas: "nicht vorhanden" (gibt es nicht) oder
  > [!todo] Noch nicht dokumentiert (gibt es, ist aber nicht beschrieben).
- Je Objekt eine Seite nach Vorlage "Mart-Objekt" im Unterordner objekte/, Dateiname = Objektname (objekte/dim_kunde_v.md).
- dokumentation: offen | teilweise | vollständig
- Konzept im Index ../00-information-mart.md eintragen, Changelog-Zeile.
-->
