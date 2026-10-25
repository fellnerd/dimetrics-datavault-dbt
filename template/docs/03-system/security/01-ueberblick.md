---
title: "Überblick"
tags:
  - system/security
---
[Dokumentation](../../README.md) › [Data Vault 2.1 – Systemdokumentation](../00-systemdokumentation.md) › [Security](00-security.md)

# Überblick

## Die drei Schichten

| Schicht | Frage | Antwort bei fehlender Berechtigung |
|---|---|---|
| **OLS** – Objektzugriff | Darf ich das Objekt überhaupt lesen? | Fehler: „permission denied" |
| **RLS** – Zeilenfilter | Welche Zeilen sehe ich darin? | **0 Zeilen, kommentarlos** |
| **CLS** – Spaltenmaskierung | Sehe ich den Inhalt dieser Spalte? | `***` statt des Werts |

Der Unterschied zwischen OLS und RLS ist im Alltag der wichtigste Diagnose-Hinweis: **eine Fehlermeldung ist ein OLS-Problem, null Zeilen ein RLS-Problem.**

## Die drei Grundentscheidungen

Jede ist durch einen konkreten Fehlermodus begründet, keine ist Geschmackssache.

### 1. Nur Views werden berechtigt, niemals Schemas

Ein Schema-Grant (`GRANT SELECT ON SCHEMA::mart_finance`) gibt **alles** frei — auch die physischen Performance-Caches wie `fakt_buchungen` oder `dim_konto`. Endnutzer sollen nur den publizierten Vertrag sehen, die `_v`-Views.

Objekt-Grants überleben keinen `dbt run` (dbt erstellt Views jedes Mal neu, Rechte sterben mit dem Objekt). Deshalb werden sie **nach jedem Lauf neu gesetzt** — Details in [03 – OLS](03-ols-view-grants.md).

### 2. Der Zeilenfilter liegt auf der Dimension, nicht auf dem Fakt

Die Prüffunktion läuft **pro Zeile**. Auf einem Fakt mit 900.000 Zeilen dominiert sie alles; auf der Dimension mit 157 Zeilen kostet sie fast nichts. Die Fakten erben den Filter über den `INNER JOIN`.

Gemessen in einem Referenzprojekt:

| Variante | ms | logische Reads |
|---|---|---|
| Filter auf dem Fakt (+ Security Policy) | 2.201 | 3.697.737 |
| Filter auf der Dimension | **273** | **31.069** |
| Referenz: gleicher Scan ohne Security | 221 | 30.744 |

Die abgesicherte View ist damit schneller, als die ungesicherte Tabelle es vorher war. Details in [04 – RLS](04-rls-dimensional.md).

### 3. Ohne Eintrag sieht niemand etwas (Deny-by-default)

Es gibt **keine** Regel „kein Eintrag = alles sehen". Wer nicht ausdrücklich berechtigt ist, sieht null Zeilen. Das ist die sichere Richtung, hat aber eine Konsequenz, die beim Berechtigen überrascht: Eine Fakt-View joint **zwei** Dimensionen, also braucht jeder Nutzer auf **beiden Achsen** ein Recht — auch auf der, wo er gar nicht eingeschränkt ist. Siehe [05 – Berechtigung vergeben](05-berechtigung-vergeben.md).

## Objektlandkarte (Finance)

```
                    sec.sec_user_privilege          ← wer darf was (Einzelrechte)
                    sec.sec_group_privilege         ← wer darf was (Gruppen)
                    sec.sec_special_user_privilege  ← Ausnahmen (Service-User)
                              │
                              ▼
                    sec.fn_check_rls(schlüssel, kontext)
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
   dim_kostenstelle_v                   dim_konto_v
   Kontext 'finance_kst'                Kontext 'finance_konto'
   FILTER                               FILTER
              │                               │
              └───────────────┬───────────────┘
                              │  INNER JOIN (beide)
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
      fakt_buchungen_v  fakt_budget_v  fakt_forecast_v
      erben den Filter — kein eigener Filter nötig
```

Die beiden Dimensionen sind die **Träger** der Berechtigung. Alles andere erbt.

Nicht abgedeckt: `fakt_belege_v` — Kreditorenbelege haben keine Kostenstelle und können von dieser Dimension nichts erben.

## Was es NICHT (mehr) gibt

- **Keine Security Policies.** Die native `SECURITY POLICY` auf `fakt_buchungen` wurde entfernt: Seit nur noch Views berechtigt werden, ist die Tabelle für Endnutzer ohnehin unerreichbar — und die Policy kostete 2 logische Reads pro Basiszeile.
- **Keine Schema-Grants.** Ein Test schlägt an, sobald einer auftaucht.
- **Keine invertierte Logik.** Bewusst verworfen: Die Prüffunktion verknüpft ihre Zweige mit `ODER`, ein pauschales Recht würde jede Einzeleinschränkung aufheben.

---

[Übersicht](00-security.md) · [Berechtigung vergeben](05-berechtigung-vergeben.md) ▶
