---
title: "Schulung"
aliases:
  - "Schulung"
  - "Schulungsunterlagen"
tags:
  - schulung
  - typ/inhaltsverzeichnis
---
[Dokumentation](../README.md)

# Schulung

Schulungsunterlagen zur Data-Vault-Plattform — Konzept, Handouts und Praxisfälle.

## Inhalt

Empfohlene Gliederung (je Handout ein Unterordner mit eigenem `README.md` als Inhaltsverzeichnis):

| Dokument | Beschreibung |
|----------|--------------|
| `schulungsplan.md` | Schulungskonzept: Zielgruppen, Modul-Baukasten, Use Cases, Terminblöcke, Aufwand |
| `grundlagen-architektur/` | Handout: Data Vault 2.1 Grundlagen und Architektur der Datenplattform |
| `neues-business-objekt/` | Praxis-Durchstich: von der Quelldatei über Staging und Raw Vault bis zur Dimension |
| `use-cases/` | Ausgearbeitete Fallbeispiele auf realen Quellen, datiert (`JJJJ-MM-TT-thema.md`) |

## Empfohlene Reihenfolge

1. Grundlagen & Architektur — gemeinsames Vokabular und Gesamtbild (Basis: [Benutzerhandbuch](../01-benutzer/00-benutzerhandbuch.md), [Systemübersicht](../03-system/allgemein/01-uebersicht.md))
2. Neues Business-Objekt erstellen — praktische Umsetzung Schritt für Schritt (Basis: [Neue Entity erstellen](../02-entwickler/04-objekte-anlegen/00-objekte-anlegen.md))
3. Use Cases — Anwendung auf die Quellen des Projekts

> [!TIP]
> Handouts und Kapitel über *Vorlage einfügen* mit den Vorlagen aus `vorlagen/` anlegen und Tags `schulung/<handout>` vergeben — dann erscheinen sie in der Base [Dokumentation](../uebersichten/dokumentation.base) und in der Graph-Farbe der Schulung.
