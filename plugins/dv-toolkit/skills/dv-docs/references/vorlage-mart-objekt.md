---
title: "<objekt>"
aliases:
  - "<fachlicher Name>"
tags:
  - architektur/information-mart
  - typ/objekt
objekt: <objekt>
schema: mart_<konzept>
art: Dimension
materialisierung: view
grain: <eine Zeile je …>
quellen:
  - <vault_objekt>
zeilen:
stand: {{date}}
---
[Dokumentation](../../../../README.md) › [<Mandant> — Architektur & Projekt](../../../00-<mandant>-architektur.md) › [Information Marts](../../00-information-mart.md) › [<Konzept>](../00-mart-<konzept>.md)

# <objekt>

## Allgemein

Was eine Zeile ist, wofür das Objekt gedacht ist. Link auf den Code: [<objekt>.sql](../../../../../models/mart/<konzept>/<objekt>.sql).

## Attribute

| Spalte | Typ | Bedeutung | Herkunft |
|--------|-----|-----------|----------|
| | | | |

## Funktion und Logik

Joins, Filter, Berechnungen, Inkrement-Logik. Nur was man braucht, um eine Zahl nachzuvollziehen.

## Abfragebeispiele

```sql
-- die ein bis drei wichtigsten Abfragen
```

## Besonderheiten

Keine.

## Security

Kein eigener Grant. Lesbar über den View-Grant auf `mart_<konzept>` ([Security](../00-mart-<konzept>.md)). RLS: nicht vorhanden.

---

◀ [vorheriges Objekt](…) · [Übersicht](../00-mart-<konzept>.md) · [nächstes Objekt](…) ▶

<!--
Vorlage "Mart-Objekt" — Ablage information-mart/mart_<konzept>/objekte/, Dateiname = Objektname, z. B. dim_kunde_v.md (Ausnahme von der kebab-case-Regel)
- Alle sechs Abschnitte bleiben stehen; "Keine." bzw. "nicht vorhanden", wenn es nichts gibt.
- Persistierte Objekte (Tabelle + _v-View) bekommen eine gemeinsame Seite unter dem Namen der View.
- Herkunft: Vault-Objekt.Spalte, bei Umbenennung mit ← auf die Quellspalte.
- Properties füllen, sie speisen die Base im Architektur-Ordner (Ansicht "Mart-Objekte").
-->
