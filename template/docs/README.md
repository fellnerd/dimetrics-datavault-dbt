---
title: "Start"
aliases:
  - "Start"
  - "Dokumentation"
tags:
  - typ/inhaltsverzeichnis
---
# Dokumentation

Einstiegspunkt für die Projektdokumentation. Fachsprache ist Deutsch. Jedes Handbuch ist ein Ordner mit einem Inhaltsverzeichnis `00-<ordner>.md` (in Obsidian oben), einer Base `00-<ordner>.base` (tabellarische Übersicht mit Filteransichten) und einer Datei je Kapitel mit Breadcrumb und Vor-/Zurück-Navigation.

## Handbücher

Die Handbücher `01-` bis `03-`, `lessons-learned/` und `schulung/` sind bewusst mandantenunabhängig formuliert (Platzhalter `<mandant>`, `<concept>`, `<entity>`). Konkrete Server-, Datenbank- und Quellsystemnamen stehen in `04-mandant-architektur/`.

| Bereich | Zielgruppe | Inhalt |
|---------|-----------|--------|
| [01 Benutzer](01-benutzer/00-benutzerhandbuch.md) | Analysten, Endanwender, Einsteiger | Grundkonzepte, Spalten, Namenskonventionen, Installation, dbt-Befehle, Daten prüfen, Berechtigungen, FAQ, Glossar |
| [02 Entwickler](02-entwickler/00-entwicklerhandbuch.md) | Entwickler, Data Engineers | DV-Leitfaden, [Objekte anlegen](02-entwickler/04-objekte-anlegen/00-objekte-anlegen.md) (Staging, Raw Vault, Business Vault, Mart), Tests, Deployment Workflow, Checklisten |
| [03 System](03-system/00-systemdokumentation.md) | Architekten, Betrieb | Komponenten, Datenmodell, Umgebungen, Konfiguration, CI/CD, Macros, [Security](03-system/security/00-security.md) |
| [04 Mandanten-Architektur](04-mandant-architektur/00-mandant-architektur.md) | alle | **Projektspezifisch:** je fachlichem Konzept (`mart_<konzept>`) Information Mart mit einer Seite je Dimension und Fakt sowie Raw Vault mit Beladung je Quelle, Betrieb und offenen Punkten; Business Vault, Projektdokumentation |
| [Lessons Learned](lessons-learned/00-lessons-learned.md) | alle | Entscheidungen, Fallstricke, Probleme & Lösungen — mit Messwerten |
| [Schulung](schulung/00-schulung.md) | Schulungsteilnehmende | Gliederung für Schulungsplan, Handouts, Use Cases |
| [Changelog](changelog.md) | alle | Änderungen an Plattform und Dokumentation, neueste zuerst |
| [Model Architecture](MODEL_ARCHITECTURE.md) | Entwickler | Architekturmodell (Schemas, Layer, Hash-Berechnung) als Einzeldokument |

## Einstieg

| Wenn du … | dann hier starten |
|-----------|-------------------|
| die Plattform verstehen willst | [Grundkonzepte](01-benutzer/02-grundkonzepte.md) · [Systemübersicht](03-system/allgemein/01-uebersicht.md) |
| deinen Rechner einrichten willst | [Erste Schritte](01-benutzer/05-erste-schritte.md) |
| Daten abfragen oder prüfen willst | [Daten prüfen](01-benutzer/08-daten-pruefen.md) · [Wichtige Spalten](01-benutzer/03-wichtige-spalten-verstehen.md) |
| eine neue Quelle anbinden willst | [Objekte anlegen](02-entwickler/04-objekte-anlegen/00-objekte-anlegen.md) |
| eine Änderung ausliefern willst | [Deployment Workflow](02-entwickler/06-deployment-workflow.md) |
| einen Namen suchst | [Namenskonventionen](01-benutzer/04-namenskonventionen.md) |
| jemandem eine Berechtigung geben willst | [Berechtigung vergeben](03-system/security/05-berechtigung-vergeben.md) |
| Erfahrungen und Messwerte suchst | [Lessons Learned](lessons-learned/00-lessons-learned.md) |
| den Projektstand suchst | [Projektspezifische Dokumentation](04-mandant-architektur/00-mandant-architektur.md) |
| ein Problem debuggst | [Troubleshooting](01-benutzer/11-troubleshooting.md) · [Troubleshooting Entwicklung](02-entwickler/07-troubleshooting.md) |

## Namenskonvention der Doku

