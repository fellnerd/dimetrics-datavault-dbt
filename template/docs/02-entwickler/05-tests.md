---
title: "Tests"
tags:
  - entwickler
---
[Dokumentation](../README.md) › [Data Vault 2.1 – Developer Guide](00-entwicklerhandbuch.md)

# Tests

Tests stehen als **Generic Tests** in den `_…__models.yml` (Schlüsselwort `data_tests`) oder als **Singular Tests** (`tests/assert_<prüfung>.sql`, liefert die fehlerhaften Zeilen — 0 Zeilen = bestanden).

## Pflichttests je Objekttyp

| Objekt | Spalte | Tests |
|--------|--------|-------|
| Staging View | `hk_<entity>` | `not_null` (Tag `nightly`, liest Parquet) |
| Hub | `hk_<entity>` | `unique`, `not_null` |
| | Business Key, `dss_business_key` | `not_null` |
| Satellite | `hk_<entity>` | `not_null`, `relationships` → Hub |
| | `dss_is_current` | `accepted_values: ['Y','N']` |
| | `hashdiff`, `dss_load_date` | `not_null` |
| Link | `hk_link_<…>` | `unique`, `not_null` |
| | jeder `hk_<hub>` | `not_null`, `relationships` → Hub |
| Effectivity Satellite | `dss_is_active` | `accepted_values: ['Y','N']` |
| Reference / Seed | Code | `unique`, `not_null` |
| Dimension | `<dim>_key` | `unique`, `not_null` |
| | `<dim>_code`, `<dim>_name` | `not_null` |
| Fakt | jeder `<dim>_key` | `not_null`, `relationships` → Dimension |

```yaml
models:
  - name: link_<e1>_<e2>
    columns:
      - name: hk_link_<e1>_<e2>
        data_tests: [unique, not_null]
      - name: hk_<e1>
        data_tests:
          - not_null
          - relationships: {to: ref('hub_<e1>'), field: hk_<e1>}
```

## Singular Tests

Für Regeln, die ein Generic Test nicht abdeckt — z. B. Grain eines Satellites, fachliche Abstimmungen, Security:

```sql
-- tests/assert_sat_<entity>__<quelle>_eine_aktuelle_version.sql
SELECT hk_<entity>
FROM {{ ref('sat_<entity>__<quelle>') }}
GROUP BY hk_<entity>
HAVING SUM(CASE WHEN dss_is_current = 'Y' THEN 1 ELSE 0 END) <> 1
```

Bestehende Security-Tests (`tests/security/`) laufen immer mit:

| Test | Prüft |
|------|-------|
| `assert_only_views_granted_in_mart` | Endanwender haben Rechte nur auf `_v`-Views, nie auf Tabellen |
| `assert_no_tier1_columns_in_mart` | streng vertrauliche Spalten tauchen in keinem `mart*`-Objekt auf |
| `assert_dbt_service_user_exemption` | der dbt-Dienstbenutzer ist von RLS ausgenommen (sonst lädt er leere Marts) |

Weitere fachliche Prüfabfragen: [Daten prüfen](../01-benutzer/08-daten-pruefen.md).

## Schweregrad und langsame Tests

```yaml
      - name: hk_<entity>
        data_tests:
          - unique:
              config:
                severity: warn          # nur Warnung, bricht die Pipeline nicht
                tags: ['nightly']       # läuft nur im nächtlichen Testlauf
```

- `tag:nightly` für Tests mit vollen Scans großer Tabellen und für alle Tests auf Staging Views (sie lesen live Parquet-Dateien). Die Merge-Request-Validierung schließt sie aus.
- `severity: warn` nur für bekannte, dokumentierte Datenqualitätsprobleme der Quelle.

## Ausführen

```bash
dbt test --select <modell>                            # ein Modell
dbt test --select +<modell>                           # mit allem davor
dbt build --select <modell>                           # bauen + testen
dbt test --exclude tag:nightly path:models/staging    # wie die MR-Validierung
dbt test --select tag:nightly path:models/staging     # wie der Nightly-Lauf
dbt test --select test_type:singular                  # nur Singular Tests
```

Fehlgeschlagene Zeilen ansehen: `dbt test --select <test> --store-failures` schreibt sie in ein Audit-Schema; alternativ das kompilierte Test-SQL aus `target/compiled/…/tests/` ausführen.

---

◀ [Projektstruktur](03-projektstruktur.md) · [Übersicht](00-entwicklerhandbuch.md) · [Deployment Workflow](06-deployment-workflow.md) ▶
