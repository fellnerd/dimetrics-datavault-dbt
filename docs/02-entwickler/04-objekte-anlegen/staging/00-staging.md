---
title: "Staging"
aliases:
  - "Staging"
tags:
  - entwickler/staging
  - typ/inhaltsverzeichnis
---
[Dokumentation](../../../README.md) › [Data Vault 2.1 – Developer Guide](../../00-entwicklerhandbuch.md) › [Objekte anlegen](../00-objekte-anlegen.md)

# Staging

Die Staging-Schicht (Schema `stg`) macht Quelldateien als Tabellen lesbar und berechnet alles, was der Vault braucht: Hash Keys, Hash Diffs und `dss_*`-Metadaten. Sie verändert die Daten fachlich nicht (nur Hard Rules: Typ, Format, Trimmen, NULL-Platzhalter).

```
Landing Zone (Parquet) ─► ext_<concept>_<entity> ─► [<concept>_<entity>_dedup] ─► <concept>_<entity> ─► Vault
                           External Table            optionale Vorbereitung          Staging View
                           ─► psa_<concept>_<entity>  (optional, inkrementelle Kopie)
```

| # | Objekt | Materialisierung | Wann |
|---|--------|------------------|------|
| 1 | [External Table](01-external-table.md) | External Table (PolyBase) | jede Quelldatei |
| 2 | [Staging View](02-staging-view.md) | View | jede Quelle, die in den Vault geht |
| 3 | [PSA](03-psa.md) | Incremental | große Dateien, mehrere Konsumenten, instabile Landing Zone |

Staging Views lesen bei jedem Zugriff live die Parquet-Dateien. Deshalb laufen ihre Tests nicht in der Merge-Request-Validierung, sondern nachts ([Tests](../../05-tests.md)).
