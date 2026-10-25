---
title: "Verifizieren"
tags:
  - system/security
---
[Dokumentation](../../README.md) › [Data Vault 2.1 – Systemdokumentation](../00-systemdokumentation.md) › [Security](00-security.md)

# Verifizieren

Eine Berechtigung gilt erst als umgesetzt, wenn sie **mit einem echten Login** geprüft wurde.

## `EXECUTE AS` taugt nicht zum Testen

> `sec.fn_check_rls` matcht auf `ORIGINAL_LOGIN()`, und das bleibt unter Impersonation **dein eigener Login** — samt Service-User-Bypass. Der Test bestünde fälschlich, du sähest alle Zeilen und hieltest die Berechtigung für korrekt.

Das ist kein Mangel, sondern Absicht: genau diese Stabilität ist der Grund, weshalb `ORIGINAL_LOGIN()` statt `USER_NAME()` verwendet wird.

## Test-Login einrichten

Ohne Entra-Admin-Rechte reicht ein Contained User:

```sql
CREATE USER [rls_test] WITH PASSWORD = '<passwort>';
```

`ORIGINAL_LOGIN()` liefert dafür `rls_test`. Was damit getestet wird, gilt eins zu eins für Entra-Logins — die Prüffunktion unterscheidet die Auth-Art nicht.

Dann in `dbt_project.yml` unter `ols_view_grants` eintragen und einmal `dbt run`, damit der Hook die View-Grants setzt. **Sonst nichts** — keine weiteren Rollen, keine Schema-Grants.

### dbt-Target für automatisierte Prüfungen

Passwörter gehören weder ins Repo noch in einen Chat. In `~/.dbt/profiles.yml`:

```yaml
    <mandant>-dev-rlstest:
      type: sqlserver
      driver: 'ODBC Driver 18 for SQL Server'
      server: <server>
      database: datavault-dev
      schema: dv
      authentication: sql
      user: rls_test
      password: "{{ env_var('RLS_TEST_PASSWORD') }}"
      encrypt: true
      trust_cert: false
```

```bash
export RLS_TEST_PASSWORD='…'
dbt show -t <mandant>-dev-rlstest --limit 5 --inline "SELECT COUNT(*) FROM mart_finance.fakt_buchungen_v"
```

## Prüfreihenfolge

### 1. Baseline — vor der ersten Berechtigungszeile

```sql
SELECT COUNT(*) FROM mart_finance.fakt_buchungen_v;   -- 0 erwartet
```

Null Zeilen **ohne Fehler** beweist beides auf einmal: OLS greift (die View ist lesbar) und RLS ist scharf (Deny-by-default). Kommt stattdessen ein Fehler, fehlt der Grant.

### 2. OLS — physische Objekte müssen verweigert werden

```sql
SELECT COUNT(*) FROM mart_finance.fakt_buchungen;    -- Fehler erwartet
SELECT COUNT(*) FROM mart_finance.dim_konto;         -- Fehler erwartet
SELECT COUNT(*) FROM stg.<mandant>_sp_budget;              -- Fehler erwartet
SELECT COUNT(*) FROM sec.sec_user_privilege;         -- Fehler erwartet
```

Erwartet: `The SELECT permission was denied on the object`.

### 3. RLS je Achse

Sollwert vorher als Service-User bestimmen, dann als Testuser gegenprüfen:

```sql
-- als Service-User
SELECT COUNT(*) FROM mart_finance.fakt_buchungen WHERE kostenstelle_nr = 2030;
-- als rls_test
SELECT COUNT(*) FROM mart_finance.fakt_buchungen_v;
```

Der schnellste Check, ob ein Recht richtig sitzt, ist die **Dimension**:

```sql
SELECT COUNT(*) FROM mart_finance.dim_kostenstelle_v;   -- genau die erlaubten
SELECT COUNT(*) FROM mart_finance.dim_konto_v;          -- inkl. 14 Plug-Zeilen
```

### 4. Hierarchie-Prefix

Recht auf eine Gruppe statt auf ein Detail setzen (`<mandant>||3 Vertrieb`) und prüfen, dass alle 19 Kostenstellen erscheinen — ohne je eine eigene Zeile.

### 5. Beide Achsen zusammen

Auf beiden Achsen einschränken. Das Ergebnis muss die **Schnittmenge** sein:

```sql
-- Sollwert als Service-User
SELECT COUNT(*) FROM mart_finance.fakt_buchungen f
JOIN mart_finance.dim_konto k ON k.konto_key = f.konto_key
WHERE f.kostenstelle_nr = 2030
  AND k.dss_sec_value_key LIKE N'<mandant>||5 Personalaufwand||%';
```

**Gegenprobe:** das Recht auf einer Achse entfernen → 0 Zeilen. Das beweist, dass wirklich beide Joins filtern und nicht einer wirkungslos ist.

### 6. Plug-Zeilen

```sql
SELECT COUNT(*) FROM mart_finance.dim_konto_v WHERE konto_key < 0;   -- 14 erwartet
```

Muss auch bei stark eingeschränktem Nutzer vollständig sein, sonst brechen die Zwischensummen im Report.

### 7. Vollzugriff unverändert

Als Service-User die Zeilenzahlen gegen die Quelle vergleichen:

```sql
SELECT (SELECT COUNT(*) FROM stg.<mandant>_sp_budget WHERE Konto IS NOT NULL AND Kostenstelle IS NOT NULL) AS quelle,
       (SELECT COUNT(*) FROM mart_finance.fakt_budget_v) AS view_;
-- muss identisch sein
```

Weicht etwas ab, unterschlägt ein `INNER JOIN` Zeilen — die Dimension ist unvollständig.

## Dauertests

```bash
dbt test -s tests/security --target <ziel>
```

| Test | Prüft |
|---|---|
| `assert_dbt_service_user_exemption` | Service-User-Ausnahme vorhanden — fehlt sie, laufen Builds still leer |
| `assert_only_views_granted_in_mart` | Kein Schema-Grant, kein Grant auf einer Tabelle |
| `assert_no_tier1_columns_in_mart` | Keine streng vertraulichen Spalten im Mart |

## Performance messen

```bash
dbt run-operation measure_rls_overhead \
  --args '{relation: mart_finance.fakt_buchungen_v, iterations: 4}' --target <mandant>-dev
```

Misst sitzungsisoliert über `sys.dm_exec_sessions.logical_reads`. `sys.dm_exec_query_stats` ist dafür unbrauchbar: dbt umhüllt Abfragen, und paralleler Power-BI-Traffic landet in denselben Einträgen. Ersten Lauf beim Vergleich ausklammern (kalter Buffer Pool).

---

◀ [Neues Mart-Objekt absichern](06-neues-objekt-absichern.md) · [Übersicht](00-security.md) · [Fallstricke](10-fallstricke.md) ▶
