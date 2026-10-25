# Ausgabe als Obsidian-Canvas

Für Projekte, deren Doku ein Obsidian-Vault ist. Ergebnis: `<concept>/er-<concept>.canvas` im Vault (z. B. `datavault-design/vertrieb/er-vertrieb.canvas`), bearbeitbar in Obsidian, gleiche Farben und Key-Notation wie das HTML-Artboard.

## Voraussetzungen im Vault

- Community-Plugin **Advanced Canvas** (`advanced-canvas`). In `.obsidian/plugins/advanced-canvas/data.json`:
  - `"autoResizeNodeFeatureEnabled": true`, `"autoResizeNodeEnabledByDefault": true` — Kartenhöhe passt sich an (greift, sobald eine Karte gerendert/bearbeitet wird)
  - `"edgesStylingFeatureEnabled": true`, `"nodeStylingFeatureEnabled": true`
  - `"defaultEdgeStyleAttributes": {"arrow": "triangle-outline", "pathfindingMethod": "square"}` — neue Linien im Standard
- CSS-Snippet mit dem Block **Canvas: ER-Karten** (unten) in `.obsidian/snippets/` aktiviert. Wichtig: Selektor `.canvas-node-content .markdown-rendered` (mit Leerzeichen) — der Markdown-Container sitzt *in* der Karte.
- Nach Änderungen an `data.json` oder am Snippet: Obsidian „App ohne Speichern neu laden", sonst überschreibt die laufende App die Datei.

## Vorgehen

1. Inhalt wie in Abschnitt 2–3 des Skills extrahieren (Code + Entwurf, Inkonsistenzen als „Offen").
2. Modell als JSON schreiben (Format unten), Anordnung nach Abschnitt 5 über `col`/`row`.
3. `python3 scripts/build_obsidian_canvas.py modell.json <ziel>.canvas`
4. **Bestehendes Canvas aktualisieren:** vorher lesen — hat der Nutzer Karten verschoben oder Linien ergänzt, nur `text`/`width`/`height`/`styleAttributes` der betroffenen Knoten ersetzen, `x`/`y` und Gruppen beibehalten. Nie Notiz-, Kopf- oder Legendenknoten durch Kartenlogik ersetzen (nur Knoten, deren Text mit `### hub_|sat_|link_|ref_…` beginnt).

## Modell-Format

```json
{
  "title": "Vertrieb — Gesamtmodell",
  "kicker": "Data Vault 2.1 · Raw Vault · Business Concept „_common" · Schema vault",
  "sub": "Quellsystem … · Branch dev · Stand <JJJJ-MM-TT> · Grundlage: design/… + dbt-Code",
  "conventions": ["`dss_*`-Spalten nicht dargestellt", "SHA-256 · Trenner `||` · NULL → `-1`"],
  "decisions": ["…"],
  "open": ["…"],
  "objects": [
    {"name": "hub_bestellung", "kind": "hub", "src": "ext_shop_bestellung", "col": 3, "row": 1,
     "rows": [["PK", "hk_bestellung", "← bestell_nr"]], "badges": ["im Branch", "zentraler Hub"]},
    {"name": "sat_bestellung__shop", "kind": "sat", "col": 3, "row": 2,
     "rows": [["PK", "hk_bestellung", ""], ["HD", "hd_bestellung", "← Payload"], ["ATT", "status", "→ ref_bestellstatus_v"]]},
    {"name": "hub_kunde", "kind": "hub", "foreign": true, "col": 3, "row": 0, "src": "siehe er-crm",
     "rows": [["PK", "hk_kunde", "← kunden_nr"]], "badges": ["bestehend (CRM)"]}
  ],
  "edges": [["hub_bestellung", "sat_bestellung__shop"], ["sat_bestellung__shop", "ref_bestellstatus_v", {"label": "status"}]],
  "groups": [{"label": "CRM · Kunde", "members": ["hub_kunde", "…"]}]
}
```

`kind`: `hub`, `sat`, `effsat`, `masat`, `link`, `tlink`, `ref`. `rows`: `[Kürzel, Spalte(n), Quelle/Rolle]` — Rolle mit `←` für Hash-Inputs, `→` für Verweise; mehrere `ATT`-Spalten kommagetrennt (werden untereinander gesetzt). `foreign: true` = Fremd-Hub (gepunktet).

## Was das Skript festlegt

| Element | Darstellung |
|---|---|
| Karte | `### <objekt>` · `<small>Quelle</small>` · Tabelle **Key \| Spalte \| Quelle / Rolle** · rote Hinweiszeile · kursive Badges |
| Farbe | `color` des Knotens = Typfarbe aus Abschnitt 4 (Rahmen/Tönung in Obsidian) |
| Reference Table | `styleAttributes: {border: dashed, shape: database}` |
| Transaction Link | `border: dashed` |
| Fremd-Hub | `border: dotted` |
| Kanten | Pfeil `triangle-outline`, `pathfindingMethod: square`; Richtung **Hub → Link**, **Hub → Satellite**, **Link → Satellite**, **Satellite → Reference Table** (gestrichelt) — das Skript dreht falsch herum angegebene Kanten selbst |
| Höhe | geschätzt + `dynamicHeight: true` (Advanced Canvas korrigiert beim Bearbeiten) |
| Kopf | Titel/Legende links (randlos), gelbe Notizbox rechts (Konvention, Entscheidungen, Offen), Legendenchips je Typ |

## CSS-Snippet (Block „Canvas: ER-Karten")

```css
/* ---------- Canvas: ER-Karten (Hub/Sat/Link als Tabelle) ------------------ */
.canvas-node-content .markdown-rendered h3 {
  margin: 0 0 0.1em;
  padding: 0;
  border: 0;
  font-family: var(--font-monospace);
  font-size: 0.95em;
  font-weight: var(--font-semibold);
}
.canvas-node-content .markdown-rendered small { color: var(--text-muted); }
.canvas-node-content .markdown-rendered table {
  width: 100%;
  margin: 0.4em 0 0.3em;
  font-size: 0.8em;
  line-height: 1.35;
}
.canvas-node-content .markdown-rendered th {
  padding: 0.15em 0.4em;
  font-size: 0.85em;
  font-weight: var(--font-normal);
  color: var(--text-muted);
  text-align: left;
}
.canvas-node-content .markdown-rendered td { padding: 0.2em 0.4em; vertical-align: top; font-size: 1em; }  /* feste Größe: sonst greift Obsidians --table-text-size (absolut) und Spalte 3 wird grösser */
.canvas-node-content .markdown-rendered td:first-child { width: 3.2em; white-space: nowrap; }
.canvas-node-content .markdown-rendered td:first-child code {
  font-size: 0.85em;
  font-weight: var(--font-semibold);
}
.canvas-node-content .markdown-rendered td:nth-child(2) { font-family: var(--font-monospace); font-size: 0.95em; }
.canvas-node-content .markdown-rendered td:nth-child(3) { color: var(--text-muted); }
.canvas-node-content .markdown-rendered p:last-child { margin: 0.2em 0 0; font-size: 0.8em; color: var(--text-muted); }
/* Kantenbeschriftungen klein statt Überschriftgrösse */
.canvas-path-label-wrapper .canvas-path-label { font-size: var(--font-ui-small); padding: 2px 6px; }
```