- **Ordner und Dateien:** Kleinschreibung, `kebab-case`, keine Unterstriche, Leerzeichen oder Umlaute im Dateinamen. Ausnahmen: Konzeptordner heissen wie das Mart-Schema (`mart_<konzept>/`), Objektseiten im Unterordner `objekte/` wie das Objekt (`objekte/dim_kunde_v.md`), damit Suche und Links den Namen aus dem Code treffen.
- **Nummerierung:** Handbuch-Ordner `01-` bis `04-`, Kapitel mit zweistelligem Präfix in Lesereihenfolge; das Inhaltsverzeichnis heißt `00-<ordner>.md`.
- **Assets** im Unterordner `assets/` des jeweiligen Bereichs.
- **Datierte Dokumente** (Use Cases, Meetings, Analysen): `JJJJ-MM-TT-<thema>.md`.
- **Kein Versions- oder Statussuffix** (`_v2`, `_final`) — der Stand steht im Dokument bzw. im [Changelog](changelog.md), die Historie in Git.
- Objektnamen der Plattform: [Namenskonventionen](01-benutzer/04-namenskonventionen.md).

## Arbeiten mit Obsidian

Dieser Ordner (`docs`) ist ein Obsidian-Vault (*Ordner als Vault öffnen*). Damit die Doku in Obsidian **und** in GitLab/GitHub funktioniert:

- **Links:** nur relative Markdown-Links (`[Text](../ordner/datei.md)`), keine `[[Wikilinks]]`. Obsidian zieht Links beim Umbenennen oder Verschieben automatisch nach.
- **Properties:** jede Notiz trägt `title` (Anzeigename in Explorer, Graph und Tabs über das Plugin „Front Matter Title“) und `tags` für ihren Bereich (`benutzer`, `entwickler/raw-vault`, `system/security`, `architektur/raw-vault` …) sowie bei Bedarf einen Typ (`typ/inhaltsverzeichnis`, `typ/nachschlagen`, `typ/glossar`, `typ/faq`, `typ/troubleshooting`, `typ/checkliste`, `typ/changelog`, `typ/er-diagramm`, `typ/objekt`). Inhaltsverzeichnisse haben `aliases`. Konzeptseiten tragen zusätzlich `konzept`, `schicht`, `schema`, `quellsysteme`, `dokumentation`, `stand`; Objektseiten `objekt`, `schema`, `art`, `materialisierung`, `grain`, `quellen`, `zeilen`, `stand`. Daraus speisen sich die Ansichten „Konzepte“ und „Mart-Objekte“ der [Architektur-Base](04-mandant-architektur/00-mandant-architektur.base).
- **Hinweise:** als Callouts (`> [!TIP]`, `> [!WARNING]`, `> [!IMPORTANT]`, `> [!NOTE]`). Fehlende Doku markiert `> [!todo] Noch nicht dokumentiert`; die Suche nach `[!todo]` zeigt alle Lücken. Gibt es etwas nicht (z. B. keine RLS), steht dort „nicht vorhanden“.
- **Bases:** je Handbuch `00-<ordner>.base` (Ansichten: Kapitel, nach Ordner, nach Tag, Unterbereiche, Nachschlagen, zuletzt geändert, wenig verlinkt); über den ganzen Vault [`dokumentation.base`](uebersichten/dokumentation.base) und [`design-diagramme.base`](uebersichten/design-diagramme.base).
- **Design-Diagramme:** die `er-*.md`-Notizen unter `04-mandant-architektur/raw-vault/` und `information-mart/` erzeugt `python3 scripts/sync_design_to_vault.py` aus `design/` (Konfiguration `design/vault-sync.json`) — nicht von Hand ändern.
- **Neue Kapitel:** über *Vorlage einfügen* mit den Vorlagen aus `vorlagen/`; im Inhaltsverzeichnis verlinken, Eintrag im Changelog.
- **Graph und Explorer:** Farbe je Bereich — Benutzer blau, Entwickler grün, System ocker, Architektur rot, Schulung türkis, Lessons Learned violett. Startseite und Changelog sind im Graph ausgeblendet.
- **Gemeinsame Einstellungen** (CSS-Snippet `datavault`, Graph, Lesezeichen, Vorlagen, Plugins) liegen versioniert in `.obsidian/`; `workspace*.json` ist von Git ausgenommen.
- **Claude Code:** Skill `dv-docs` des Plugins `dv-toolkit` kennt diese Struktur; die Agents pflegen Doku und Changelog bei jeder Modelländerung mit.
