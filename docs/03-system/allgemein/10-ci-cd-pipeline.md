---
title: "CI/CD Pipeline"
tags:
  - system
---
[Dokumentation](../../README.md) › [Data Vault 2.1 – Systemdokumentation](../00-systemdokumentation.md)

# CI/CD Pipeline

Das Projekt wird über zwei parallel gepflegte Pipelines deployed:

| Pipeline | Datei | Rolle |
|----------|-------|-------|
| **GitLab CI** | `.gitlab-ci.yml` | Primäre Pipeline in der Mandanten-Umgebung (Merge-Request-Validierung, Deployments dev/test/prod, geplante Läufe) |
| **GitHub Actions** | `.github/workflows/` | Parallel gepflegte Workflows für die Entwicklung im Herstellerrepository |

Beide führen dieselben dbt-Kommandos gegen dieselben Targets aus; unterscheidet sich nur die Trigger-Mechanik. Wird ein Deployment-Schritt geändert, ist er in **beiden** Dateien nachzuziehen.

### 10.1 Stages und Jobs (GitLab CI)

| Stage | Job | Trigger | Ziel |
|-------|-----|---------|------|
| validate | `ci:validate` | Merge Request | `dbt compile` + `dbt test` gegen dev (ohne `tag:nightly` und Staging-Tests) |
| validate | `ci:nightly-tests` | Scheduled Pipeline (`NIGHTLY_TESTS=true`) | langsame Tests (`tag:nightly`, Staging-Views auf External Tables) |
| deploy | `deploy:dev` | Push auf `dev` (nur bei Änderungen an `models/`, `macros/`, `seeds/`, `dbt_project.yml`, `packages.yml`) | External Tables, `dbt run`, `dbt test` gegen dev |
| deploy | `deploy:dev:full-refresh` | manuell | `dbt run --full-refresh` gegen dev |
| deploy | `deploy:test` | Push/Web auf `test`, manuell | Deployment gegen test |
| deploy | `deploy:test:adf-triggered` | Scheduled Pipeline (alle 30 Min.) | prüft `vault.load_status_pending_v` via `scripts/check_load_pending.py` und startet dbt nur bei neuem Quell-Load |
| deploy | `deploy:test:full-refresh` | manuell | Full Refresh gegen test |
| deploy | `deploy:prod` | Tag `v*` automatisch, sonst manuell auf `main` | Deployment gegen Produktion |
| deploy | `deploy:prod:full-refresh` | manuell | Full Refresh gegen Produktion |
| deploy | Domänen-Jobs (`*:<domäne>-load`, `*-fastload`, `*-full-refresh`) | manuell | Laden getaggter Domänen (Massendaten) in definierter Reihenfolge Staging → PSA → Vault → Mart |

Jobs mit langen Laufzeiten haben eigene `timeout`-Werte (bis 3 Stunden); der ADF-getriggerte Job läuft mit `resource_group`, damit sich zwei Läufe nicht überholen.

### 10.2 Ausführungsumgebung

- **GitLab:** Shell-Executor auf einem dedizierten Runner (Tag `<mandant>-dbt`); dbt, Python und der ODBC-Treiber sind auf dem Runner-Host installiert. `before_script` führt `dbt deps` aus.
- **GitHub:** Self-hosted Runner (Labels `self-hosted, linux, dbt, aca`), betrieben als Container-App bzw. VM.
- `profiles.yml` wird im Job aus CI-Variablen erzeugt (`DBT_PROFILES_DIR` = Projektverzeichnis).

### 10.3 Variablen und Umgebungen

| Zweck | GitLab | GitHub |
|-------|--------|--------|
| DB-Zugang | `DBT_..._SQL_USER`, `DBT_..._SQL_PASSWORD` (masked, protected) | Repository-/Environment-Secrets |
| Umgebungen | `environment: <mandant>-dev / -test / -prod` | Environments `<mandant>-dev` / `<mandant>-prod` |
| Freigabe Produktion | Tag oder manueller Job auf `main` | Required Reviewer auf dem Prod-Environment |

### 10.4 Geplante Läufe

| Plan | Branch | Zweck |
|------|--------|-------|
| Nightly Tests | `dev` | langsame Tests ausserhalb der Merge-Request-Validierung |
| ADF-Trigger | `test` | alle 30 Minuten prüfen, ob ein neuer Quell-Load vorliegt |
