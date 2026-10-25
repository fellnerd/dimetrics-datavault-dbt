#!/usr/bin/env python3
"""Prüft die Konzeptdokumentation unter <vault>/04-<mandant>-architektur/ (Skill dv-docs, references/konzeptdoku.md).

Fehler (Exit 1):
  - Pflichtkapitel (H2) fehlen oder stehen in falscher Reihenfolge
      Information Mart, Übersicht  information-mart/mart_*/00-*.md
      Information Mart, Objekt     information-mart/mart_*/objekte/*.md
      Raw Vault, Übersicht         raw-vault/mart_*/00-*.md
  - Kapitel ohne Inhalt (Platzhalter fehlt)
  - Pflicht-Properties fehlen, Objektseite heisst anders als ihr Property `objekt`
  - relative Links ins Leere, [[Wikilinks]]
Warnungen:
  - Beladungsseiten ohne die üblichen Kapitel (nur bei Konzepten mit Doku-Stand teilweise/vollständig)
  - Konzept nur in einer Schicht vorhanden
  - `dokumentation: vollständig`, aber [!todo] auf der Seite oder den Objektseiten
  - Stilmerkmale: Gedankenstriche, Fettdruck, Floskeln (siehe references/schreibstil.md), nur für
    Konzepte mit `dokumentation: teilweise` oder `vollständig`

Aufruf:  python3 check_concept_docs.py <vault>   (Vault = Ordner mit .obsidian/, z. B. docs oder docs/datavault-x)
"""
import os
import re
import sys
from urllib.parse import unquote

IM_CONCEPT = ["Allgemein", "Datenquelle", "Objekte und Logik", "Security", "Datenmodell"]
IM_OBJECT = ["Allgemein", "Attribute", "Funktion und Logik", "Abfragebeispiele", "Besonderheiten", "Security"]
RV_CONCEPT = ["Allgemein", "Beladung Datenquelle", "Objekte", "Datenmodell", "Modellierung", "Datenqualität",
              "Security", "Weitere Seiten"]
BELADUNG_KEYS = ["Quelle", "Lieferung", "Pipeline", "Lineage", "Felder", "Staging", "PSA", "Ladestand"]

PROPS_CONCEPT = ["title", "tags", "konzept", "schicht", "schema", "dokumentation", "stand"]
PROPS_OBJECT = ["title", "tags", "objekt", "schema", "art", "materialisierung", "grain", "quellen", "stand"]

FLOSKELN = ["darüber hinaus", "ausserdem", "außerdem", "zudem", "des weiteren", "ferner,", "nicht nur",
            "es ist wichtig", "zu beachten ist", "zusammenfassend", "insgesamt zeigt", "fazit", "nahtlos",
            "robust", "leistungsstark", "spielt eine", "entscheidende rolle", "zentrale rolle"]

GENERATED = "generiert von scripts/sync_design_to_vault.py"
LINK = re.compile(r"\]\(([^)\s]+)\)")
FENCE = re.compile(r"^```.*?^```", re.S | re.M)


def frontmatter(text):
    """Einfacher Parser: Top-Level-Schlüssel mit Wert oder Liste (reicht für Obsidian-Properties)."""
    if not text.startswith("---\n"):
        return {}, text
    end = text.find("\n---\n", 4)
    if end < 0:
        return {}, text
    props, key = {}, None
    for line in text[4:end].splitlines():
        m = re.match(r"^([A-Za-z_][\w-]*):\s*(.*)$", line)
        if m:
            key = m.group(1)
            val = m.group(2).strip().strip('"')
            props[key] = val if val else []
        elif key and re.match(r"^\s+-\s+", line):
            if not isinstance(props[key], list):
                props[key] = [props[key]] if props[key] else []
            props[key].append(re.sub(r"^\s+-\s+", "", line).strip().strip('"'))
    return props, text[end + 5:]


