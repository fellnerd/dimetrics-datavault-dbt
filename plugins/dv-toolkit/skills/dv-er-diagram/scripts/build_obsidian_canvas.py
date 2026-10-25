#!/usr/bin/env python3
"""Baut ein Raw-Vault-ER-Diagramm als Obsidian-Canvas (JSON Canvas + Advanced-Canvas-Attribute).

Aufruf:  python3 build_obsidian_canvas.py <modell.json> <ziel.canvas>

Das Modell (JSON) beschreibt nur Inhalt und grobe Anordnung; Farben, Kartenaufbau,
Pfeilrichtung und Kantenstil setzt das Skript nach dem dv-er-diagram-Standard.
Format siehe references/obsidian-canvas.md.
"""
import hashlib, json, sys

COLOR = {"hub": "#3653C4", "sat": "#5B6472", "effsat": "#0F766E", "masat": "#4D7C0F",
         "link": "#B45309", "tlink": "#9A3412", "ref": "#6B7280", "note": "#CA8A04"}
EDGE = {("hub", "sat"): "#9CA3AF", ("link", "sat"): "#9CA3AF", ("hub", "masat"): "#9CA3AF",
        ("hub", "link"): "#D08A3E", ("hub", "tlink"): "#D08A3E", ("link", "effsat"): "#0F766E",
        ("sat", "ref"): "#6B7280", ("masat", "ref"): "#6B7280"}
ORDER = {"hub": 0, "link": 1, "tlink": 1, "sat": 2, "effsat": 2, "masat": 2, "ref": 3}
LEGEND = [("hub", "Hub"), ("sat", "Satellite"), ("link", "Link"), ("ref", "Reference Table")]
COL_W, GAP_X, GAP_Y = 560, 60, 60


def nid(s):
    return hashlib.md5(s.encode()).hexdigest()[:16]


def card(o):
    """Markdown einer Objektkarte: Titel, Quelle, Tabelle Key | Spalte | Quelle / Rolle, Hinweis, Badges."""
    t = [f"### {o['name']}"]
    if o.get("src"):
        t.append(f"<small>{o['src']}</small>")
    t += ["", "| Key | Spalte | Quelle / Rolle |", "|---|---|---|"]
    for key, col, role in o["rows"]:
        t.append(f"| `{key}` | {col.replace(', ', '<br>') if key == 'ATT' else col} | {role or ''} |")
    if o.get("note"):
        t.append(f"\n<small><font color=\"#991B1B\">Hinweis: {o['note']}</font></small>")
    t.append("\n*" + " · ".join(o.get("badges", ["im Branch"])) + "*")
    return "\n".join(t)


