#!/usr/bin/env python3
"""
Deterministischer DV-2.1/dbt-Lint (automate_dv auf SQL Server/Azure SQL).

Zwei Betriebsarten:

1. PostToolUse-Hook (Edit|Write, JSON auf stdin): prueft die gerade geschriebene
   Datei (models/**/*.sql, design/**/*.mmd) und meldet Verstoesse an Claude zurueck
   (Exit 2 + stderr). Keine Meldung = alles OK.
2. Audit:  python dv_lint.py --audit [<projekt-root>] [--all]
   prueft alle Modelle eines Projekts und listet Pflicht-Verstoesse je Datei
   (mit --all auch Hinweise). Exit 1, wenn Pflicht-Verstoesse gefunden wurden.
   Wird auch vom SessionStart-Hook genutzt, damit nicht konforme Bestandsmodelle
   nicht als Vorlage kopiert werden.

Befunde ohne "(Hinweis)" sind Pflicht-Verstoesse gegen die Konvention; "(Hinweis)"
markiert Heuristiken, die im Einzelfall begruendet abweichen duerfen.
"""
import json
import re
import sys
from pathlib import Path

HINT = " (Hinweis)"

RESERVED_KEYWORDS = {
    "PLAN", "LEVEL", "KEY", "STATUS", "TYPE", "ORDER", "GROUP", "INDEX",
    "BEFORE", "AFTER", "FUNCTION", "VALUE", "TABLE", "VIEW", "USER", "ROLE",
    "CHECK", "DEFAULT", "PRIMARY", "FOREIGN", "REFERENCES", "RETURN",
}

# Reine Durchreich-Views (z. B. publizierte Mart-Views dim_x_v = SELECT * FROM dim_x)
PASSTHROUGH_RE = re.compile(r"select\s+\*\s+from\s+\{\{\s*ref\(", re.I)


def is_hint(issue: str) -> bool:
    return issue.endswith(HINT)


# ---------------------------------------------------------------------------
# Modelle
# ---------------------------------------------------------------------------

def lint_model_sql(path: Path, text: str) -> list[str]:
    posix = path.as_posix()
    name = path.stem  # z. B. hub_kunde, sat_kunde__erp, dim_kunde
    in_staging = "/staging/" in posix
    in_vault = "/raw_vault/" in posix
    in_mart = "/mart/" in posix
    issues: list[str] = []

    # --- Pflicht-Metadaten (nicht in reinen Durchreich-Views / Vorbereitungs-Views) ---
    if not PASSTHROUGH_RE.search(text) and not name.startswith(("prep_", "dim_date")):
        for col in ("dss_load_date", "dss_record_source"):
            if col not in text:
                issues.append(f"Pflicht-Metadatenspalte fehlt: {col}")

    # --- Reserved Keywords als YAML-Listeneintraege (stage()/sat()-Metadata) ---
    escape_block = re.search(r"_escape:.*?(?=\n\S|\n{2})", text, re.S)
    escaped = set(re.findall(r'"([^"]+)"', escape_block.group(0))) if escape_block else set()
    for kw in sorted(RESERVED_KEYWORDS):
        if re.search(rf'^\s*-\s*"?{kw}"?\s*$', text, re.M) and kw not in escaped:
            issues.append(
                f"Reserved Keyword '{kw}' als Spalte gelistet, aber nicht im "
                f"_escape-Block — SQL-Server-Fehler wahrscheinlich" + HINT
            )

    if in_staging:
        issues += lint_staging(name, text)
    if in_vault:
        issues += lint_vault(path, name, text)
    if in_mart:
        issues += lint_mart(path, name, text)
    return issues


def _extra_columns_passed(text: str, macro: str) -> bool:
    """src_extra_columns im YAML muss auch an das automate_dv-Macro uebergeben werden."""
    return not ("src_extra_columns:" in text and "src_extra_columns=" not in text)


def lint_staging(name: str, text: str) -> list[str]:
    issues = []
    if "automate_dv.stage(" not in text:
        return issues
    hashed = re.search(r"hashed_columns:(.*?)(?:\{%-?\s*endset|\Z)", text, re.S)
    has_hub_key = bool(hashed and re.search(r"^\s*hk_(?!link_)\w+:", hashed.group(1), re.M))
    if has_hub_key:
        if "dss_create_datetime" not in text:
            issues.append(
                "Staging ohne derived_column dss_create_datetime — Hubs und Satellites "
                "brauchen sie in src_extra_columns"
            )
        if "dss_business_key" not in text:
            issues.append(
                "Staging mit Hub-Hash-Key, aber ohne derived_column dss_business_key "
                "(Klartext-BK der Haupt-Entitaet: CONCAT_WS('||', 'default', 'default', <BK…>)). "
                "FK-Hubs bekommen eine eigene FK-Staging-View <staging>__<entity>" + HINT
            )
    return issues


