---
title: "Namenskonventionen"
tags:
  - benutzer
  - typ/nachschlagen
---
[Dokumentation](../README.md) › [Data Vault 2.1 – Benutzer-Dokumentation](00-benutzerhandbuch.md)

# Namenskonventionen

Verbindliche Namen für alle Objekte der Plattform. Grundregeln: **Kleinschreibung**, Wörter mit `_` getrennt (Datenbank, dbt) bzw. `-` (Dateien der Doku, Branches), fachliche Begriffe auf Deutsch, DV-Begriffe (Hub, Satellite, Link, Mart) unübersetzt. Platzhalter: `<concept>` = Quellsystem/Domäne (z. B. `crm`), `<entity>` = fachliches Objekt (z. B. `kunde`), `<quelle>` = Quellsystem-Kürzel im Satellite-Suffix, `<domain>` = Mart-Domäne.

## Schemas

| Schema | Inhalt | Materialisierung |
|--------|--------|------------------|
| `stg` | External Tables, Staging Views, PSA | External / View / Incremental |
| `vault` | Raw Vault quellübergreifend (`models/raw_vault/_common/`), Reference Views, `load_status` | Incremental / View |
| `vault_<concept>` | Raw Vault einer Domäne mit eigenem Ladefenster (`models/raw_vault/<concept>/`) | Incremental |
| `mart` | Geteilte Dimensionen (`dim_date` …) aus `models/mart/_common/` | Table + View |
| `mart_<domain>` | Dimensionen, Fakten und Business-Vault-Views einer Domäne | Table + View |
| `sec` | Security: Rechtetabellen, Prüffunktionen (per DDL, nicht dbt) | — |

`generate_schema_name` setzt das Schema **ohne** dbt-Präfix: `+schema: vault` ergibt `vault`, nicht `dv_vault`. Datenbanken je Umgebung: `<datenbank>-dev`, `<datenbank>-test`, `<datenbank>` (Produktion).

## Datenbankobjekte

| Schicht | Objekt | Muster | Beispiel |
|---------|--------|--------|----------|
| Staging | External Table | `ext_<concept>_<entity>` | `ext_crm_kunde` |
| | Staging View | `<concept>_<entity>` | `crm_kunde` |
| | Vorbereitungs-View (Deduplizierung, Filter) | `<concept>_<entity>_dedup` | `crm_kunde_dedup` |
| | FK-Staging-View (Business Key eines FK-Hubs) | `<staging_view>__<entity>` | `crm_auftrag__kunde` |
| | Persistent Staging Area | `psa_<concept>_<entity>` | `psa_crm_kunde` |
| Raw Vault | Hub | `hub_<entity>` (ohne Quelle) | `hub_kunde` |
| | Satellite | `sat_<entity>__<quelle>` | `sat_kunde__crm` |
| | Multi-Active Satellite | `sat_<entity>_<gruppe>_ma__<quelle>` | `sat_vertrag_optionen_ma__crm` |
| | Effectivity Satellite | `sat_<entity>_eff__<quelle>` | `sat_vertrag_eff__crm` |
| | Dependent-Child Satellite | `sat_<entity>_<child>__<quelle>` | `sat_kontakt_telefon__crm` |
| | Transaction Satellite | `sat_<ereignis>_tl__<quelle>` | `sat_sensor_messung_tl__iot` |
| | Link | `link_<entity1>_<entity2>` (ohne Quelle) | `link_auftrag_kunde` |
| | Transaction Link | `link_<ereignis>_tl` | `link_zahlung_tl` |
| | Reference Table | `ref_<thema>` | `ref_status` |
| Business Vault | Current View | `sat_<…>_current_v` | `sat_kunde__crm_current_v` |
| | PIT / Bridge | `pit_<entity>` / `bridge_<thema>` | `pit_kunde` |
| | Business-Regel als View | `<thema>_v` | `konto_pl_zuordnung_v` |
| Mart | Dimension (Tabelle) | `dim_<entity>` | `dim_kunde` |
| | Faktentabelle | `fakt_<inhalt>` | `fakt_umsatz` |
| | Publizierte View (BI-Zugriff, Security) | `<objekt>_v` | `dim_kunde_v`, `fakt_umsatz_v` |
| | Datumsdimension | `dim_date` | |
| Seeds | CSV-Referenzdaten | `seed_<thema>` | `seed_konto_pl_zuordnung` |

