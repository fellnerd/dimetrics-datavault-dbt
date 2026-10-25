# Workflow examples

These are **patterns, not live workflows** — the `.yml.example` extension keeps
GitHub Actions from picking them up automatically. They encode a real,
reusable deploy pattern (environment-gated dev deploy, tag-triggered
production deploy with a target choice) but need customer-specific values
(targets, database names, secrets) filled in before use.

To use one:

1. Copy it into `.github/workflows/` and rename to `.yml`.
2. Replace the `staging`/`production` choice options and
   `<CUSTOMER>_STAGING` / `<CUSTOMER>_PRODUCTION` database placeholders with
   your real target names.
3. Set the referenced secrets (`AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`,
   `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`) in the repository or
   environment settings.
4. Adjust `runs-on` if you use a self-hosted runner.
