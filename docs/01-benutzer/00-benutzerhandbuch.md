---
title: "Data Vault 2.1 – Benutzer-Dokumentation"
aliases:
  - "Benutzerhandbuch"
  - "Data Vault 2.1 - Benutzer-Dokumentation"
tags:
  - benutzer
  - typ/inhaltsverzeichnis
---
[Dokumentation](../README.md)

# Data Vault 2.1 – Benutzer-Dokumentation

> **Projekt:** Data Vault 2.1 Plattform auf Azure SQL mit dbt Core
> **Zielgruppe:** Analystinnen und Analysten, Endanwender, Einsteiger in die Entwicklung
> **Übersicht als Tabelle:** [Benutzerhandbuch (Base)](00-benutzerhandbuch.base)

## Inhalt

### Verstehen

1. [Einführung: Was ist Data Vault?](01-einfuehrung-was-ist-data-vault.md) — wozu die Plattform dient
2. [Grundkonzepte](02-grundkonzepte.md) — Hub, Satellite, Link, PIT, Ghost Records
3. [Wichtige Spalten verstehen](03-wichtige-spalten-verstehen.md) — alle `hk_`/`hd_`/`dss_`-Spalten und Mart-Schlüssel
4. [Namenskonventionen](04-namenskonventionen.md) — Schemas, Tabellen, Views, Spalten, Dateien, Branches

### Arbeiten

5. [Erste Schritte](05-erste-schritte.md) — Installation (Python, dbt, Pakete), Verbindung, Targets
6. [dbt-Befehle](06-dbt-befehle.md) — Bauen, Testen, Selektion, External Tables, Betrieb
7. [Neue Entity hinzufügen](07-neue-entity-hinzufuegen.md) — Kurzablauf Quelle → Hub/Satellite/Link
8. [Daten prüfen](08-daten-pruefen.md) — Zählungen, Eindeutigkeit der Business Keys, Historie, Waisen
9. [Datenzugriff & Berechtigungen](09-datenzugriff-berechtigungen.md) — OLS/RLS/CLS, Zugriff beantragen

### Nachschlagen

10. [Best Practices](10-best-practices.md)
11. [Troubleshooting](11-troubleshooting.md)
12. [Häufige Fragen (FAQ)](12-haeufige-fragen-faq.md)
13. [Glossar](13-glossar.md)

Änderungen an Plattform und Dokumentation: [Changelog](../changelog.md).
