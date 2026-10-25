---
title: "Information Marts"
aliases:
  - "Information Mart"
  - "Information Marts"
tags:
  - architektur/information-mart
  - typ/inhaltsverzeichnis
---
[Dokumentation](../../README.md) › [Mandanten-Architektur & Projekt](../00-mandant-architektur.md)

# Information Marts

Die Sternschemas, auf die das BI-Werkzeug zugreift, je fachlichem Konzept ein Schema `mart_<konzept>`. Jedes Konzept hat einen Ordner `mart_<konzept>/` mit der Übersicht `00-mart-<konzept>.md` (Allgemein, Datenquelle, Objekte und Logik, Security, Datenmodell) und im Unterordner `objekte/` einer Seite je Dimension und Fakt. Vorlagen: [Konzept Information Mart](../../vorlagen/konzept-information-mart.md), [Mart-Objekt](../../vorlagen/mart-objekt.md). Muster: [Objekte anlegen → Mart](../../02-entwickler/04-objekte-anlegen/mart/00-mart.md).

| Konzept | Schema | Quelle | Inhalt | Berechtigte Gruppe | Doku |
|---------|--------|--------|--------|--------------------|------|
| *(Konzept verlinken)* | `mart_<konzept>` | | | `<gruppen-prefix>-<bereich>-ro` | offen |

Gemeinsam genutzte Dimensionen (z. B. `dim_date_v`) hier nennen. Die Ansicht „Mart-Objekte“ der [Base](../00-mandant-architektur.base) listet alle Objektseiten mit Schema, Art und Grain.

Die ER-Diagramme (`mart_<konzept>/er-mart-<konzept>.md`) sind Kopien aus `design/mart/` und werden mit `python3 scripts/sync_design_to_vault.py` aktualisiert.
