# scripts/

Utility SQL scripts that support setup and operations for this project.

- `setup_schemas.sql` — creates the empty staging/vault/mart schemas in a
  fresh target database, so `dbt debug` and the first `dbt run` work without
  manual setup.
- `sync_design_to_vault.py` — mirrors Mermaid diagrams and design notes from `design/` into the
  Obsidian vault (`docs/04-mandant-architektur/{raw-vault,business-vault,information-mart}/`),
  configured in `design/vault-sync.json`. `--check` exits 1 when copies are stale (CI).

Add customer- or environment-specific setup scripts here as needed; they are
not tracked upstream in the boilerplate template.
