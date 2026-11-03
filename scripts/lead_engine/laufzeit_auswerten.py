#!/usr/bin/env python3
"""Laufzeit je dbt-Modell aus run_results.json auswerten.

Aufruf (auf der VM oder lokal):
    python3 scripts/lead_engine/laufzeit_auswerten.py [pfad/zu/run_results.json] [--top 10]
Standard: target/run_results.json. Ausgabe: Gesamtlaufzeit, Summe der Modell- und Testzeiten, Top-Modelle, Aufteilung nach Schicht.
Die Summen sind Rechenzeit (bei threads > 1 groesser als die Wanduhrzeit "elapsed_time").
"""
import json
import sys
from collections import defaultdict

args = [a for a in sys.argv[1:] if not a.startswith("--")]
top = int(sys.argv[sys.argv.index("--top") + 1]) if "--top" in sys.argv else 10
if "--top" in sys.argv:
    args = [a for a in args if a != str(top)]
pfad = args[0] if args else "target/run_results.json"

d = json.load(open(pfad))
res = d["results"]


def schicht(uid):
    name = uid.split(".")[-1]
    if uid.startswith("test."):
        return "tests"
    for pre, s in (("base_", "base"), ("stg_", "staging"), ("hub_", "raw vault"), ("link_", "raw vault"), ("sat_", "raw vault"),
                   ("bv_", "business vault"), ("ref_", "business vault"), ("dim_", "mart"), ("fakt_", "mart"), ("lead_", "mart")):
        if name.startswith(pre):
            return s
    return "sonstige"


zeilen = [(r["execution_time"], r["unique_id"], r["status"]) for r in res]
modelle = [z for z in zeilen if not z[1].startswith("test.")]
tests = [z for z in zeilen if z[1].startswith("test.")]
print(f"Wanduhrzeit (elapsed_time): {d['elapsed_time']/60:.1f} min  | Knoten: {len(res)} (Modelle {len(modelle)}, Tests {len(tests)})")
print(f"Rechenzeit Modelle: {sum(z[0] for z in modelle)/60:.1f} min | Tests: {sum(z[0] for z in tests)/60:.1f} min")
print(f"\nTop {top} Modelle:")
for t, uid, st in sorted(modelle, reverse=True)[:top]:
    print(f"  {t/60:6.1f} min  {uid.split('.')[-1]}  [{st}]")
print(f"\nTop {top} Tests:")
for t, uid, st in sorted(tests, reverse=True)[:top]:
    print(f"  {t/60:6.1f} min  {uid.split('.')[-1][:90]}  [{st}]")
je = defaultdict(float)
for t, uid, st in zeilen:
    je[schicht(uid)] += t
print("\nNach Schicht (Rechenzeit):")
for s, t in sorted(je.items(), key=lambda x: -x[1]):
    print(f"  {t/60:6.1f} min  {s}")