def sections(body):
    """H2-Überschriften mit Inhalt (ohne Codeblöcke und ohne Fussnavigation)."""
    body = FENCE.sub(lambda m: "\n" * m.group(0).count("\n") + "CODE", body)
    parts = re.split(r"^## (.+)$", body, flags=re.M)
    out = []
    for i in range(1, len(parts), 2):
        content = re.split(r"^---\s*$", parts[i + 1], maxsplit=1, flags=re.M)[0]
        out.append((parts[i].strip(), content.strip()))
    return out


def check_order(found, required):
    names = [n for n, _ in found]
    missing = [r for r in required if r not in names]
    idx = [names.index(r) for r in required if r in names]
    wrong_order = idx != sorted(idx)
    return missing, wrong_order


class Report:
    def __init__(self, root):
        self.root, self.errors, self.warnings = root, [], []

    def err(self, path, msg):
        self.errors.append(f"{os.path.relpath(path, self.root)}: {msg}")

    def warn(self, path, msg):
        self.warnings.append(f"{os.path.relpath(path, self.root)}: {msg}")


def check_links(rep, path, body):
    text = FENCE.sub("", body)
    text = re.sub(r"`[^`\n]*`", "", text)
    if "[[" in text:
        rep.err(path, "Wikilink [[...]] gefunden, nur relative Markdown-Links verwenden")
    for m in LINK.finditer(text):
        link = m.group(1)
        if re.match(r"^[a-z]+:", link) or link.startswith("#"):
            continue
        target = unquote(link.split("#")[0])
        if target and not os.path.exists(os.path.normpath(os.path.join(os.path.dirname(path), target))):
            rep.err(path, f"Link ins Leere: {link}")


def check_style(rep, path, body):
    """Stilmerkmale je Datei zusammengefasst melden."""
    text = FENCE.sub("", body)
    hits = {}
    for no, line in enumerate(text.splitlines(), 1):
        s = line.strip()
        if not s or s.startswith(("#", "[Dokumentation]", "◀", "<!--", "> **Kopie**")):
            continue
        s = re.sub(r"`[^`\n]*`", "", s)
        if re.search(r"\s[—–]\s", s):
            hits.setdefault("Gedankenstrich", []).append(no)
        if "**" in s and not s.startswith("|"):
            hits.setdefault("Fettdruck im Text", []).append(no)
        low = s.lower()
        for f in FLOSKELN:
            if f in low:
                hits.setdefault(f"Floskel „{f.strip(',')}“", []).append(no)
    for what, lines in hits.items():
        shown = ", ".join(map(str, lines[:8])) + (" …" if len(lines) > 8 else "")
        rep.warn(path, f"{what}: {len(lines)}x (Zeile {shown})")


def check_page(rep, path, required, props_req, strict=True, style=True):
    text = open(path, encoding="utf-8").read()
    props, body = frontmatter(text)
    if GENERATED in text:
        return props, body
    for p in props_req:
        if p not in props or props[p] in ("", []):
            rep.err(path, f"Property fehlt: {p}")
    secs = sections(body)
    missing, wrong = check_order(secs, required)
    log = rep.err if strict else rep.warn
    if missing:
        log(path, "Kapitel fehlt: " + ", ".join(missing))
    if wrong:
        log(path, "Kapitel in falscher Reihenfolge, erwartet: " + " · ".join(required))
    for name, content in secs:
        if not content:
            rep.err(path, f"Kapitel „{name}“ ist leer (Platzhalter „nicht vorhanden“ oder [!todo] setzen)")
    check_links(rep, path, body)
    if style:
        check_style(rep, path, body)
    return props, body


