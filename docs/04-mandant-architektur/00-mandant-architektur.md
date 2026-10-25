---
title: "Mandanten-Architektur & Projekt"
aliases:
  - "Mandanten-Architektur"
  - "Projektspezifische Dokumentation"
tags:
  - architektur
  - typ/inhaltsverzeichnis
---
[Dokumentation](../README.md)

# Mandanten-Architektur & Projekt

Alles, was nur für dieses Projekt gilt. Die Handbücher [Benutzer](../01-benutzer/00-benutzerhandbuch.md), [Entwickler](../02-entwickler/00-entwicklerhandbuch.md) und [System](../03-system/00-systemdokumentation.md) bleiben mandantenneutral. Tabellarische Übersicht: [Architektur (Base)](00-mandant-architektur.base).

> [!TIP]
> Ordner beim Projektstart umbenennen in `04-<kunde>-architektur` — **in Obsidian** (Rechtsklick → Umbenennen), dann werden alle Links automatisch angepasst. Titel und Aliase dieser Notiz sowie `design/vault-sync.json` entsprechend setzen.

## Projekt

| Dokument | Inhalt |
|----------|--------|
| [Projektdokumentation](projektdokumentation/00-projektdokumentation.md) | Ziel, Phasen, Stand, offene Punkte, Entscheidungslogbuch |
| [Quellsysteme](quellsysteme/00-quellsysteme.md) | angebundene Systeme, Landing Zone, Business Keys, Besonderheiten |
| `business-case.md` | fachlicher Nutzen (anlegen) |
| `meetings/` | Protokolle `JJJJ-MM-TT-<thema>.md` (anlegen) |
| `assets/` | Architekturdiagramm, PDFs |

## Datenmodell

| Schicht | Dokument | Inhalt |
|---------|----------|--------|
| Raw Vault | [Raw Vault](raw-vault/00-raw-vault.md) | ER-Diagramme je Quelle/Domäne |
| Business Vault | [Business Vault](business-vault/00-business-vault.md) | Current Views, PIT, fachliche Regeln |
| Information Mart | [Information Mart](information-mart/00-information-mart.md) | Star Schemas je Domäne |

Diagramme entstehen in `design/` (Model First, Skill `dv-design-sync`) und werden mit `python3 scripts/sync_design_to_vault.py` in die Ordner gespiegelt (Konfiguration `design/vault-sync.json`, Vorlage im Kopf des Skripts).

## Umgebung

| Was | Wert |
|-----|------|
| SQL Server | `<sql-server>.database.windows.net` |
| Datenbanken | `<datenbank>-dev`, `<datenbank>-test`, `<datenbank>` |
| dbt-Targets | `<mandant>-dev`, `<mandant>-test`, `<mandant>` |
| Storage / Landing Zone | `<storage-account>` / Container `<container>` |
| Pipeline | GitHub Actions bzw. GitLab CI, Repository `<org>/<repo>` |
| Entra-Gruppen | `<gruppen-prefix>-<bereich>-ro`, `…-full-ro` |
