---
title: "Data Vault 2.1 – Systemdokumentation"
aliases:
  - "Systemdokumentation"
  - "Data Vault 2.1 - Systemdokumentation"
tags:
  - system
  - typ/inhaltsverzeichnis
---
[Dokumentation](../README.md)

# Data Vault 2.1 – Systemdokumentation

> **Projekt:** Data Vault 2.1 Plattform auf Azure SQL mit dbt Core
> **Zielgruppe:** Architekten, Betrieb, Entwickler
> **Übersicht als Tabelle:** [Systemdokumentation (Base)](00-systemdokumentation.base)

## Allgemein

1. [Übersicht](allgemein/01-uebersicht.md) — Architektur und Datenfluss
2. [Komponenten](allgemein/02-komponenten.md) — Azure-Dienste, dbt, Pakete, Schemas
3. [Datenmodell](allgemein/03-datenmodell.md) — Objekttypen, Hash-Konfiguration, alle `dss_*`-Spalten
4. [Umgebungen & Targets](allgemein/04-umgebungen-targets.md)
5. [Dateistruktur](allgemein/05-dateistruktur.md)
6. [Konfiguration](allgemein/06-konfiguration.md) — `dbt_project.yml`, `vars`, Hooks
7. [Sicherheit](allgemein/07-sicherheit.md) — Überblick, Details unter Security
8. [Erweiterung](allgemein/08-erweiterung.md) — neue Quellen, Domänen, Mandanten
9. [Monitoring & Troubleshooting](allgemein/09-monitoring-troubleshooting.md)
10. [CI/CD Pipeline](allgemein/10-ci-cd-pipeline.md) — Jobs, Schutzmechanismen, ADF-Übergabe
11. [Wiederverwendbare Macros](allgemein/11-wiederverwendbare-macros.md)

## Security

[Security: Berechtigungen im Data Vault](security/00-security.md) — sec-Schema, OLS,
RLS dimensional, Berechtigung vergeben, neues Objekt absichern, Verifizieren, CLS,
Betrieb, Fallstricke.

## Siehe auch

- Änderungen: [Changelog](../changelog.md)
- Arbeitsabläufe: [Entwicklerhandbuch](../02-entwickler/00-entwicklerhandbuch.md),
  [Deployment Workflow](../02-entwickler/06-deployment-workflow.md)
- Konkrete Umgebung, Quellen und Diagramme: [Projektspezifische Dokumentation](../04-mandant-architektur/00-mandant-architektur.md)
