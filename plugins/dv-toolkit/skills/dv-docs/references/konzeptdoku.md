# Konzeptdokumentation: Information Mart und Raw Vault

Gilt für `04-<mandant>-architektur/information-mart/` und `raw-vault/`. Ablage, Notizformat, Changelog und Schreibstil regelt die [SKILL.md](../SKILL.md); hier steht, wie ein fachliches Konzept dokumentiert wird.

Jedes Konzept wird zweimal beschrieben: im **Information Mart** für Nutzer (was bedeutet eine Zahl, wie entsteht sie, was darf ich sehen) und im **Raw Vault** für Betrieb und Entwicklung (woher kommen die Daten, wie werden sie geladen, was ist offen). Beide Seiten haben eine feste Kapitelstruktur, die immer vollständig ist. ER-Diagramme in `design/` und ihr Sync gehören zu `dv-design-sync`, Canvas-Darstellungen zu `dv-er-diagram`.

## Zielstruktur

```
<vault>/04-<mandant>-architektur/
├── 00-<mandant>-architektur.md            Index: Tabellen Information Marts / Raw Vault mit Doku-Stand
├── information-mart/
│   ├── 00-information-mart.md             Konzepttabelle
│   └── mart_<konzept>/                    Ordner heisst wie das Schema
│       ├── 00-mart-<konzept>.md           Allgemein · Datenquelle · Objekte und Logik · Security · Datenmodell
│       ├── objekte/<objekt>.md            je Dimension/Fakt, Dateiname = Objektname (dim_kunde_v.md)
│       └── er-mart-<konzept>.md           generiert (design/ → sync_design_to_vault.py)
├── raw-vault/
│   ├── 00-raw-vault.md                    Konzepttabelle, Quellenübersicht, konzeptübergreifende Diagramme
│   ├── common/                            konzeptübergreifende ER-Diagramme (optional)
│   └── mart_<konzept>/
│       ├── 00-mart-<konzept>.md           Allgemein · Beladung Datenquelle · Objekte · Datenmodell ·
│       │                                  Modellierung · Datenqualität · Security · Weitere Seiten
│       ├── 01-beladung-<quelle>.md        je Quelle eine Seite (02-, 03- … bei mehreren Quellen)
│       ├── NN-betrieb.md                  danach in dieser Reihenfolge, gelten für das ganze Konzept
│       ├── NN-entscheidungen-und-befunde.md
│       ├── NN-offene-punkte.md
│       └── er-*.md, *.canvas, *.sql       generierte Diagramme, Canvas, Prüfabfragen
├── business-vault/, projektdokumentation/, meetings/, assets/
```

Der Konzeptname folgt dem Mart-Schema (`mart_telecom` → Ordner `mart_telecom/`, Index `00-mart-telecom.md`), auch auf der Raw-Vault-Seite. Vorlagen: [Konzept Information Mart](vorlage-konzept-information-mart.md), [Mart-Objekt](vorlage-mart-objekt.md), [Konzept Raw Vault](vorlage-konzept-raw-vault.md), [Beladung Quelle](vorlage-beladung-quelle.md). Liegen sie im Vault unter `vorlagen/`, dieselben verwenden.

## Ablauf

1. **Scope klären.** Konzept, Mart-Schema, Modellordner (`models/mart/<konzept>/`, beteiligte `models/raw_vault/**`, `models/staging/**`), Quellsysteme, Vault-Pfad und Mandantenordner. Bestehende Seiten lesen: Gerüst, alte Kapitel, verstreute Notizen (`load/`, `quellsysteme/`, Meetings, Projektdoku).
2. **Fakten aus dem Code holen**, nicht aus der Erinnerung:

   | Quelle | Was daraus in die Doku geht |
   |--------|-----------------------------|
   | `models/mart/<konzept>/*.sql`, `_*.yml` | Grain, Joins (INNER/LEFT und ihre Folgen), Filter, CASE-Mappings, Einheiten, Materialisierung, Inkrement-Logik, Spalten mit Typ und Beschreibung |
   | Raw-Vault-Modelle | `yaml_metadata` (src_pk, src_fk, src_nk, Hashdiff, Payload, CDK, DFK/SFK, Start/Ende), Post-Hooks, eigenes SQL statt Macro und warum |
   | Staging-Views | `hashed_columns` (welche Spalten in welchen Hash), `derived_columns` (Umbenennungen, Konstanten wie `dss_record_source`), Dedup-Views, PSA, Delta-Filter |
   | `sources.yml` | External Table, ADLS-Ordner, Dateiformat |
   | `dbt_project.yml`, `security/`, `macros/security/` | Schemas, `ols_view_grants`, RLS-Prädikate, CLS, Verschlüsselung |
   | CI (`.gitlab-ci.yml`, `.github/workflows/`) | Jobs, Reihenfolge, `--select`, Limits, manuelle Schritte |
   | `design/` | Implementierungspläne, Beschlüsse, ER-Entwürfe (Model First) |
   | bestehende Doku | alles, was nicht im Code steht: Beschlüsse, Befunde, Zahlen, Personen, offene Fragen |

   Zeilenzahlen und Datenstände nur mit Datum und Umgebung (`Stand 6. Oktober 2026 auf <db>-dev`). Aus der bisherigen Doku übernehmen oder mit dem Agent `db-monitor` ermitteln, nie schätzen.
