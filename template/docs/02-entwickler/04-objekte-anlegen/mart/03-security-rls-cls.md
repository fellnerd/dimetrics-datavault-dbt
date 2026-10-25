---
title: "Security in Mart-Models (RLS/CLS)"
tags:
  - entwickler/mart
---
[Dokumentation](../../../README.md) › [Data Vault 2.1 – Developer Guide](../../00-entwicklerhandbuch.md) › [Objekte anlegen](../00-objekte-anlegen.md) › [Mart](00-mart.md)

# Security in Mart-Models (RLS/CLS)

> Kurzfassung für Modellentwickler. Vollständige Referenz: **[03-system/security/](../../../03-system/security/00-security.md)** — insbesondere [Neues Objekt absichern](../../../03-system/security/06-neues-objekt-absichern.md).

## Das Grundprinzip in einem Satz

**Der Zeilenfilter liegt auf der Dimension, die Fakten erben ihn über den `INNER JOIN`.**

```
dim_kostenstelle_v   Kontext 'finance_kst'     ← FILTER
dim_konto_v          Kontext 'finance_konto'   ← FILTER
        │
        │ INNER JOIN
        ▼
fakt_buchungen_v · fakt_budget_v · fakt_forecast_v   ← erben, kein eigener Filter
```

## Die vier Regeln

### Regel 1: Nur Views werden berechtigt

Physische Models (`materialized='table'`) bekommen **keinen** Grant — der `on-run-end`-Hook `grant_select_on_views()` iteriert über `sys.views`. Deshalb braucht **jeder physische Cache eine `_v`-Wrapper-View**, sonst ist er für Konsumenten unerreichbar.

```
dim_beleg.sql      materialized='table'   ← Logik, kein Grant
dim_beleg_v.sql    materialized='view'    ← publiziert, berechtigt
```

Eine Tabelle mit `_v`-Suffix ist ein Fehler.

### Regel 2: Träger-Dimensionen führen `dss_sec_value_key` und filtern

Nur Dimensionen, die einen **Zugriffsbereich** definieren (Kostenstelle, Konto, …). Der Schlüssel ist ein hierarchischer Pfad, die Prüffunktion matcht per Prefix:

```sql
-- dim_kostenstelle.sql (Tabelle, ungefiltert)
{{ sec_value_key("CONCAT_WS('||', ISNULL(CAST(rk.Bereich_L1 AS NVARCHAR(255)), '?'),
                                  CAST(b.kostenstelle_nr AS NVARCHAR(50)))") }} AS dss_sec_value_key

-- dim_kostenstelle_v.sql (View, gefiltert)
SELECT <spalten> FROM {{ ref('dim_kostenstelle') }}
WHERE {{ rls_filter('finance_kst') }}
```

Träger-Dimensionen **materialisieren** — sie liegen auf dem kritischen Pfad jeder Fakt-Abfrage.

Plug-/Ghost-Zeilen müssen immer durch:

```sql
WHERE konto_key < 0 OR {{ rls_filter('finance_konto') }}
```

### Regel 3: Fakt-Views joinen die Träger-Dimensionen

```sql
SELECT f.*
FROM {{ ref('fakt_buchungen') }} f
INNER JOIN {{ ref('dim_kostenstelle_v') }} d ON d.kostenstelle_key = f.kostenstelle_key
INNER JOIN {{ ref('dim_konto_v') }}        k ON k.konto_key        = f.konto_key
```

**Vorher prüfen, dass die Dimension vollständig ist** — sonst unterschlägt der `INNER JOIN` Zeilen, still und auch für Admins:

```sql
SELECT COUNT(*) FROM <fakt> f
WHERE NOT EXISTS (SELECT 1 FROM <dimension> d WHERE d.<key> = f.<key>);   -- 0 erwartet
```

Danach den `relationships`-Test auf `severity: error` setzen.

### Regel 4: PII-Spalten → `cls_mask`, Tier-1 nie in den Mart

```sql
{{ cls_mask('person_name', 'person_pii') }}           AS person_name,
{{ cls_mask('geburtsdatum', 'person_pii', 'NULL') }}  AS geburtsdatum,
```

**Tier-1-Spalten** (`SOC_INSURANCE_NR`, `ZEMIS_NR`, `BADGE_ID`) dürfen in **keinem** Mart-Objekt auftauchen — Vorsicht bei `SELECT *` aus Satellites. Der Test `assert_no_tier1_columns_in_mart` schlägt sonst an.

## Referenz-Implementierungen

| Muster | Model |
|---|---|
| Träger-Dimension (Tabelle + gefilterter Wrapper) | `dim_kostenstelle.sql` / `dim_kostenstelle_v.sql` |
| Träger-Dimension mit Plug-Ausnahme | `dim_konto_v.sql` |
| Fakt, der beide Achsen erbt | `fakt_buchungen_v.sql` |
| Fakt mit gekapseltem SELECT + Join | `fakt_budget_v.sql` |
| Physischer Cache ohne Grant | `dim_beleg.sql` / `dim_beleg_v.sql` |
| Dimension mit `cls_mask` | `mart/project/dim_person_v.sql` |

## Häufige Fehler

| Symptom | Ursache |
|---|---|
| `dbt run`: „Invalid object name 'sec.fn_check_rls'" | `security/ddl/*.sql` auf der Ziel-DB nicht deployed |
| „Invalid column name 'dss_sec_value_key'" im `WHERE` | Der Schlüssel ist ein SELECT-Alias — in einer CTE erzeugen und außen filtern |
| „Ambiguous column name 'dss_sec_value_key'" | Nach einem Join qualifizieren: `rls_filter('…', 'f.dss_sec_value_key')` |
| Neues Model für User nicht sichtbar | `table` ohne `_v`-Wrapper-View |
| Zeilen fehlen auch für Admins | Dimension unvollständig, `INNER JOIN` schluckt sie |
| Zwischensummen weg im Report | Plug-Zeilen (`konto_key < 0`) werden mitgefiltert |
| Marts/Tests plötzlich leer, kein Fehler | Service-User-Exemption (`no_sec=1`) fehlt |

## Nach jeder Änderung

```bash
dbt run  -s <models> --target <mandant>-dev
dbt test -s <models> tests/security --target <mandant>-dev
```

Und mit einem echten Test-Login gegenprüfen — [Verifizieren](../../../03-system/security/07-verifizieren.md). `EXECUTE AS` taugt dafür **nicht**.

> **Keine Security Policies mehr.** Das frühere Hook-Paar `drop_security_policy` / `apply_security_policy` auf physischen Fakt-Tabellen wurde entfernt: Seit nur noch Views berechtigt werden, sind die Tabellen ohnehin unerreichbar — und die Policy kostete 2 logische Reads pro Basiszeile. Die Macros bleiben im Projekt, falls je eine physische Tabelle direkt berechtigt werden muss.

---

◀ [Persistierte Marts](02-persistierte-marts.md) · [Übersicht](00-mart.md)
