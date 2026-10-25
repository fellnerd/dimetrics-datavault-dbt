---
title: "Quellsysteme"
aliases:
  - "Quellsysteme"
tags:
  - architektur/quellsysteme
  - typ/inhaltsverzeichnis
---
[Dokumentation](../../README.md) › [Mandanten-Architektur & Projekt](../00-mandant-architektur.md)

# Quellsysteme

Je Quellsystem eine Notiz `<quelle>.md`:

| Abschnitt | Inhalt |
|-----------|--------|
| Herkunft | System, Verantwortliche, Lieferweg (ADF, Export), Frequenz |
| Landing Zone | Pfad im Container, Dateiformat, Vollabzug oder Delta |
| Tabellen | External Table ↔ Staging View ↔ Vault-Objekte |
| Business Keys | je Entität, Eindeutigkeit geprüft, Normalisierung (Cast, Trim) |
| Besonderheiten | Dubletten, Sonderwerte, Zeitzonen, reservierte Wörter |
| Offene Fragen | an den Fachbereich |

| Quelle | Record Source | Concept | Stand |
|--------|---------------|---------|-------|
| <Quelle> | `<mandant>_<quelle>` | `<concept>` | geplant |