3. **Code schlägt Doku.** Widerspricht eine bestehende Aussage dem Code, die Aussage korrigieren und im Changelog und in der Antwort nennen. Weicht ein ER-Entwurf in `design/` vom gebauten Stand ab, dort korrigieren oder nicht Gebautes als `NICHT GEBAUT` kommentieren, dann den Sync laufen lassen.
4. **Seiten schreiben** nach den Kapitelregeln unten und dem [Schreibstil](schreibstil.md).
5. **Einhängen.** Konzept in `information-mart/00-information-mart.md`, `raw-vault/00-raw-vault.md` und `00-<mandant>-architektur.md` mit Doku-Stand eintragen; Vor-/Zurück-Navigation; in `design/vault-sync.json` je Konzeptordner eine Gruppe (`{"title": "<Konzept>", "index": "00-mart-<konzept>.md"}`), damit die generierten ER-Notizen das Konzept im Breadcrumb zeigen; `python3 scripts/sync_design_to_vault.py`.
6. **Prüfen** mit `python3 <dv-docs>/scripts/check_concept_docs.py <vault>` (Kapitel, Properties, Links, leere Kapitel, Stilmerkmale), dann Changelog-Zeile (Bereich `doku`).

Bestehende Doku umbauen statt neu schreiben: [Migration](migration.md).

## Information Mart

### Übersicht `00-mart-<konzept>.md`

| Kapitel | Inhalt |
|---------|--------|
| Allgemein | Zweck und Fachbegriffe in wenigen Sätzen, Konsumenten (Power BI, Export), Stand je Umgebung als Tabelle (Objekt, Zeilen, Zustand), Warn-Callout bei leeren oder fehlerhaften Objekten, Link auf die offenen Punkte |
| Datenquelle | Mermaid-Flowchart Vault → Mart (ein `subgraph` je Schema), Tabelle *Mart-Objekt / liest aus / Verknüpfung*, Link auf das Raw-Vault-Konzept und die Beladungsseite. Spaltenherkunft gehört auf die Objektseiten |
| Objekte und Logik | Tabelle *Objekt / Art / Grain / Materialisierung / Zeilen* mit Links nach `objekte/`, darunter die Regeln für den ganzen Mart: Schlüsselbildung, Datumsschlüssel, Klassifikationen, Zeitfilter, Statuslogik, welche Objekte Power BI liest |
| Security | Tabelle *Ebene / Umsetzung*: OLS (Gruppe, Schemas, Hook/Skript), Tabellen ohne Grant, RLS, CLS/Verschlüsselung, Personenbezug. Was es nicht gibt, steht als „nicht vorhanden“ da |
| Datenmodell | Mermaid-Übersicht des Sterns, Listen *Dimensionen* und *Fakten* (Link + Halbsatz), gemeinsam genutzte Dimensionen, Link auf das generierte ER-Diagramm. Gibt es kein dimensionales Modell: „nicht vorhanden“ und was stattdessen existiert |

### Objektseite `objekte/<objekt>.md`

| Kapitel | Inhalt |
|---------|--------|
| Allgemein | Was eine Zeile ist, wofür das Objekt gedacht ist, Link auf die `.sql`-Datei(en) |
| Attribute | Tabelle *Spalte / Typ / Bedeutung / Herkunft*; Herkunft als `vault_objekt.spalte`, Umbenennungen mit `←` bis zum Quellfeld, berechnete Spalten mit Formel |
| Funktion und Logik | Joins und was dabei wegfällt, Filter, Mapping-Tabellen, Einheiten, Deduplizierung, Inkrement-Logik (Strategie, Schlüssel, Zeitfenster) |
| Abfragebeispiele | ein bis drei lauffähige T-SQL-Abfragen mit Schema-Präfix, die wichtigsten Fragen an das Objekt; Platzhalter wie `'<vertrag_id>'` statt echter Kundennummern |
| Besonderheiten | Datenlücken, Duplikate, bekannte Abweichungen mit Zahlen, Fallstricke für Nutzer; sonst „Keine.“ |
| Security | Grant-Weg (eigener Grant oder über den Schema-View-Grant), RLS, sensible Spalten |

Ein persistiertes Objekt (Tabelle + `_v`-View) bekommt eine gemeinsame Seite unter dem Namen der View. Properties siehe [Obsidian](obsidian.md); sie speisen die Base-Ansicht „Mart-Objekte“.

## Raw Vault

### Übersicht `00-mart-<konzept>.md`