def lint_vault(path: Path, name: str, text: str) -> list[str]:
    issues = []
    has_config = "config(" in text

    if name.startswith(("hub_", "link_", "sat_")):
        # Config-Pruefung nur bei inline config(); sonst greift die Folder-Config
        normalized = text.replace('"', "'")
        if has_config and "materialized='view'" in normalized:
            issues.append(
                "Vault-Objekt als View materialisiert — Raw Vault muss physisch/"
                "inkrementell sein (Historisierung)"
            )
        if has_config and "as_columnstore" not in text:
            issues.append("config() ohne as_columnstore=false (Azure SQL Basic/Serverless)" + HINT)
        if "create_hash_index" not in text:
            issues.append("post_hook create_hash_index fehlt — Konvention fuer hk_*-Join-Performance" + HINT)

    if name.startswith(("hub_", "link_")) and "__" in name:
        issues.append(
            f"Naming: '{name}' enthaelt '__' — der __source-Suffix gilt nur fuer "
            f"Satellites, nicht fuer Hubs/Links"
        )

    if name.startswith("hub_"):
        issues += lint_hub_business_key(path, text)

    if name.startswith("sat_"):
        issues += lint_satellite(name, text)

    return issues


def lint_satellite(name: str, text: str) -> list[str]:
    issues = []
    special = next((t for t in ("_ma", "_eff", "_tl") if re.search(rf"{t}(__|$)", name)), None)

    if "dss_create_datetime" not in text:
        msg = "Satellite ohne dss_create_datetime in src_extra_columns (nicht im Payload!)"
        # Standard- und Dependent-Child-Satellites: Pflicht; Sondertypen: dringend empfohlen
        issues.append(msg + HINT if special else msg)
    elif not _extra_columns_passed(text, "sat"):
        issues.append(
            "src_extra_columns im YAML definiert, aber nicht an das automate_dv-Macro "
            "uebergeben — die Spalten landen nicht in der Tabelle"
        )
    if re.search(r"src_payload:(?:(?!src_\w+:).)*dss_create_datetime", text, re.S):
        issues.append(
            "dss_create_datetime im src_payload — gehoert in src_extra_columns, sonst "
            "wird jede Zeile bei jedem Lauf eine neue Version"
        )

    m_hd = re.search(r'src_hashdiff:\s*\n\s+source_column:\s*"?(\w+)"?', text)
    if m_hd and "__" not in m_hd.group(1):
        issues.append(f"Hash Diff '{m_hd.group(1)}' ohne __<quelle> (Konvention: hd_<entity>__<quelle>)" + HINT)
    if m_hd:
        if not re.search(r'alias:\s*"?hashdiff"?', text, re.I):
            issues.append(
                'src_hashdiff ohne alias: "hashdiff" — automate_dv erwartet den '
                "Alias, sonst bricht die Change Detection"
            )
    if "src_hashdiff" in text and special != "_tl" and "update_satellite_current_flag" not in text:
        issues.append(
            "Historisierter Satellite ohne update_satellite_current_flag "
            "post_hook — dss_is_current/dss_end_date bleiben leer"
        )
    if "__" not in name:
        issues.append(f"Naming: '{name}' ohne __source-Suffix (Konvention: sat_<entity>__<quelle>)" + HINT)
    return issues


def _find_project_root(path: Path):
    for parent in path.resolve().parents:
        if (parent / "dbt_project.yml").is_file():
            return parent
    return None


