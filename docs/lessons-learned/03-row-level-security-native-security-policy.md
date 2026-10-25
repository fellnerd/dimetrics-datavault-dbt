---
title: "Row-Level Security"
tags:
  - lessons-learned
---
[Dokumentation](../README.md) › [Lessons Learned](00-lessons-learned.md)

# 2. Row-Level Security

> Aktueller Stand und Anleitung: **[Security](../03-system/security/00-security.md)**. Dieses Kapitel hält fest, *warum* es so gebaut ist und was gemessen wurde.

### RLS wertet pro Basiszeile aus, auch für global exemptierte User

`sec.fn_check_rls` hat 4 OR-Branches; Branch 1+2 (Admin-Bypass) hängen **nicht** von der pro-Zeile wechselnden Spalte `@sec_value_key` ab. Trotzdem: gemessen **~2.03 logische Reads pro Zeile** (163.015 Reads bei 80.247 Zeilen test-DB; 1.850.944 bei 911.394 Zeilen dev-DB — exakt dasselbe Verhältnis) statt der erwarteten ~1 Read/Zeile, obwohl `sqladmin` per `no_sec=1` global exemptiert ist.

### Versuchter Fix (CTE-Isolation) hat NICHT funktioniert — nicht wiederholen

Idee: Branch 1+2 in eine eigene `WITH bypass AS (...)` CTE isolieren, damit der Optimizer sie einmalig statt pro Zeile auswertet. **Ergebnis nach Deploy + Messung: identisches Read-Verhältnis wie vorher, keine Verbesserung.** Grund: benannte CTEs sind in SQL Server keine Materialisierungs-Grenze — sie werden beim Kompilieren genauso "entfaltet" wie inline geschriebene Bedingungen. Zusätzlich ist `fn_check_rls` eine **Inline-TVF** (bestätigt `is_inlineable=True`), die beim Planbau komplett in die äußere Query expandiert wird — es gibt zum Optimierungszeitpunkt keine "Funktionsgrenze" mehr, an der eine CTE-Isolation greifen könnte. **Falls RLS-Overhead später wieder zum Flaschenhals wird: einen fundamental anderen Ansatz probieren (z.B. echte Materialisierung des Bypass-Checks über eine Session-gecachte Tabelle), nicht diese Variante wiederholen.**

Änderung wurde nach Test zurückgebaut (kein Netto-Nutzen, aber unnötige Komplexität).

### Dimensionale Absicherung: 8x schneller, 119x weniger Reads

Gemessen in einem Referenzprojekt, `fakt_buchungen` mit 915.841 Zeilen, Aggregation `COUNT(*) + SUM(betrag)`, Mittel aus drei warmen Läufen (`dbt run-operation measure_rls_overhead`):

| Objekt / Zustand | ms | logische Reads | Reads je Zeile |
|---|---|---|---|
| `fakt_buchungen` — Tabelle **mit** Policy | 1.482 | 1.862.428 | 2,03 |
| `fakt_buchungen_v` — Policy + View-Filter + Join | 2.201 | 3.697.737 | 4,04 |
| `fakt_buchungen` — Tabelle **ohne** Policy (reiner Scan) | 221 | 30.744 | 0,03 |
| `fakt_buchungen_v` — nur dimensionaler Join, Dimension als View | 342 | 33.425 | 0,04 |
| **`fakt_buchungen_v` — Dimension materialisiert (Endstand)** | **273** | **31.069** | **0,03** |
| `dim_kostenstelle_v` — gefiltert, als View über ref_kostenstelle_v | 58 | 1.938 | 12,3 |
| `dim_kostenstelle_v` — gefiltert, auf materialisierter Tabelle | 0 | 325 | 2,1 |

**Die Kosten der Prüffunktion pro Zeile haben sich nicht geändert — geändert hat sich, auf wie vielen Zeilen sie ausgewertet wird.** Vorher 915.841 Mal je Absicherung (und davon gab es zwei), jetzt 157 Mal auf der Dimension.

Gegen den reinen Scan (30.744 Reads) gerechnet kostet die gesamte Row-Level-Security im Endstand noch **325 logische Reads** — gegenüber 3.697.737 zuvor. Das ist Faktor 11.000.

Daraus folgt die Faustregel: **den Zeilenfilter auf das kleinste Objekt legen, das den Zugriffsbereich definiert** — die Dimension, nicht den Fakt. Der Fakt erbt über den INNER JOIN. Voraussetzung ist, dass die Dimension jede im Fakt vorkommende Ausprägung enthält, sonst unterschlägt der Join stillschweigend Zeilen (bei uns: 6 fehlende Kostenstellen / 936 Budget-Zeilen, vorher nur als `severity: warn` sichtbar).

