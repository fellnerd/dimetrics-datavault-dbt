---
title: "Neues Mart-Objekt absichern"
tags:
  - system/security
---
[Dokumentation](../../README.md) › [Data Vault 2.1 – Systemdokumentation](../00-systemdokumentation.md) › [Security](00-security.md)

# Neues Mart-Objekt absichern

Für Modellentwickler. Die Frage ist immer dieselbe: **Trägt das Objekt den Filter, oder erbt es ihn?**

## Entscheidungsbaum

```
Neues Mart-Objekt
│
├── Ist es eine Dimension, die einen Zugriffsbereich definiert?
│   (Kostenstelle, Konto, Projekt, Organisationseinheit …)
│   └── JA  → TRÄGER: dss_sec_value_key + rls_filter        (A)
│
├── Ist es ein Fakt mit Kennzahlen?
│   └── JA  → ERBT: INNER JOIN auf die Träger-Dimension(en) (B)
│
├── Ist es eine Dimension ohne Zugriffsbezug? (dim_date, dim_buchungsstatus …)
│   └── JA  → kein Filter. Keine Kennzahlen, kein Leak      (C)
│
└── Ist es ein physischer Cache (materialized='table')?
    └── JA  → kein Filter, kein Grant, dafür _v-Wrapper     (D)
```

## A — Träger-Dimension

```sql
-- dim_<name>.sql  (materialized='table', ohne Filter)
SELECT
    …,
    {{ sec_value_key("CONCAT_WS('||', ISNULL(CAST(<gruppe> AS NVARCHAR(255)), '?'),
                                      CAST(<detail> AS NVARCHAR(50)))") }} AS dss_sec_value_key,
    dss_load_date,
    dss_record_source
FROM …
```

```sql
-- dim_<name>_v.sql  (materialized='view', mit Filter)
SELECT <spalten explizit>
FROM {{ ref('dim_<name>') }}
WHERE {{ rls_filter('<kontext>') }}
```

Drei Dinge dabei:

1. **Neuen Kontext** in [02 – sec-Schema](02-sec-schema.md) eintragen und in der Doku ergänzen.
2. **Plug-/Ghost-Zeilen** durchlassen, falls die Dimension welche hat: `WHERE <key> < 0 OR {{ rls_filter(…) }}`.
3. **Materialisieren.** Die Träger-Dimension liegt auf dem kritischen Pfad *jeder* Fakt-Abfrage. Als View liest sie pro Abfrage ihre Quellen neu — bei `dim_kostenstelle` waren das 1.938 statt 325 logische Reads, weil `ref_kostenstelle_v` an einer externen Parquet-Tabelle hängt.

> **Eine CTE hilft dagegen nicht.** Benannte CTEs sind in SQL Server keine Materialisierungsgrenze — der Versuch machte es messbar schlechter (1.938 → 2.654 Reads). Nur echte Materialisierung wirkt.

## B — Fakt, der erbt

```sql
-- fakt_<name>_v.sql
SELECT f.*
FROM {{ ref('fakt_<name>') }} f
INNER JOIN {{ ref('dim_kostenstelle_v') }} d ON d.kostenstelle_key = f.kostenstelle_key
INNER JOIN {{ ref('dim_konto_v') }}        k ON k.konto_key        = f.konto_key
```

**Vorher zwingend prüfen**, dass die Dimensionen vollständig sind:

```sql
SELECT COUNT(*) FROM <fakt> f
WHERE NOT EXISTS (SELECT 1 FROM <dimension> d WHERE d.<key> = f.<key>);
-- Erwartung: 0 — sonst unterschlägt der INNER JOIN Zeilen, auch für Admins
```

Danach den `relationships`-Test auf dem Fremdschlüssel auf `severity: error` setzen:

```yaml
- name: kostenstelle_key
  tests:
    - relationships:
        arguments:
          to: ref('dim_kostenstelle_v')
          field: kostenstelle_key
        config:
          severity: error
```

Wird das bestehende `SELECT` durch den Join mehrdeutig, kapsle es in eine CTE:

```sql
WITH fakt AS ( <bisheriges SELECT> )
SELECT f.* FROM fakt f INNER JOIN {{ ref('dim_…_v') }} d ON …
```

## C — Dimension ohne Zugriffsbezug

Kein Filter. `dim_date`, `dim_buchungsstatus` und ähnliche tragen keine Kennzahlen; wer sie sieht, erfährt nichts Schützenswertes. Ein Filter würde nur Joins kaputtmachen.

## D — Physischer Cache

```sql
{{ config(materialized='table', as_columnstore=false, tags=['dimension']) }}
```

Kein Filter (ein benutzerabhängiger Filter kann nicht in einer Tabelle stehen), kein Grant (der Hook berechtigt nur Views). **Immer** eine `_v`-Wrapper-View dazu, sonst ist das Objekt für Konsumenten unerreichbar.

Namenskonvention: Tabelle ohne `_v`, View mit. Eine Tabelle mit `_v`-Suffix ist ein Fehler.

## Nach der Änderung

```bash
dbt run  -s <deine_models> --target <mandant>-dev
dbt test -s <deine_models> tests/security --target <mandant>-dev
```

Und mit einem echten Test-Login gegenprüfen — [07 – Verifizieren](07-verifizieren.md).

## Checkliste

- [ ] Träger oder Erbe? (Entscheidungsbaum oben)
- [ ] Bei Trägern: Kontext dokumentiert, Plug-Zeilen durchgelassen, materialisiert
- [ ] Bei Erben: Dimension auf Vollständigkeit geprüft (0 Waisen), `severity: error`
- [ ] Physischer Cache hat eine `_v`-Wrapper-View
- [ ] `dbt test -s tests/security` grün
- [ ] Zeilenzahl als Service-User unverändert gegenüber der Quelle

---

◀ [Berechtigung vergeben](05-berechtigung-vergeben.md) · [Übersicht](00-security.md) · [Verifizieren](07-verifizieren.md) ▶