def lint_hub_business_key(path: Path, text: str) -> list[str]:
    """Hub-Pflichtspalten + FK-Hub-Falle.

    Jeder Hub fuehrt dss_create_datetime und genau eine Spalte dss_business_key
    (ohne Suffix). Die Falle: ein FK-Hub uebernimmt den dss_business_key seines
    Stagings — der gehoert aber der Haupt-Entitaet des Stagings (z. B. Bestellung
    statt Kunde). FK-Hubs lesen deshalb aus einer eigenen FK-Staging-View.
    """
    issues = []
    if "dss_create_datetime" not in text:
        issues.append("Hub ohne dss_create_datetime in src_extra_columns — Pflichtspalte jedes Hubs")
    suffixed = re.findall(r'"(dss_business_key_[a-z0-9_]+)"', text)
    if suffixed:
        issues.append(
            f"Suffix-Spalte {suffixed[0]} — jeder Hub hat genau EINE Spalte "
            f"dss_business_key ohne Suffix. FK-Hub: eigene FK-Staging-View "
            f"<staging>__<entity> anlegen, die dss_business_key bildet"
        )
    elif not re.search(r'"dss_business_key"', text):
        issues.append(
            "Hub ohne dss_business_key in src_extra_columns — Pflichtspalte jedes Hubs. "
            "FK-Hub: eigene FK-Staging-View <staging>__<entity> anlegen"
        )
    if not _extra_columns_passed(text, "hub"):
        issues.append(
            "src_extra_columns im YAML definiert, aber nicht an automate_dv.hub() "
            "uebergeben — die Spalten landen nicht in der Tabelle"
        )

    # FK-Hub-Falle: plain dss_business_key, dessen Staging-Ausdruck den src_nk nicht enthaelt
    uses_plain = re.search(r'-\s*"dss_business_key"\s*$', text, re.M)
    m_src = re.search(r'source_model:\s*"([^"]+)"', text)
    m_nk = re.search(r'src_nk:\s*"([^"]+)"', text)
    root = _find_project_root(path)
    if uses_plain and m_src and m_nk and root:
        stg = next((root / "models").rglob(f"{m_src.group(1)}.sql"), None)
        if stg and stg.is_file():
            expr = re.search(r'dss_business_key:\s*"([^"]+)"', stg.read_text(errors="ignore"))
            if expr and m_nk.group(1).lower() not in expr.group(1).lower():
                issues.append(
                    f"FK-Hub-Falle: dss_business_key aus '{m_src.group(1)}' enthaelt den "
                    f"Schluessel '{m_nk.group(1)}' nicht — er gehoert der Haupt-Entitaet "
                    f"des Stagings. Eigene FK-Staging-View <staging>__<entity> anlegen, "
                    f"die dss_business_key fuer diese Entitaet bildet"
                )
    return issues


def lint_mart(path: Path, name: str, text: str) -> list[str]:
    """Mart-Hausmuster: dim_*/fakt_* als Tabelle + publizierte *_v-View, BIGINT-Surrogate-Keys."""
    issues = []
    if name.startswith("fact_"):
        issues.append(f"Naming: '{name}' — Faktentabellen heissen fakt_<inhalt> (nicht fact_)")
    is_dim = name.startswith("dim_") and name != "dim_date"
    is_fakt = name.startswith(("fakt_", "fact_"))
    if not (is_dim or is_fakt):
        return issues

    if name.endswith("_v"):
        normalized = text.replace('"', "'")
        if "materialized='view'" not in normalized:
            issues.append("Publizierte Mart-View *_v ohne materialized='view'" + HINT)
        return issues

    if "surrogate_key(" not in text:
        issues.append(
            "Kein {{ surrogate_key(...) }} — Dimensions-/Fakt-Keys sind BIGINT-Surrogate-Keys "
            "(<dim>_key), nie hk_*-Hashes, ROW_NUMBER() oder Identity"
        )
    if is_dim:
        for suffix in ("_key", "_id", "_code", "_name"):
            if not re.search(rf"\bAS\s+\w+{suffix}\b", text, re.I):
                issues.append(f"Dimension ohne Pflichtspalte <dim>{suffix}")
        if not re.search(r"-1\b", text):
            issues.append("Dimension ohne Unbekannt-Zeile (<dim>_key = -1) fuer fehlende Bezuege" + HINT)
        # Stern, kein Snowflake: Key einer anderen Dimension desselben Ordners
        own = name[len("dim_"):]
        siblings = {p.stem[len("dim_"):] for p in path.parent.glob("dim_*.sql")
                    if not p.stem.endswith("_v")} - {own}
        foreign = sorted({k for k in re.findall(r"\bAS\s+(\w+)_key\b", text, re.I)
                          if k.lower() in siblings})
        if foreign:
            issues.append(
                "Dimension fuehrt Key(s) anderer Dimensionen (" + ", ".join(f"{k}_key" for k in foreign)
                + ") — Stern, kein Snowflake: Zugehoerigkeit als Attribut (<x>_code/<x>_name), "
                "den Key in die Fakten"
            )
    if "tags=" not in text.replace(" ", ""):
        issues.append("config() ohne tags=['dimension'] bzw. tags=['fact']" + HINT)
    if re.search(r"\{\{\s*ref\(\s*['\"](stg_|ext_)", text):
        issues.append("Mart liest Staging direkt — Marts lesen ausschliesslich den Vault" + HINT)

    view = path.with_name(f"{name}_v.sql")
    if not view.exists():
        issues.append(f"Publizierte View {name}_v fehlt (BI-Schnittstelle, spaeter RLS)" + HINT)
    return issues


