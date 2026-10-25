---
title: "Mart"
aliases:
  - "Information Mart"
  - "Mart"
tags:
  - entwickler/mart
  - typ/inhaltsverzeichnis
---
[Dokumentation](../../../README.md) › [Data Vault 2.1 – Developer Guide](../../00-entwicklerhandbuch.md) › [Objekte anlegen](../00-objekte-anlegen.md)

# Mart

Der Information Mart übersetzt den Vault in Star Schemas für BI-Tools. Schema `mart` (geteilte Dimensionen, `models/mart/_common/`) und `mart_<domain>` (`models/mart/<domain>/`).

```
Raw Vault ─► Current View / PIT ─► dim_* / fakt_* (Table) ─► dim_*_v / fakt_*_v (View, Security) ─► Power BI
```

| # | Kapitel | Inhalt |
|---|---------|--------|
| 1 | [Dimensionale Modellierung](01-dimensionale-modellierung.md) | Dimensionen, Fakten, Surrogate Keys, SCD1/SCD2, Pflichtspalten, Hausmuster Tabelle + `_v`-View |
| 2 | [Persistierte Marts](02-persistierte-marts.md) | Wann Tabelle/Incremental statt View, Indizes |
| 3 | [Security (RLS/CLS)](03-security-rls-cls.md) | Die vier Regeln für jede publizierte View |

Grundsätze:

- **Nur `_v`-Views sind Schnittstelle** für BI-Tools; sie werden per Hook berechtigt.
- **Keine eigene Historisierung im Mart.** Historie kommt aus dem Vault (Satellites, PIT).
- **Jeder Mart ist aus dem Vault neu baubar** — Full Refresh im Mart ist unkritisch.
- Mart-Diagramme: `design/mart/er-mart-<domain>.mmd`, im Vault unter [Information Mart](../../../04-mandant-architektur/information-mart/00-information-mart.md).
