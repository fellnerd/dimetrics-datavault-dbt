# datavault-dbt-boilerplate

A [Copier](https://copier.readthedocs.io/) template for scaffolding new **Data
Vault 2.1** dbt projects on SQL Server / Azure SQL. Ships with generic hash-key
and satellite macros, the standard staging → hub/sat/link layering convention,
a working AdventureWorks reference implementation, and CI workflows for
`dbt build` + docs publishing.

This repository is the template itself — the actual project scaffold lives
under [`template/`](template/). `copier.yml` at the root defines the questions
asked when generating a new project.

## Create a new project from this template

There are two ways to start a new project from this template. **Option A is
recommended** — it generates the rendered project and lets you push it to a
new repo in one go. Option B is for when a repo already exists (e.g. you
clicked GitHub's "Use this template" button) and now needs to be rendered.

### Option A: Generate locally, then push to a new repo

Install Copier once:

```bash
pipx install copier
# or: uv tool install copier
```

Generate a new project:

```bash
copier copy gh:fellnerd/datavault-dbt-boilerplate my-customer-dbt-project
```

Copier will prompt for: project name, dbt profile name, company/author name,
GitHub org, example warehouse server / database name, schema names, hash
algorithm, and whether to include the AdventureWorks demo. Answers are
written to `.copier-answers.yml` in the new project — **do not delete this
file**, it is required for `copier update` later.

Then push it to a new (empty) GitHub repo:

```bash
cd my-customer-dbt-project
git init -b main
git add -A
git commit -m "Initial project from datavault-dbt-boilerplate"
git remote add origin git@github.com:<your-org>/<your-repo>.git
git push -u origin main
```

### Option B: You already created a repo via "Use this template"

GitHub's green **"Use this template"** button only copies the files
as-is — it does **not** run Copier and does not ask any questions. If you
used it, your new repo still contains the raw, unrendered scaffold
(`copier.yml`, the `template/` folder, `.jinja` files, `{% if %}` in some
file names) instead of a working dbt project. To actually render it:

```bash
git clone git@github.com:<your-org>/<your-repo>.git
cd <your-repo>

pipx install copier   # if not already installed
copier copy gh:fellnerd/datavault-dbt-boilerplate . --overwrite
```

Answer the prompts (for `github_org`, use the org/user your new repo lives
under). This overwrites the raw scaffold in place with the rendered project
and writes `.copier-answers.yml`. Then commit and push:

```bash
git add -A
git commit -m "Render project from datavault-dbt-boilerplate"
git push
```

## Pull in later template improvements

From inside an already-generated project:

```bash
copier update
```

Copier re-applies your original answers (from `.copier-answers.yml`), diffs
against the current template version, and merges upstream boilerplate changes
(new macros, CI fixes, doc improvements) into your project — including
conflict markers for anything you've customized. Commit the result like any
other merge.

To change an answer after the fact (e.g. drop the AdventureWorks demo):

```bash
copier update --data include_example=false
```

## Claude Code plugin marketplace

This repo doubles as a **Claude Code plugin marketplace** (catalog at
[`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json)). It ships
two plugins:

- [`dv-toolkit`](plugins/dv-toolkit/) — generic dbt / Data Vault 2.1 skills
  (`dv-patterns`, `dv-staging`, `dv-marts`, `dv-design-sync`, `dv-er-diagram`,
  `dv-performance`, `dv-security`, `dv-docs` incl. concept documentation per mart), five specialized agents (vault-architect, staging-engineer,
  mart-architect, db-monitor, performance-optimizer) that also maintain the Obsidian docs vault and
  `docs/changelog.md`, and two hooks:
  - **SessionStart** (dbt + automate_dv projects only): loads the mandatory conventions
    into the session and lists existing models that violate them, so non-compliant
    code is not copied as a template.
  - **PostToolUse** lint on every edit of `models/**` (staging `dss_*` derived columns,
    hub/satellite `src_extra_columns`, FK-hub trap, hashdiff alias, mart surrogate keys,
    `_id`/`_code`/`_name`, `fakt_` naming, published `_v` views) and `design/**/*.mmd` drift.
    Full project audit: `python plugins/dv-toolkit/hooks/dv_lint.py --audit <project>`.

  Hooks need Python 3 and a POSIX `sh` (on Windows: Git for Windows, which Claude Code
  requires anyway). `hooks/pyrun.sh` picks the first interpreter (`python3`, `python`,
  `py`) that can actually read the plugin files — the Microsoft Store `python3` alias
  cannot, and is skipped.
- [`masterdata-api`](plugins/masterdata-api/) — a single skill for talking to
  any deployed Master Data Services (MDS) instance over its token-authenticated
  REST API (`/api/v1/*`): manage models/entities/attributes, stage records
  with attribute-value filters, and read deployed master data/views with
  field selection and unique-value (`distinct`) lookups for cascading
  dropdown filters. Not tied to Data Vault or this template - works against
  any MDS deployment.

Projects generated from this template are wired up automatically — their
`.claude/settings.json` registers this marketplace via `extraKnownMarketplaces`
and enables `dv-toolkit@datavault-dbt`, so Claude Code offers to install it on
first start. Manual installation in any other project:

```shell
/plugin marketplace add fellnerd/datavault-dbt-boilerplate
/plugin install dv-toolkit@datavault-dbt
/plugin install masterdata-api@datavault-dbt
```

The marketplace and the copier template are versioned together (git tags), so
the conventions the template generates and the conventions the plugin's lint
hook enforces always match. Update installed plugins with

```shell
/plugin marketplace update datavault-dbt
/plugin update dv-toolkit@datavault-dbt
```

(or from a terminal: `claude plugin marketplace update datavault-dbt` and
`claude plugin update dv-toolkit@datavault-dbt`), then start a new session.

## What's included

- `macros/` — 10 generic Data Vault 2.1 macros (hash keys, ghost records,
  satellite current-flag handling, schema naming, parquet/external-table
  helpers).
- `models/raw_vault/_common/{hubs,satellites,links}` — empty framework
  folders for your cross-source Data Vault objects.
- `models/raw_vault/adworks/`, `models/staging/adworks_*.sql` — optional
  AdventureWorks reference implementation (toggle via `include_example`).
- `design/` — Mermaid/Markdown design templates for hubs, links, PITs,
  bridges, and staging mappings.
- `docs/` — developer guide, architecture notes, lessons learned.
- `.github/workflows/` — generic CI (`dbt build` on PR) and docs-publishing
  workflows; `.github/workflows-examples/` has non-executing deploy pipeline
  patterns to adapt per customer.
- `scripts/setup_schemas.sql` — creates the staging/vault/mart schemas in a
  fresh target database so `dbt debug && dbt run` works right after setup.

## Template development

Test changes to the template locally before pushing:

```bash
copier copy . /tmp/smoke-test --defaults
```

## License

[MIT](LICENSE)