def main():
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except AttributeError:
        pass
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    vault = os.path.abspath(sys.argv[1])
    archs = [os.path.join(vault, d) for d in sorted(os.listdir(vault))
             if re.match(r"^04-.+-architektur$", d) and os.path.isdir(os.path.join(vault, d))]
    if not archs:
        print(f"Kein Ordner 04-<mandant>-architektur in {vault}")
        sys.exit(2)
    rep = Report(vault)
    summary = []
    for arch in archs:
        im, rv = os.path.join(arch, "information-mart"), os.path.join(arch, "raw-vault")
        concepts = sorted({d for base in (im, rv) if os.path.isdir(base)
                           for d in os.listdir(base) if d.startswith("mart_") and os.path.isdir(os.path.join(base, d))})
        for c in concepts:
            row = {"konzept": c, "im": "-", "rv": "-", "objekte": 0, "todo": 0}
            for layer, base, req in (("im", im, IM_CONCEPT), ("rv", rv, RV_CONCEPT)):
                folder = os.path.join(base, c)
                if not os.path.isdir(folder):
                    rep.warn(arch, f"Konzept {c} fehlt in {os.path.basename(base)}/")
                    continue
                idx = [f for f in os.listdir(folder) if f.startswith("00-") and f.endswith(".md")]
                if not idx:
                    rep.err(folder, "Übersichtsseite 00-<konzept>.md fehlt")
                    continue
                p = os.path.join(folder, idx[0])
                pre = frontmatter(open(p, encoding="utf-8").read())[0].get("dokumentation", "")
                style = pre in ("teilweise", "vollständig")
                props, body = check_page(rep, p, req, PROPS_CONCEPT, style=style)
                doku = props.get("dokumentation", "?") or "?"
                row[layer] = doku
                todos = body.count("[!todo]")
                pages = [p]
                if layer == "im":
                    od = os.path.join(folder, "objekte")
                    if os.path.isdir(od):
                        for f in sorted(os.listdir(od)):
                            if not f.endswith(".md"):
                                continue
                            op = os.path.join(od, f)
                            oprops, obody = check_page(rep, op, IM_OBJECT, PROPS_OBJECT, style=style)
                            if oprops.get("objekt") and oprops["objekt"] != f[:-3]:
                                rep.err(op, f"Dateiname passt nicht zum Property objekt ({oprops['objekt']})")
                            todos += obody.count("[!todo]")
                            row["objekte"] += 1
                else:
                    for f in sorted(os.listdir(folder)):
                        fp = os.path.join(folder, f)
                        if not f.endswith(".md") or f.startswith("00-"):
                            continue
                        if "-beladung-" in f and doku in ("teilweise", "vollständig"):
                            ftext = open(fp, encoding="utf-8").read()
                            heads = [n for n, _ in sections(frontmatter(ftext)[1])]
                            miss = [k for k in BELADUNG_KEYS if not any(k.lower() in h.lower() for h in heads)]
                            if miss:
                                rep.warn(fp, "Beladungsseite ohne Kapitel zu: " + ", ".join(miss))
                        if not open(fp, encoding="utf-8").read().count(GENERATED):
                            fbody = frontmatter(open(fp, encoding="utf-8").read())[1]
                            check_links(rep, fp, fbody)
                            if style:
                                check_style(rep, fp, fbody)
                            todos += fbody.count("[!todo]")
                if doku == "vollständig" and todos:
                    rep.warn(p, f"dokumentation: vollständig, aber {todos} [!todo] im Konzept")
                row["todo"] += todos
            summary.append(row)
        # übrige Notizen im Architekturordner: nur Links
        for dp, dn, fn in os.walk(arch):
            if os.sep + "mart_" in dp + os.sep:
                continue
            for f in fn:
                if f.endswith(".md"):
                    fp = os.path.join(dp, f)
                    check_links(rep, fp, frontmatter(open(fp, encoding="utf-8").read())[1])

    print("Konzept              IM            RV            Objekte  [!todo]")
    for r in summary:
        print(f"{r['konzept']:<20} {r['im']:<13} {r['rv']:<13} {r['objekte']:>7}  {r['todo']:>7}")
    print()
    for w in rep.warnings:
        print("WARNUNG", w)
    for e in rep.errors:
        print("FEHLER ", e)
    print(f"\n{len(rep.errors)} Fehler, {len(rep.warnings)} Warnungen")
    sys.exit(1 if rep.errors else 0)


if __name__ == "__main__":
    main()
