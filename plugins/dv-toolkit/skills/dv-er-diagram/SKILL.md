---
name: dv-er-diagram
description: Erstellt ein standardisiertes Raw-Vault-ER-Diagramm (Hubs, Links, Satellites) als visuelle Darstellung aus dbt-Modellen oder Mermaid-Entwürfen — immer gleiches Layout, gleiche Farben, gleiche Key-Notation. Verwenden bei "ER-Diagramm darstellen", "Vault-Diagramm", "Raw Vault visualisieren", "Modell für Review/Schulung aufbereiten" oder wenn aus einem Concept ein präsentierbares Diagramm entstehen soll. Auch als Obsidian-Canvas (.canvas) bei "Canvas", "Obsidian", "im Vault darstellen".
---

# Raw-Vault-ER-Diagramm (Standarddarstellung)

Ziel: Für jedes Business Concept (z. B. `_common`, `crm`, `shop`) ein Diagramm in immer gleicher Darstellung, aus dem sich Staging-Views und Raw-Vault-Objekte direkt ableiten lassen. Das Diagramm zeigt **nur Informationen mit Funktion**: Quelle, Keys, Hash-Inputs, Hashdiff-Namen, Gültigkeit. Keine Metadaten, keine reine Payload.

Abgrenzung zu `dv-design-sync`: Die Mermaid-Dateien unter `design/` bleiben die Model-First-Quelle und werden dort gepflegt. Dieser Skill erzeugt daraus bzw. aus dem dbt-Code die **präsentierbare** Darstellung (Review, Fachabstimmung, Schulung).

Sprache im Diagramm: Deutsch. Objekt- und Spaltennamen exakt wie im Code.

## 1. Scope klären

- Welches Concept / welcher Ordner (`models/raw_vault/<concept>/`)? Welcher Branch?
- Ist das Modell schon gebaut (dbt-Code lesen) oder nur entworfen (Mermaid unter `design/raw-vault/<concept>/er-diagram.mmd` oder `docs/`)? Beides kombinieren ist üblich: gebaute Objekte aus dem Code, geplante aus dem Entwurf.
- Hubs anderer Concepts, auf die Links zeigen (z. B. `hub_kunde` aus `_common`), werden als Fremd-Hub mit aufgenommen (Badge `bestehend (<Quelle>)`).

## 2. Informationen extrahieren

Pro Objekt aus dem `yaml_metadata`-Block des dbt-Modells:

| Objekt | Makro | Was ins Diagramm |
|---|---|---|
| Hub | `automate_dv.hub` | `src_pk`, `src_nk`, alle `source_model` (Multi-Source) |
| Link | `automate_dv.link` | `src_pk`, `src_fk` |
| Transaction Link | `link`, Name mit Suffix `_tl` | wie Link |
| Satellite | `automate_dv.sat` | `src_pk`, Hashdiff-Name (`src_hashdiff.source_column`), Parent |
| Effectivity-Sat | `automate_dv.eff_sat` | `src_pk`, `src_dfk`, `src_sfk`, `src_start_date`, `src_end_date` |
| Multi-Active-Sat | `automate_dv.ma_sat` | `src_pk`, `src_cdk`, Hashdiff-Name |
| Dependent-Child-Sat | `sat` mit CDK | wie Satellite + `CDK` |
| Reference Table | `automate_dv.ref_table` | `src_pk` (Natural Key, kein Hash) |

Aus der Staging-View (`models/staging/<model>.sql`, Block `hashed_columns`) die **Quellspalten jedes Hash Keys** (`hk_x: "id"`, `hk_link_x: ["a", "b"]`). Aus `derived_columns` nur abgeleitete BK-Spalten (z. B. `kunde_id: "kunden_nummer"`) — dargestellt als `hk_kunde ← kunde_id (kunden_nummer)`.

Quelle = **voller Name der External Table** aus `source_model.staging` der Staging-View bzw. `sources.yml` (z. B. `ext_idms_service_subscription_main`), nie nur der fachliche Tabellenname. Liest ein Hub aus einer eigenen FK-Staging-View (`<staging>__<entity>`), steht diese als Quelle.

Status `im Branch`: Es existiert bereits eine Modelldatei unter `models/raw_vault/**` im aktuellen Branch.

## 3. Was gezeigt wird — und was nicht