| Kapitel | Inhalt |
|---------|--------|
| Allgemein | Fachlicher Hintergrund der Quelle(n), Schemas und warum, Detailquellen in `design/`, Stand je Schicht als Tabelle (Lieferung, Staging/PSA, Raw Vault, Mart, Retention, weitere Umgebungen) |
| Beladung Datenquelle | Mermaid-Flowchart Quelle → Pipeline → ADLS → External Table → Staging/PSA → Vault → Mart, Tabelle *Quelle / Lieferung / Staging / Ziel im Vault / Details* mit Link je Beladungsseite |
| Objekte | Tabelle *Objekt / Schema / Art / Schlüssel / Zeilen*, Objekte mit Link auf die `.sql`-Datei; Current Views; Objekte im Schema, die nicht zum Konzept gehören |
| Datenmodell | Mermaid-`erDiagram` nur mit Beziehungen, Links auf die generierten ER-Diagramme und Canvas |
| Modellierung | Warum so modelliert: Business Keys, Hub-Quellen, Satelliten-Schnitt, Sonderobjekte (Effectivity, Multi-Active, Transaction Link), unveränderliche Daten |
| Datenqualität | Geprüfte Eigenschaften und Abweichungen mit Zahlen, Link auf die Befunde |
| Security | Grants auf die Vault-Schemas, personenbezogene Spalten, Verschlüsselung |
| Weitere Seiten | Tabelle der Unterseiten |

### Beladungsseite `0N-beladung-<quelle>.md`

Kapitel: **Quelle** (System, Betreiber, Record Source) · **Lieferungen** (Rhythmus, Voll/Delta, Ordner, Löschverhalten, Schlüssel zwischen Lieferungen) · **Pipelines** (ADF o. ä., Stand, was nicht im Repo liegt) · **Lineage** (Mermaid bis zu den Vault-Objekten) · **Felder** (Tabelle je Lieferung, welche Felder nicht im Vault landen) · **Staging** (Umbenennungen, Konstanten, Tabelle *Hash / gebildet aus / Ziel*, Dedup-Views mit Grund) · **PSA und Delta** (falls vorhanden, sonst „nicht vorhanden“) · **Ladestand** (letzte Ladung, Zeitraum, Lücken; Gantt oder xychart, wenn es hilft) · **Änderungen** (datiert).

### Betrieb, Entscheidungen, offene Punkte

Gelten für das ganze Konzept, also auch für den Mart; die Mart-Seiten verlinken dorthin.

- **Betrieb:** Jobs mit Inhalt und Limit, Ablauf als Flowchart, Nachladen, Full Refresh und wer ihn freigibt, Kontrollabfragen, Retention.
- **Entscheidungen und Befunde:** Timeline, Beschlusstabelle *Thema / Beschluss / Datum*, Tests mit Ergebnis, Korrekturen früherer Annahmen mit Begründung und Zahlen.
- **Offene Punkte:** Tabelle *Nr. / Punkt / abhängig von*, darunter je Punkt ein kurzer Abschnitt mit Ursache und nächstem Schritt; zum Schluss „Nicht gebaut“, falls Geplantes entfallen ist.

## Gerüst und Doku-Stand

- Ein Konzept ohne Inhalt bekommt oben `> [!todo] Gerüst` mit Link auf Vorlage und ein fertiges Beispielkonzept; im Kapitel Datenmodell die Objekte aus `models/mart/<konzept>/` als Liste ohne Links. Alle Kapitel bleiben stehen (Platzhalter-Regel in der SKILL.md).
- Property `dokumentation: offen | teilweise | vollständig` und die Spalte „Doku“ in den Indexseiten stimmen überein.

## Darstellung

- Callouts: `[!WARNING]` für leere oder fehlerhafte Objekte und gefährliche Schritte, `[!todo]` für Lücken, sonst sparsam.
- Mermaid für Lineage (`flowchart LR`), Beziehungen (`erDiagram`), Zeiträume (`gantt`), Mengen (`xychart-beta`, `pie`) und Chronologien (`timeline`). Keine HTML-Entities in Labels, Zeilenumbruch mit `<br/>`.
- Keine `#Überschrift`-Anker in Links (Obsidian und GitLab bilden sie unterschiedlich). Links auf `models/` und `design/` relativ zum Notizort; Obsidian zieht diese beim Verschieben nicht nach.
- Die Reihenfolge der Objektseiten in der Vor-/Zurück-Navigation folgt der Liste im Kapitel Datenmodell.

## Abschluss-Check

1. `check_concept_docs.py` meldet keine Fehler; Warnungen zu Stil gelesen und begründet behoben oder belassen.
2. Jede Aussage zur Logik ist im SQL nachgesehen, jede Zahl hat Stand und Umgebung.
3. Bei einer Migration: jeder Abschnitt, jede Zahl und jeder Beschluss der alten Seiten ist auf einer neuen Seite wiederzufinden ([Migration](migration.md), Schritt 6).
4. Indexseiten, Base-Ansichten und `vault-sync.json` sind nachgezogen, der Sync meldet `0 veraltet`.
5. Changelog-Zeile vorhanden.
6. In der Antwort nennen: korrigierte Aussagen, neue Befunde, offene `[!todo]`, getroffene Annahmen.