# ---------------------------------------------------------------------------
# Design-Diagramme
# ---------------------------------------------------------------------------

def lint_mermaid(path: Path, text: str, project_dir: Path) -> list[str]:
    """Drift-Check: Objekte im ER-Diagramm vs. Modell-Dateien (beide Richtungen)."""
    issues = []
    diagram_objs = set(re.findall(r"\b((?:hub|sat|link)_[a-z0-9_]+)\b", text.lower()))
    # Diagramm gilt je Konzept: design/raw-vault/<concept>/… ↔ models/raw_vault/<concept>/…
    concept = path.parent.name
    concept_dir = project_dir / "models" / "raw_vault" / concept
    if not concept_dir.is_dir():
        return issues  # reines Design-Stadium
    model_files = {
        p.stem.lower()
        for p in concept_dir.glob("**/*.sql")
        if p.stem.lower().startswith(("hub_", "sat_", "link_"))
    }
    if not model_files:
        return issues
    missing_in_diagram = sorted(model_files - diagram_objs)
    missing_as_model = sorted(diagram_objs - model_files)
    if missing_in_diagram:
        issues.append("Modelle ohne Eintrag im ER-Diagramm: " + ", ".join(missing_in_diagram))
    if missing_as_model:
        issues.append(
            "Im Diagramm, aber keine Modell-Datei (geplant? dann OK): "
            + ", ".join(missing_as_model) + HINT
        )
    return issues


# ---------------------------------------------------------------------------
# Audit (ganzes Projekt)
# ---------------------------------------------------------------------------

def audit(root: Path, include_hints: bool = False) -> dict[str, list[str]]:
    """Alle Modelle eines Projekts pruefen -> {relativer Pfad: [Befunde]}."""
    result: dict[str, list[str]] = {}
    models = root / "models"
    if not models.is_dir():
        return result
    for p in sorted(models.rglob("*.sql")):
        found = lint_model_sql(p, p.read_text(errors="replace"))
        if not include_hints:
            found = [i for i in found if not is_hint(i)]
        if found:
            result[p.relative_to(root).as_posix()] = found
    return result


def _utf8_streams() -> None:
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8")
        except (AttributeError, ValueError):
            pass


def main() -> None:
    _utf8_streams()

    if "--audit" in sys.argv:
        args = [a for a in sys.argv[1:] if not a.startswith("--")]
        root = Path(args[0]) if args else Path(".")
        findings = audit(root.resolve(), include_hints="--all" in sys.argv)
        for rel, found in findings.items():
            print(rel)
            for i in found:
                print(f"  - {i}")
        total = sum(len(v) for v in findings.values())
        print(f"\n{len(findings)} Datei(en), {total} Befund(e).")
        sys.exit(1 if any(not is_hint(i) for v in findings.values() for i in v) else 0)

    try:
        hook_input = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)

    file_path = (hook_input.get("tool_input") or {}).get("file_path", "")
    if not file_path:
        sys.exit(0)

    path = Path(file_path)
    project_dir = Path(hook_input.get("cwd") or ".")
    posix = path.as_posix()
    if not path.exists():
        sys.exit(0)

    issues: list[str] = []
    if posix.endswith(".sql") and "/models/" in posix:
        issues = lint_model_sql(path, path.read_text(errors="replace"))
    elif posix.endswith(".mmd") and "/design/" in posix:
        issues = lint_mermaid(path, path.read_text(errors="replace"), project_dir)

    if issues:
        print(
            f"DV-Lint für {path.name}:\n" + "\n".join(f"  - {i}" for i in issues),
            file=sys.stderr,
        )
        sys.exit(2)  # stderr geht als Feedback an Claude

    sys.exit(0)


if __name__ == "__main__":
    main()
