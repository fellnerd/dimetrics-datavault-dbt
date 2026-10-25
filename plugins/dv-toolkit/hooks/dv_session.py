#!/usr/bin/env python3
"""
SessionStart-Hook: laedt in dbt/automate_dv-Projekten die Pflichtkonventionen in den
Kontext und meldet, welche Bestandsmodelle sie verletzen.

Warum: Ohne diesen Anstoss orientiert sich Claude an vorhandenen Modellen — sind die
selbst nicht konform, wird der Fehler weiterkopiert. Die Stdout-Ausgabe eines
SessionStart-Hooks landet als Kontext in der Sitzung. In Nicht-dbt-Projekten: keine Ausgabe.
"""
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

MAX_FILES = 12


def _is_dv_project(root: Path) -> bool:
    if not (root / "dbt_project.yml").is_file():
        return False
    packages = root / "packages.yml"
    return packages.is_file() and "automate_dv" in packages.read_text(errors="ignore")


def main() -> None:
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8")
        except (AttributeError, ValueError):
            pass
    try:
        hook_input = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        hook_input = {}
    root = Path(hook_input.get("cwd") or ".").resolve()
    if not _is_dv_project(root):
        sys.exit(0)

    print((HERE / "pflichtkonventionen.md").read_text(encoding="utf-8").rstrip())

    try:
        from dv_lint import audit
        findings = audit(root)
    except Exception as exc:  # Audit darf den Sitzungsstart nie blockieren
        print(f"\n(Konventions-Audit übersprungen: {exc})")
        sys.exit(0)

    if not findings:
        print("\nAudit: alle Modelle erfüllen die Pflichtkonventionen.")
        sys.exit(0)

    total = sum(len(v) for v in findings.values())
    print(
        f"\nAudit: {len(findings)} Modell(e) verletzen Pflichtkonventionen ({total} Befunde) — "
        "diese NICHT als Vorlage verwenden; beim Anfassen angleichen bzw. dem User melden:"
    )
    for rel, found in list(findings.items())[:MAX_FILES]:
        print(f"- {rel}: {found[0]}" + (f" (+{len(found) - 1})" if len(found) > 1 else ""))
    if len(findings) > MAX_FILES:
        print(f"- … {len(findings) - MAX_FILES} weitere. Vollständig: python <plugin>/hooks/dv_lint.py --audit .")
    sys.exit(0)


if __name__ == "__main__":
    main()