**BI-Tools lesen ausschließlich `_v`-Views** — nur sie sind berechtigt und tragen die Security. `dim_*`/`fakt_*`-Tabellen sind Implementierungsdetail.

> [!NOTE]
> Ältere Objekte können abweichen (`v_<name>`-Präfix, `dss_source_filename`, Satellites ohne Quell-Suffix). Nicht nachträglich umbenennen — Vault-Tabellen umzubenennen heißt Neuaufbau —, aber für neue Objekte nur die Muster oben verwenden.

## Spalten

| Spalte | Muster | Regel |
|--------|--------|-------|
| Hash Key | `hk_<entity>` | in Hub, Satellite und Link identisch benannt |
| Link-Hash | `hk_link_<e1>_<e2>` | Name des Links ohne `link_`-Präfix |
| Hash Diff | `hd_<entity>__<quelle>` (Staging), `hashdiff` (Satellite) | ein Hashdiff je Satellite; ältere Objekte `hd_<entity>` ohne Quell-Suffix |
| Metadaten | `dss_<name>` | nur die in [Wichtige Spalten](03-wichtige-spalten-verstehen.md) definierten |
| Business Keys, Payload | Name wie in der Quelle | Quellspalten nicht umbenennen (Nachvollziehbarkeit) |
| Mart-Schlüssel | `<dim>_key`, `<dim>_id`, `<dim>_code`, `<dim>_name` | Pflichtspalten jeder Dimension |
| Measures | fachlich, `snake_case`, Einheit im Namen wenn nötig | `betrag_eur`, `menge_stueck` |
| Flags | `ist_<zustand>` bzw. `dss_is_<zustand>` | Werte `Y`/`N` |

## Dateien im Repository

| Was | Muster | Ort |
|-----|--------|-----|
| Modell | `<objektname>.sql` — Dateiname = Objektname | `models/<schicht>/…` |
| Quellen (External Tables) | `sources.yml` | `models/staging/` |
| Modell-Doku und Tests | `_<ordner>__models.yml` (`_staging__models.yml`, `_common__models.yml`, `_<domain>__models.yml`, `_business_vault__models.yml`) | im Modellordner |
| Singular Test | `assert_<prüfung>.sql` | `tests/`, Security-Tests in `tests/security/` |
| Macro | `<verb>_<objekt>.sql` (`create_hash_index`, `log_row_counts`) | `macros/`, Security in `macros/security/` |
| Seed | `seed_<thema>.csv` + Eintrag in `seeds/schema.yml` | `seeds/` |
| Design | `er-diagram.mmd` je Quelle, `er-mart-<domain>.mmd` je Mart | `design/raw-vault/<concept>/`, `design/mart/` |
| Doku | `NN-kebab-case.md`, Index `00-<ordner>.md` | `docs/` (siehe Startseite) |

## Tags

| Tag | Wirkung |
|-----|---------|
| `dimension`, `fact` | Kennzeichnung im Mart (Selektion, Doku) |
| `<domain>` (z. B. `iot`) | Massendaten-Domäne (z. B. Logs, Events, Sensordaten): läuft **nicht** im Standardlauf, sondern über eigene Jobs (`--select tag:<domain>`) |
| `nightly` | Langlaufende Tests, nur im nächtlichen Testlauf |

## Umgebungen, Git, Security

| Was | Muster | Beispiel |
|-----|--------|----------|
| dbt-Target | `<mandant>-dev`, `<mandant>-test`, `<mandant>` (Produktion) | `crm-dev` |
| Branches | `main` (Produktion), `test` (Abnahme), `dev` (Integration), `feat/<thema>`, `fix/<thema>` | `feat/crm-vertraege` |
| Release-Tag | `vMAJOR.MINOR.PATCH` | `v1.4.0` |
| Commit | Conventional Commits: `<typ>(<bereich>): <was>` mit `feat`, `fix`, `docs`, `refactor`, `chore`, `test` | `feat(crm): hub_kunde und sat_kunde__crm` |
| Entra-Gruppe (Lesen) | `<gruppen-prefix>-<bereich>-ro`, Vollzugriff `<gruppen-prefix>-<bereich>-full-ro` | |
| Security-Kontext | `<bereich>_<achse>` | `finance_kst` |

---

◀ [Wichtige Spalten verstehen](03-wichtige-spalten-verstehen.md) · [Übersicht](00-benutzerhandbuch.md) · [Erste Schritte](05-erste-schritte.md) ▶
