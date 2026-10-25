# Memory & Project Context

> Working memory for the `datavault` project. See `docs/` for details.
> Respond in the language the user writes in.

## Me

Daniel Fellner, developer/owner of the `datavault` project, part of **Dimetrics**.

## Project

**datavault** — Virtualized **Data Vault 2.1** architecture on
Azure SQL / SQL Server with dbt Core.

**Data flow:** Source system -> External Table (`stg.ext_*`) -> Staging View (`stg.stg_*`) -> Hub/Sat/Link (`vault.*`)

## People

| Who | Role |
|-----|------|
| **Daniel Fellner** | Developer/owner |
| **Dimetrics** | Maintainer of the project |

## Terms (Glossary)

| Term | Meaning |
|------|---------|
| **DV 2.1** | Data Vault 2.1 (methodology) |
| **Hub / Sat / Link** | Business Key / Attributes+History / Relationship |
| **PIT** | Point-in-Time table (history snapshots) |
| **hk / hd** | Hash Key / Hash Diff (change detection) |
| **dss_*** | DV metadata: dss_load_date, dss_record_source, dss_is_current, dss_end_date |
| **BK** | Business Key |
| **PSA** | Persistent Staging Area (optional cache layer) |

## Environments

| Target | Database | Usage |
|--------|----------|-------|
| `dev` | datavault-dev | Development |
| `test` | datavault-test | Testing |
| `prod` | datavault | Production |

## Conventions

- **Naming:** `hub_<entity>`, `sat_<entity>__<quelle>`, `link_<e1>_<e2>`, staging `<concept>_<entity>`, marts `dim_*`/`fakt_*` + published `*_v` views — full list: `docs/01-benutzer/04-namenskonventionen.md`
- **Schemas:** `stg.*` (Staging), `vault.*` / `vault_<source>` (Raw Vault), `mart_*` (Business Views)
- **Hash:** SHA -> `CHAR(64)` via `HASHBYTES()`; composite separator `'||'` (automate_dv `concat_string`)
- **Raw Vault physical, Business Vault virtual** (views)
- **Azure SQL Basic Tier:** no columnstore (`+as_columnstore: false`), incremental `append`

## Mandatory conventions (convention beats existing code)

Existing models are a template **only if they comply**. Non-compliant existing models are reported, never copied. Full rules: `docs/03-system/allgemein/03-datenmodell.md`, `docs/02-entwickler/04-objekte-anlegen/`.

- **Staging** (`automate_dv.stage()`): `derived_columns` `dss_record_source`, `dss_load_date`, `dss_create_datetime`, `dss_business_key` = `CONCAT_WS('||', 'default', 'default', ISNULL(LTRIM(RTRIM(CAST(<bk> AS NVARCHAR(MAX)))), '-1') …)` (same BK columns/order as `hashed_columns`). Every FK hub fed by a staging gets its own FK staging view `<staging>__<entity>`.
- **Hub:** `src_extra_columns: [dss_business_key, dss_create_datetime]` — exactly one `dss_business_key`, no suffix — and pass `src_extra_columns=` to `automate_dv.hub()`.
- **Satellite** (incl. dependent child): `dss_create_datetime` in `src_extra_columns` (never in the payload), `src_hashdiff` with `alias: "hashdiff"`, post-hooks `create_hash_index` + `update_satellite_current_flag`.
- **Mart:** `dim_<name>` / `fakt_<name>` tables + published `*_v` views; `<dim>_key` BIGINT via `{{ surrogate_key(...) }}` (never `hk_*`), unknown row `-1`, `<dim>_id` / `_code` / `_name` with ISNULL fallbacks to `'UNKNOWN'`, `datum_key` YYYYMMDD, `dss_load_date` / `dss_record_source`.

## Working rules

- **Load the matching `dv-toolkit` skill or agent before creating/changing an object:** staging → `dv-staging` / staging-engineer, raw vault → `dv-patterns` / vault-architect, mart → `dv-marts` / mart-architect.
- **DV lint findings** (PostToolUse hook) are fixed, not ignored. If the hook itself errors (e.g. no usable Python), tell the user — then nothing is being checked.
- **Always ask** before creating DV objects (offer numbered options).
- **Confirm destructive actions:** `dbt run --full-refresh` (loses history!), deleting models, ALTER/DROP.
- **Never** `--full-refresh` on historized satellites.
- **DB tools read-only** — writes only via dbt commands.
- Details: [docs/CLAUDE.md](docs/CLAUDE.md), [docs/02-entwickler/](docs/02-entwickler/00-entwicklerhandbuch.md)

## Dokumentation

- Obsidian-Vault: `docs/` (Start `docs/README.md`), Struktur und Regeln: Skill `dv-docs` (Plugin `dv-toolkit`)
- Bei jeder Änderung an models/, macros/, seeds/, security/ oder der Pipeline: Zeile in `docs/changelog.md` (neueste oben)
- Projektspezifisches nur in `docs/04-mandant-architektur/`; Handbücher 01–03 bleiben mandantenneutral
- Design first (`design/`, Skill `dv-design-sync`), Diagramme per `python3 scripts/sync_design_to_vault.py` in den Vault spiegeln

## Infrastructure

| Resource | Value |
|----------|-------|
| SQL Server | sqlbi01.database.windows.net |
| GitHub | `fellnerd/datavault` |

## Preferences

- Concise and direct; avoid unnecessary explanations.
