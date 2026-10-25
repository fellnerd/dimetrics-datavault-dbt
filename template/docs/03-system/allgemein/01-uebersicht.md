---
title: "Übersicht"
tags:
  - system
---
[Dokumentation](../../README.md) › [Data Vault 2.1 – Systemdokumentation](../00-systemdokumentation.md)

# Übersicht

Dieses Projekt implementiert eine **Data Vault 2.1**-Plattform auf Azure SQL mit dbt Core als wiederverwendbares Template. Ein Git-Repository bedient alle Mandanten; pro Mandant existiert je eine Datenbank für Development, Test und Produktion.

Die konkrete Ausprägung eines Mandanten (Server-, Datenbank- und Quellsystemnamen) ist bewusst nicht Teil dieser Dokumentation — sie steht in der jeweiligen Mandanten-Dokumentation, für den aktuellen Mandanten unter [`04-mandant-architektur/`](../../04-mandant-architektur/00-mandant-architektur.md).

### 1.1 Architektur-Diagramm

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              QUELLSYSTEME                                   │
│  ERP · CRM · Fachanwendungen · Datenbanken · Dateiexporte                   │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼ Azure Data Factory / Synapse Pipeline
┌─────────────────────────────────────────────────────────────────────────────┐
│                         AZURE DATA LAKE STORAGE GEN2                        │
│  Container (Landing Zone): <concept>/<quelle>/<Datei>.parquet               │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼ External Tables (PolyBase / OPENROWSET)
┌─────────────────────────────────────────────────────────────────────────────┐
│                            AZURE SQL DATABASE                               │
├─────────────────────────────────────────────────────────────────────────────┤
│  [stg]            ext_<concept>_<entity>   External Tables auf Parquet      │
│                   <concept>_<entity>       Staging Views (Hashes, Metadaten)│
│                   psa_<concept>_<entity>   PSA (optional, persistiert)      │
│  [vault]          hub_* · sat_* · link_*   Raw Vault, quellübergreifend     │
│  [vault_<concept>]hub_* · sat_* · link_*   Raw Vault je Quellsystem/Domäne  │
│  [mart], [mart_<domain>]                   Dimensionen, Fakten, _v-Views    │
│  [sec]            Funktionen + Rechtetabellen für RLS/CLS                   │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼ Power BI / BI-Werkzeuge (nur mart*-Schemas)
┌─────────────────────────────────────────────────────────────────────────────┐
│                              DBT PROJEKT                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│  dbt Core (Adapter dbt-sqlserver), ausgeführt lokal und auf CI-Runnern      │
│  Packages: automate_dv, dbt_external_tables, dbt_utils                      │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Schichten

| Schicht | Schema | Aufgabe |
|---------|--------|---------|
| Landing Zone | ADLS Gen2 | Rohdateien (Parquet) aus den Quellsystemen, von der Orchestrierung befüllt |
| Staging | `stg` | External Tables + Views mit Hash Keys, Hash Diffs und Metadaten-Spalten — nur Hard Rules |
| Raw Vault | `vault`, `vault_<concept>` | Historisierte Hubs, Satellites, Links — 1:1 zur Quelle, keine Geschäftslogik |
| Business Vault | `mart_<domain>` | Abgeleitete Regeln, Hierarchien, Berechnungen (Soft Rules) |
| Mart | `mart`, `mart_<domain>` | Dimensionen, Fakten und publizierte `_v`-Views für BI — einzige Schicht mit Business-Grants |
