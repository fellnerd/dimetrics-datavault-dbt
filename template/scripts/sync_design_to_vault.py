#!/usr/bin/env python3
"""Spiegelt Design-Dokumente aus design/ als Markdown-Notizen in einen Obsidian-Vault.

design/ bleibt die Model-First-Quelle (gepflegt über dv-design-sync). Obsidian rendert keine
.mmd-Dateien, nur ```mermaid-Blöcke in .md — dieses Skript erzeugt je Eintrag eine .md mit
Frontmatter, Breadcrumb, Quellverweis und Inhalt:
  - Quelle .mmd → Inhalt als Mermaid-Block
  - Quelle .md  → Inhalt übernommen (eigene H1 entfällt), relative Links auf den Vault-Ort umgerechnet

Zielstruktur im Vault (einheitlich): 04-<mandant>-architektur/raw-vault/, business-vault/,
information-mart/ — je mit Index 00-<ordner>.md. Darunter ein Ordner je Konzept (mart_<konzept>/) mit
Index 00-mart-<konzept>.md. Gruppen dürfen verschachtelt sein: Jede Gruppe, deren Pfad zum Ziel passt,
erscheint im Breadcrumb (von aussen nach innen); der Tag kommt von der innersten Gruppe mit Tag.

Konfiguration: design/vault-sync.json im Repo-Root, z. B.
{
  "vault": "docs",
  "breadcrumb": [["Dokumentation", "README.md"], ["Architektur & Projekt", "04-<mandant>-architektur/00-<mandant>-architektur.md"]],
  "tags": ["typ/er-diagramm"],
  "groups": {
    "04-<mandant>-architektur/raw-vault": {"title": "Raw Vault", "tag": "architektur/raw-vault", "index": "00-raw-vault.md"},
    "04-<mandant>-architektur/raw-vault/mart_<concept>": {"title": "<Concept>", "index": "00-mart-<concept>.md"}
  },
  "diagrams": [
    {"source": "design/raw-vault/<concept>/er-diagram.mmd",
     "target": "04-<mandant>-architektur/raw-vault/<concept>/er-<concept>.md",
     "title": "Raw Vault — <Concept>",
     "extra": "Präsentationsfassung: [er-<concept>.canvas](er-<concept>.canvas)"}
  ]
}

Aufruf (aus dem Repo-Root):
  python3 scripts/sync_design_to_vault.py          # schreibt geänderte Dateien
  python3 scripts/sync_design_to_vault.py --check  # nur prüfen, Exit 1 wenn veraltet (CI)
"""
import json, os, posixpath, re, sys

MARK = "<!-- generiert von scripts/sync_design_to_vault.py aus {src} — nicht von Hand bearbeiten, Änderungen in design/ vornehmen -->"


def rel(target_dir, path):
    return posixpath.relpath(path, target_dir or ".").replace(" ", "%20")


def render(cfg, d):
    vault = cfg["vault"]
    tdir = posixpath.dirname(d["target"])
    groups = cfg.get("groups", {})
    # alle passenden Gruppen von aussen nach innen, z. B. raw-vault/ und raw-vault/mart_telecom/
    matched = sorted((g for g in groups if d["target"].startswith(g + "/")), key=len)
    crumbs = [f"[{t}]({rel(tdir, p)})" for t, p in cfg.get("breadcrumb", [])]
    for g in matched:
        gi = groups[g]
        crumbs.append(f"[{gi.get('title', g)}]({rel(tdir, g + '/' + gi.get('index', 'README.md'))})")
    tag = next((groups[g]["tag"] for g in reversed(matched) if groups[g].get("tag")), None)
    tags = ([tag] if tag else []) + cfg.get("tags", [])
    src_rel = posixpath.relpath(d["source"], posixpath.join(vault, tdir)).replace(" ", "%20")
    body = open(d["source"], encoding="utf-8").read().rstrip("\n")
    out = ["---", "title: " + json.dumps(d["title"], ensure_ascii=False), "tags:"] + [f"  - {t}" for t in tags] + ["---", MARK.format(src=d["source"]), " › ".join(crumbs), "",
           f"# {d['title']}", "",
           f"> **Kopie** von [`{d['source']}`]({src_rel}) — Model-First-Quelle ist `design/` (gepflegt über dv-design-sync).",
           "> Änderungen dort vornehmen und `scripts/sync_design_to_vault.py` ausführen.", ""]
    if d.get("extra"):
        out += [d["extra"], ""]
    if d["source"].endswith(".md"):
        out += [md_body(body, d["source"], posixpath.join(vault, d["target"])), ""]
    else:
        out += ["```mermaid", body, "```", ""]
    return "\n".join(out)


LINK_RE = re.compile(r"(\]\()([^)\s]+)(\))")


def md_body(body, source, target):
    """Markdown-Quelle übernehmen: Frontmatter und erste H1 entfernen, relative Links umrechnen."""
    if body.startswith("---\n"):
        body = body.split("\n---\n", 1)[1]
    body = re.sub(r"\A\s*# [^\n]*\n", "", body, count=1)

    def repl(m):
        link = m.group(2)
        if re.match(r"^[a-z]+:", link) or link.startswith("#"):
            return m.group(0)
        path, sep, anchor = link.partition("#")
        absolute = posixpath.normpath(posixpath.join(posixpath.dirname(source), path.replace("%20", " ")))
        new = posixpath.relpath(absolute, posixpath.dirname(target)).replace(" ", "%20")
        return m.group(1) + new + sep + anchor + m.group(3)

    return LINK_RE.sub(repl, body.strip("\n"))


def main():
    check = "--check" in sys.argv
    cfg = json.load(open("design/vault-sync.json", encoding="utf-8"))
    stale = []
    for d in cfg["diagrams"]:
        path = os.path.join(cfg["vault"], d["target"])
        new = render(cfg, d)
        old = open(path, encoding="utf-8").read() if os.path.exists(path) else None
        if old == new:
            continue
        stale.append(path)
        if not check:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            open(path, "w", encoding="utf-8").write(new)
    verb = "veraltet" if check else "aktualisiert"
    print(f"{len(cfg['diagrams'])} Diagramme, {len(stale)} {verb}" + "".join(f"\n  {p}" for p in stale))
    sys.exit(1 if check and stale else 0)


if __name__ == "__main__":
    main()
