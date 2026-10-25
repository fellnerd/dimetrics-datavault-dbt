---
title: "Data Vault 2.1 – Developer Guide"
aliases:
  - "Entwicklerhandbuch"
  - "Developer Guide"
  - "Data Vault 2.1 - Developer Guide"
tags:
  - entwickler
  - typ/inhaltsverzeichnis
---
[Dokumentation](../README.md)

# Data Vault 2.1 – Developer Guide

> **Projekt:** Data Vault 2.1 Plattform auf Azure SQL mit dbt Core und automate_dv
> **Zielgruppe:** Entwickler, Data Engineers
> **Übersicht als Tabelle:** [Entwicklerhandbuch (Base)](00-entwicklerhandbuch.base)
> **Voraussetzung:** Umgebung eingerichtet ([Erste Schritte](../01-benutzer/05-erste-schritte.md))

## Inhalt

1. [Data Vault 2.1 Leitfaden](01-data-vault-leitfaden.md) — welches Objekt wann, Entscheidungslogik
2. [Quick Reference](02-quick-reference.md) — Befehle, Selektoren, wichtige Dateien, Macros
3. [Projektstruktur](03-projektstruktur.md) — Ordner, Schemas, Konventionen
4. [Objekte anlegen](04-objekte-anlegen/00-objekte-anlegen.md) — Ablauf und Vorlagen je Objekttyp
   - [Staging](04-objekte-anlegen/staging/00-staging.md): External Table, Staging View, PSA
   - [Raw Vault](04-objekte-anlegen/raw-vault/00-raw-vault.md): Hub, Satellite, Link, Transaction Link, Effectivity/DC/MA-Satellite, Reference Table, Attribut hinzufügen
   - [Business Vault](04-objekte-anlegen/business-vault/00-business-vault.md): Current View, PIT
   - [Mart](04-objekte-anlegen/mart/00-mart.md): Dimensionale Modellierung (SCD1/SCD2), persistierte Marts, Security
5. [Tests](05-tests.md) — Pflichttests je Objekttyp, Singular Tests, Nightly
6. [Deployment Workflow](06-deployment-workflow.md) — Git, Merge Request, Freigaben, Pipelines, Release
7. [Troubleshooting](07-troubleshooting.md)
8. [Checklisten](08-checklisten.md)

## Siehe auch

| Thema | Wo |
|-------|-----|
| Namen von Schemas, Tabellen, Spalten, Dateien | [Namenskonventionen](../01-benutzer/04-namenskonventionen.md) |
| Datenmodell, Hash-Konfiguration, `dss_*` im Detail | [Systemdokumentation → Datenmodell](../03-system/allgemein/03-datenmodell.md) |
| Alle Macros | [Wiederverwendbare Macros](../03-system/allgemein/11-wiederverwendbare-macros.md) |
| Pipelines im Detail | [CI/CD Pipeline](../03-system/allgemein/10-ci-cd-pipeline.md) |
| Berechtigungen (OLS/RLS/CLS) | [Security](../03-system/security/00-security.md) |
| Konkrete Quellen, Domänen, ER-Diagramme | [Projektspezifische Dokumentation](../04-mandant-architektur/00-mandant-architektur.md) |
| Entscheidungen, Fallstricke mit Messwerten | [Lessons Learned](../lessons-learned/00-lessons-learned.md) |
| Generierte Modelldoku mit Lineage | `dbt docs generate && dbt docs serve` |
| Claude-Code-Plugin `dv-toolkit` | Skills `dv-patterns`, `dv-staging`, `dv-marts`, `dv-security`, `dv-design-sync`, `dv-docs`; Agents `staging-engineer`, `vault-architect`, `mart-architect` |