def size(o):
    """Schätzt Breite/Höhe; Advanced Canvas (auto resize) korrigiert die Höhe beim ersten Bearbeiten."""
    longest = max([len(o["name"]) * 1.15, len(o.get("src") or "") * 0.8] +
                  [4 + len(c) + len(r or "") * 0.9 for _, c, r in o["rows"]])
    w = int(min(max(longest * 8.5 + 60, 320), COL_W - GAP_X)) // 10 * 10
    per_row = [1 + max(len(c) // 28, len(r or "") // 30, c.count(",") if k == "ATT" else 0) for k, c, r in o["rows"]]
    h = 110 + 30 * (1 + sum(per_row)) + (28 if o.get("note") else 0) + 30
    return w, h // 10 * 10 + 10


def build(m):
    nodes, edges = [], []
    kind = {o["name"]: o["kind"] for o in m["objects"]}
    # Kopf: Titel, Legende, Notizbox
    head = [f"<small>{m.get('kicker', '')}</small>", f"# {m['title']}", m.get("sub", ""), "",
            "**Farbe** = Objekttyp · Pfeile: Hub → Link, Hub → Satellite, Satellite → Reference Table",
            "Kürzel: `PK` Hash Key · `FK` Fremdschlüssel · `HD` Hashdiff · `DFK`/`SFK` Driving/Secondary FK · "
            "`DT` Gültigkeit · `CDK` Dependent Key · `BK` Natural Key · `ATT` Attribut mit Funktion · `←` gehashte Quellspalten"]
    nodes.append({"id": nid("hdr"), "type": "text", "x": 0, "y": 0, "width": 1300, "height": 300,
                  "text": "\n".join(head), "styleAttributes": {"border": "invisible"}})
    note = []
    for title, key in (("Konvention", "conventions"), ("Entscheidungen", "decisions"), ("Offen (Code ↔ Entwurf, nicht korrigiert)", "open")):
        if m.get(key):
            note += [f"**{title}**"] + [f"- {x}" for x in m[key]] + [""]
    nodes.append({"id": nid("note"), "type": "text", "x": 1400, "y": 0, "width": 1400, "height": 300,
                  "color": COLOR["note"], "text": "\n".join(note).strip(), "dynamicHeight": True})
    for i, (k, label) in enumerate(LEGEND):
        leg = {"id": nid("leg" + k), "type": "text", "text": f"**{label}**", "x": i * 190, "y": 320,
               "width": 170, "height": 50, "color": COLOR[k]}
        if k == "ref":
            leg["styleAttributes"] = {"border": "dashed"}
        nodes.append(leg)
    # Objekte im Raster col/row; Zeilenhöhe = höchste Karte der Zeile
    sized = {o["name"]: size(o) for o in m["objects"]}
    rows = sorted({o["row"] for o in m["objects"]})
    y, row_y = 440, {}
    for r in rows:
        row_y[r] = y
        y += max(sized[o["name"]][1] for o in m["objects"] if o["row"] == r) + GAP_Y
    for o in m["objects"]:
        w, h = sized[o["name"]]
        n = {"id": nid(o["name"]), "type": "text", "text": card(o), "x": o["col"] * COL_W, "y": row_y[o["row"]],
             "width": w, "height": h, "color": COLOR[o["kind"]], "dynamicHeight": True}
        if o["kind"] in ("ref", "tlink"):
            n["styleAttributes"] = {"border": "dashed"} | ({"shape": "database"} if o["kind"] == "ref" else {})
        if o.get("foreign"):
            n["styleAttributes"] = {"border": "dotted"}
        nodes.append(n)
    # Kanten: Richtung normalisieren (niedrigere ORDER zeigt auf höhere), Seiten aus Lage ableiten
    pos = {n["id"]: n for n in nodes}
    for e in m["edges"]:
        a, b = e[0], e[1]
        opts = e[2] if len(e) > 2 else {}
        if ORDER[kind[a]] > ORDER[kind[b]]:
            a, b = b, a
        A, B = pos[nid(a)], pos[nid(b)]
        dx = (B["x"] + B["width"] / 2) - (A["x"] + A["width"] / 2)
        dy = (B["y"] + B["height"] / 2) - (A["y"] + A["height"] / 2)
        if abs(dx) >= abs(dy):
            fs, ts = ("right", "left") if dx > 0 else ("left", "right")
        else:
            fs, ts = ("bottom", "top") if dy > 0 else ("top", "bottom")
        pair = (kind[a], kind[b])
        st = {"arrow": "triangle-outline", "pathfindingMethod": "square"}
        if kind[b] == "ref":
            st["path"] = "short-dashed"
        edge = {"id": nid(a + ">" + b), "fromNode": nid(a), "fromSide": fs, "toNode": nid(b), "toSide": ts,
                "color": EDGE.get(pair, "#9CA3AF"), "styleAttributes": st}
        if opts.get("label"):
            edge["label"] = opts["label"]
        edges.append(edge)
    # Gruppen (optional): {"label": "...", "members": [...]}
    for g in m.get("groups", []):
        ms = [pos[nid(x)] for x in g["members"]]
        x0, y0 = min(n["x"] for n in ms) - 30, min(n["y"] for n in ms) - 50
        nodes.insert(0, {"id": nid("g" + g["label"]), "type": "group", "label": g["label"], "x": x0, "y": y0,
                         "width": max(n["x"] + n["width"] for n in ms) + 30 - x0,
                         "height": max(n["y"] + n["height"] for n in ms) + 30 - y0})
    return {"nodes": nodes, "edges": edges}


if __name__ == "__main__":
    model = json.load(open(sys.argv[1], encoding="utf-8"))
    json.dump(build(model), open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False, indent="\t")
    print(f"ok: {sys.argv[2]}")