Gezeigt (Kürzel als dunkles Label vor der Zeile):

| Kürzel | Bedeutung | Beispiel |
|---|---|---|
| `PK` | Hash Key mit gehashten Quellspalten | `PK hk_abo ← id` |
| `FK` | Fremdschlüssel eines Links mit Quellspalte | `FK hk_service ← service_id` |
| `HD` | Hashdiff, nur Name | `HD hd_service ← Payload` |
| `DFK` / `SFK` | Driving / Secondary FK eines Effectivity-Sats | `DFK hk_abo` |
| `DT` | Gültigkeitsspalten eines Effectivity-Sats | `DT start_date ← [start]` |
| `CDK` | Dependent Key eines MA-/DC-Sats | `CDK abo_option_name` |
| `BK` | Natural Key einer Reference Table | `BK KontoNr` |
| `ATT` | Attribut **mit Funktion** | `ATT mandate_id (FK-Kandidat, Option A)` |

`ATT` nur für: FK-Kandidaten, die bewusst Attribut bleiben; Status-/Filterspalten mit fachlicher Rolle (z. B. `disabled` für aktive Abos); Spalten, mit denen ein Mart rechnet (Preis, Menge).

Nicht gezeigt:
- alle `dss_*`-Spalten (load_date, record_source, business_key, create_datetime, eff_date) — Standard, steht einmal in der Konventions-Notiz
- reine Payload-Spalten — nur `← Payload`
- Datentypen

Hashdiff heisst im Staging `hd_<name>`, im Satellite physisch `HASHDIFF` (alias) — gehört in die Legende, nicht in jede Box.

## 4. Visueller Standard

### Farben je Objekttyp (Oberkante der Box + Legende)

| Typ | CSS-Klasse | Farbe | Besonderheit |
|---|---|---|---|
| Hub | `hub` | `#3653C4` | Rahmen `#C7D0F0`; zentraler Hub zusätzlich `border-width:2px` |
| Satellite | `sat` | `#5B6472` | |
| Effectivity-Sat | `effsat` | `#0F766E` | |
| Multi-Active / Dependent-Child-Sat | `masat` | `#4D7C0F` | |
| Link | `link` | `#B45309` | |
| Transaction Link | `tlink` | `#9A3412` | Rahmen gestrichelt |
| Reference Table | `ref` | `#6B7280` | Rahmen gestrichelt |

### Verbindungslinien (eine SVG-Ebene über das ganze Artboard, 2 px, gerade)

- Hub ↔ Satellite, Link ↔ Satellite: `#9CA3AF`
- Hub ↔ Link: `#D08A3E`
- Link ↔ Effectivity-Sat: `#0F766E`
- An der Kantenmitte andocken; mehrere Linien an derselben Kante gleichmässig verteilen, in der Reihenfolge ihrer Ziele (oben → unten).

### Badges und Hinweise

- `im Branch` grün (`#DCFCE7` / `#166534`)
- offen rot (`#FEE2E2` / `#991B1B`): offene Entscheidung, z. B. `Grain offen`, `Quellsystem offen`
- info blau (`#E8EBF7` / `#2A3F8F`): z. B. `bestehend (CRM)` für Fremd-Hubs
- Hinweiszeile rot (Sans 11 px): fehlende Objekte oder Code-Inkonsistenzen, z. B. „Noch kein Satellite für disabled"

### Schrift und Fläche

IBM Plex Sans (Titel, Labels) + IBM Plex Mono (Objekt-/Spaltennamen), Hintergrund `#F4F1EA`, Boxen weiss, Radius 10 px. Keine Emojis, keine Verläufe.

## 5. Layout-Regeln

- Ein Artboard, absolute Positionierung, Breite ~2400–2600 px, Höhe nach Inhalt.
- **Header** (0–240 px):
  - links: Kicker `Data Vault 2.1 · Raw Vault · Business Concept „<x>" · Schema <schema>`, Titel `<Concept> — Gesamtmodell`, Unterzeile (Quellsystem · Branch · Staging-Konvention `ext_<quelle>_<tabelle>_main → <quelle>_<tabelle>_main` · Stand-Datum), darunter zweizeilige Legende (Typ-Farben, `←`, Badge `im Branch`; Kürzel PK/FK/HD/DT/ATT, bei Bedarf DFK/SFK/CDK/BK)
  - rechts: gelbe Notizbox mit **Konvention** (dss_* nicht dargestellt, SHA-256, Trenner `||`, NULL → `-1`, Payload nicht aufgeführt), **Entscheidungen** (mit Datum), **Offen**