### CTE gegen doppelten View-Zugriff funktioniert nicht (zweiter Anlauf)

`dim_kostenstelle_v` liest `ref_kostenstelle_v` zweimal — einmal fürs Kostenstellen-Universum, einmal für die Attribute. Diese View hängt über Staging an einer externen Parquet-Tabelle (556 Reads je Zugriff). Der Versuch, sie in eine benannte CTE zu ziehen, machte es **schlechter**: 1.938 → 2.654 Reads. Benannte CTEs sind in SQL Server keine Materialisierungsgrenze — genau wie beim RLS-CTE-Versuch weiter unten. Zurückgebaut.

**Der wirksame Hebel war Materialisierung**: `dim_kostenstelle` als Tabelle plus `dim_kostenstelle_v` als gefilterter Wrapper, Muster `dim_konto`/`dim_konto_v`. Damit verschwindet der externe Parquet-Zugriff aus dem DirectQuery-Pfad — und die Dimension liegt seit der dimensionalen Absicherung auf dem kritischen Pfad **jeder** Abfrage gegen `fakt_buchungen_v`. Gemessen: Dimension 1.938 → 325 Reads, Fakt-View 342 → 273 ms.

Merksatz: gegen wiederholten Zugriff auf eine teure View hilft in SQL Server nur Materialisierung, nie eine CTE.

### Security Policies können sehr wohl an Views binden (Doku war falsch)

Unser Architekturdokument behauptete, native Security Policies könnten nicht an Views gebunden werden — daher der eingebettete `rls_filter` in den `_v`-Views. Ein anderes Referenzkonzept zeigt das Gegenteil: dort binden Policies mit **`schemabinding = off`** direkt an Views (z. B. `policy_hr` auf `<datenbank>.hr.dim_organisation_v`). `schemabinding = off` ist dort nötig, weil die Prüffunktion in einer anderen Datenbank liegt.

**An unserer Umsetzung ändert das nichts** — der eingebettete Filter bleibt, weil er im dbt-Code sichtbar und versioniert ist (eine Policy ist unsichtbare DDL, auffindbar nur über `sys.security_policies`) und für den Optimizer transparent bleibt. Aber die Begründung „geht technisch nicht" war falsch und ist korrigiert. **Der konkrete Nachweis auf Azure SQL steht noch aus.**

### OLS: Grants nur auf Views, gesetzt per on-run-end-Hook

Ausgangslage war `GRANT SELECT ON SCHEMA::mart_finance` — das gibt auch die physischen Performance-Caches (`fakt_buchungen`, `dim_konto`) frei. Begründung damals: Objekt-Grants überleben den `dbt run` nicht, weil dbt Objekte neu erstellt.

Die Lösung ist nicht, das Problem zu umgehen, sondern die Grants **nach jedem Run neu zu setzen** (`grant_select_on_views()` in `on-run-end`). Entscheidend ist, **woraus die Schleife liest**: aus `sys.views`. Eine physische Tabelle kann dadurch gar keinen Grant bekommen — der Schutz ist strukturell, nicht prozedural. Ein `post_hook` je Model oder eine gepflegte Objektliste wäre vergessbar gewesen; diese Konstruktion ist es nicht.

Beim Umbau aufgefallen: **`dim_beleg_v` war eine Tabelle mit `_v`-Suffix.** Unter Schema-Grants fällt so etwas nicht auf, unter View-Grants wird das Objekt schlagartig unerreichbar. Seither aufgeteilt in `dim_beleg` + `dim_beleg_v`, und der Test `assert_only_views_granted_in_mart` hält die Konvention fest.

### Security-DDL wird bewusst NICHT über dbt deployed

`security/ddl/*.sql` (inkl. `fn_check_rls`) wird laut `security/DEPLOYMENT.md` **manuell in SSMS** deployed, dev→test→prod, mit eigenem Verifikationsprotokoll. Ein automatisierter Sicherheitsfilter (Auto-Mode-Classifier) blockiert `DROP SECURITY POLICY`/ähnliche DDL auch bei explizitem User-Chat-Approval, unabhängig vom verwendeten Shell-Tool (Bash und PowerShell gleichermaßen betroffen) — das ist eine bewusste, werkzeugübergreifende Grenze, kein Bug. **Solche Schritte muss der User selbst ausführen; nicht versuchen zu umgehen.**

---

◀ [dbt-Modellierung / Materialisierung](02-dbt-modellierung-materialisierung.md) · [Übersicht](00-lessons-learned.md) · [DAX-Fallstricke](04-dax-fallstricke.md) ▶
