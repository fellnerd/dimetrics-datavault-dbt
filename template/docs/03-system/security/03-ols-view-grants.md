---
title: "OLS – Objektzugriff"
tags:
  - system/security
---
[Dokumentation](../../README.md) › [Data Vault 2.1 – Systemdokumentation](../00-systemdokumentation.md) › [Security](00-security.md)

# OLS – Objektzugriff

**Regel: Endnutzer bekommen `SELECT` ausschließlich auf `_v`-Views.**

Keine Schema-Grants, keine Grants auf physische Tabellen, keine Grants auf `stg`, `vault*` oder `sec`.

## Warum keine Schema-Grants?

`GRANT SELECT ON SCHEMA::mart_finance` gibt alles im Schema frei — auch die physischen Performance-Caches, die im selben Schema liegen:

| Objekt | Typ | berechtigt? |
|---|---|---|
| `fakt_buchungen_v` | VIEW | ✅ |
| `fakt_buchungen` | TABLE | ❌ |
| `dim_konto_v` | VIEW | ✅ |
| `dim_konto` | TABLE | ❌ |

Die Views lesen ihre Caches trotzdem — über **Ownership Chaining**, weil alle Objekte `dbo` gehören. Genau so lesen sie auch aus `vault`, ohne dass dort je ein Grant nötig war.

## Wie die Grants den `dbt run` überleben

Gar nicht — sie werden **nach jedem Lauf neu gesetzt**. dbt erstellt Views bei jedem Run neu, objektbezogene Rechte sterben mit dem Objekt.

```yaml
# dbt_project.yml
on-run-end:
  - "{{ log_load_status() }}"
  - "{{ grant_select_on_views() }}"

vars:
  ols_view_grants:
    <gruppen-prefix>-finance-employees-ro: ['mart', 'mart_finance']
    <gruppen-prefix>-project-ro: ['mart', 'mart_project']
    <gruppen-prefix>-sales-ro:   ['mart', 'mart_sales']
    rls_test:                ['mart', 'mart_finance']   # Dev-Testuser
```

Das Macro [`grant_select_on_views()`](../../../macros/security/grant_select_on_views.sql) iteriert über **`sys.views`**. Das ist der entscheidende Punkt:

> Eine physische Tabelle kann gar keinen Grant bekommen — nicht weil jemand daran denkt, sondern weil sie in der Quelle nicht vorkommt. Der Schutz ist **strukturell**, nicht prozedural. Ein neues `_v`-Model ist automatisch berechtigt, ein neuer Cache automatisch nicht.

Principals, die in der Ziel-Datenbank nicht existieren, werden still übersprungen — derselbe Var-Block funktioniert auf dev (SQL-Testuser) wie auf prod (Entra-Gruppen).

Im Log erscheint je Principal eine Zeile:

```
OLS: 13 View-Grants fuer <gruppen-prefix>-finance-employees-ro gesetzt (mart, mart_finance).
```

## Folgeregel: jeder Cache braucht eine Wrapper-View

Ein physisches Model ohne `_v`-View ist für Konsumenten **unerreichbar**. Muster:

```
dim_beleg.sql       materialized='table'   ← Logik, kein Grant
dim_beleg_v.sql     materialized='view'    ← publiziert, berechtigt
```

> Historischer Stolperstein: `dim_beleg_v` war selbst eine **Tabelle** mit `_v`-Suffix. Unter Schema-Grants fällt so etwas nie auf; bei der Umstellung auf View-Grants wäre das Objekt schlagartig unsichtbar geworden. Seither aufgeteilt in `dim_beleg` + `dim_beleg_v`.

## Namenskonvention der Gruppen

```
<gruppen-prefix>-<bereich>-ro
```

Je nach Organisation werden die Gruppen direkt in Entra ID oder im **lokalen AD** angelegt und dann per Entra-Connect-Sync nach Azure synchronisiert (Sync-Intervall beachten). In der Datenbank wird der Name verwendet, unter dem die Gruppe in Entra ID erscheint.

## Das Gruppenmodell

Zwei Gruppen mit klar getrennten Aufgaben:

| Gruppe | Mitglieder | `ols_view_grants` | `sec_group_privilege` |
|---|---|---|---|
| `<gruppen-prefix>-finance-employees-ro` | **alle** Finance-Nutzer | ✅ | — |
| `<gruppen-prefix>-finance-full-ro` | nur die **uneingeschränkten** | — | ✅ 2 Zeilen (`<mandant>` je Achse) |

Die erste Gruppe regelt nur den Objektzugriff und trägt **keine** Zeile in `sec_group_privilege`. Bekäme sie eine, hätten per ODER-Logik alle Mitglieder Vollzugriff — auch die eingeschränkten.

**Eingeschränkte Nutzer dürfen nicht in der zweiten Gruppe sein.** Sie bekommen ihre Rechte einzeln in `sec_user_privilege`.

## Kontrolle

```bash
dbt test -s assert_only_views_granted_in_mart --target <ziel>
```

Der Test schlägt an bei jedem Schema-Grant auf `mart*` und bei jedem Objekt-Grant auf einer physischen Tabelle. Ohne ihn driftet die Konvention zurück.

---

◀ [Das sec-Schema](02-sec-schema.md) · [Übersicht](00-security.md) · [RLS – Zeilenfilter über Dimensionen](04-rls-dimensional.md) ▶