- **Leserichtung links → rechts, Satelliten immer aussen:**
  - links: Satelliten der Referenz-Hubs | Hubs | Links Richtung Zentrum
  - Mitte: zentraler Hub (fachliche Kernentität), Fremd-Hubs darunter über ihren Link
  - rechts: wiederkehrende Gruppen (z. B. je Produkt) als **Bänder** untereinander — Link breit oben, darunter seine Satelliten nebeneinander, rechts daneben Ziel-Hub, ganz aussen dessen Satellite
- Hub-Satellite-Paare horizontal, vertikal zueinander zentriert. Abstände min. 40 px horizontal, 40–60 px vertikal, keine Überschneidungen, Linien laufen nicht durch Boxen.
- Hubs ohne Link zum Zentrum (reine Referenz) oben links, mit kursiver Seitennotiz, warum kein Link.
- Boxhöhe ≈ 47 px + 18 px je Zeile + 22 px je Badge-Zeile; lange Tabellennamen dürfen umbrechen.

## 6. Markup

Vollständiges Artboard-Gerüst mit CSS, Header, Legende, Notizbox, SVG-Ebene und einer Beispielbox je Objekttyp: [`references/artboard-skeleton.html`](references/artboard-skeleton.html). CSS unverändert übernehmen — nur so bleiben alle Diagramme gleich.

Box-Aufbau: Farbbalken → Titel (Objektname) → Quellzeile → Key-Zeilen → optional Hinweis → Badges. Satellites an Links ohne eigene Quellzeile, wenn die Quelle die des Links ist.

## 7. Ausgabe

- **Mit Design-Canvas (Claude.ai / Cowork, Artifact-Tool vorhanden):** Artifact `quickstart` mit `intent: "design"`, ohne Design System (ausser gewünscht), Canvas-Titel `Raw Vault ER-Diagramm — <Concept>`, ein Artboard `Main.dc.html` im `.dc.html`-Format des Design-Typs (Gerüst aus der Referenz in `<x-dc>` einbetten), `launch: {view: "canvas"}`.
- **Ohne Artifact-Tool (Claude Code):** das Gerüst als eigenständige HTML-Datei `design/raw-vault/<concept>/er-diagram.html` schreiben (die `<x-dc>`/`<helmet>`-Hüllen weglassen, Style in `<head>`).
- **Obsidian-Canvas (Doku als Obsidian-Vault, oder auf Wunsch „Canvas"/„Obsidian"):** Modell als JSON beschreiben und mit `scripts/build_obsidian_canvas.py` eine `.canvas`-Datei erzeugen — Kartenaufbau (Tabelle Key | Spalte | Quelle / Rolle), Farben, Rahmenstile und Pfeilrichtung (Hub → Link, Hub → Satellite, Satellite → Reference Table) setzt das Skript. Voraussetzungen im Vault (Plugin Advanced Canvas, CSS-Snippet, `data.json`-Einstellungen), Modell-Format und Update-Regeln: [`references/obsidian-canvas.md`](references/obsidian-canvas.md).
- **Bestehendes Diagramm aktualisieren:** zuerst den aktuellen Stand lesen (wird ggf. live editiert), nur geänderte Boxen/Linien anpassen, Layout beibehalten.

## 8. Abschluss-Check

- Jedes Objekt im Scope ist genau einmal drin, jede Beziehung aus `src_fk` / Parent ist als Linie gezeichnet.
- Jede Box: Quelle (voller `ext_…`-Name), PK mit `←`-Inputs; jeder Link: FKs mit Inputs; jeder Satellite: HD-Name; Effectivity-Sats: DFK/SFK/DT.
- Keine `dss_*`-Spalte, keine reine Payload-Spalte, keine Datentypen.
- Inkonsistenzen zwischen Code und Entwurf (z. B. Spalte im Hash Key, aber nicht im Hashdiff; Staging-Quelle fehlt in `sources.yml`; Objekt ohne Satellite) als Hinweiszeile oder unter „Offen" — nichts stillschweigend korrigieren.
- Im Antworttext kurz nennen, was als offen markiert wurde.
