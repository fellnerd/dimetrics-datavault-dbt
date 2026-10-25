---
title: "Dateistruktur"
tags:
  - system
---
[Dokumentation](../../README.md) › [Data Vault 2.1 – Systemdokumentation](../00-systemdokumentation.md)

# Dateistruktur

```
datavault-dbt/
├── dbt_project.yml              # Projektkonfiguration (Schemas, Materialisierung, vars, Hooks)
├── packages.yml / package-lock.yml
├── .gitlab-ci.yml               # CI/CD (primär)
├── .github/workflows/           # CI/CD (parallel gepflegt, siehe Kapitel 10)
├── macros/
│   ├── generate_schema_name.sql     # Schema ohne dbt-Prefix
│   ├── hash_override.sql            # CHAR(64)/NVARCHAR-Overrides für automate_dv
│   ├── ghost_records.sql            # Zero-/Error-Keys
│   ├── satellite_current_flag.sql   # dss_is_current, End-Dating
│   ├── satellite_current_view.sql   # Generator für sat_*_current_v
│   ├── create_hash_index.sql        # Indizes auf Hash Keys
│   ├── surrogate_key.sql            # Deterministischer Surrogate Key für Marts
│   ├── create_load_status_table.sql # Ladeprotokoll + log_load_status (on-run-end)
│   ├── log_row_counts.sql           # Row Counts je Objekt
│   ├── cleanup_old_objects.sql      # Aufräumen abgelöster Objekte
│   ├── stage_external_sources_selective.sql  # create_external_table (einzeln)
│   ├── list_parquet_files.sql / get_parquet_schema.sql / get_parquet_data.sql
│   ├── run_sql.sql / measure_rls_overhead.sql
│   └── security/                    # tenant_key, rls_filter, cls_mask, security_policy,
│                                    # grant_select_on_views
├── models/
│   ├── staging/                 # sources.yml (External Tables) + Staging Views + PSA
│   ├── raw_vault/
│   │   ├── _common/             # Schema vault: hubs/ satellites/ links/ refs/
│   │   └── <concept>/           # Schema vault_<concept>: hubs/ satellites/ links/
│   ├── business_vault/          # Soft Rules (Schema mart_<domain>)
│   └── mart/
│       ├── _common/             # Schema mart
│       └── <domain>/            # Schema mart_<domain>
├── seeds/                       # Reference Data (CSV) + schema.yml
├── tests/                       # Singular Tests, u. a. tests/security/
├── security/                    # DDL, Rechte-Skripte, OLS-Grants, DEPLOYMENT.md
├── scripts/                     # Setup- und Betriebsskripte (Runner, DB, ADF-Trigger)
├── design/                      # Modell-Design je Quelle/Domäne (ER-Diagramme, Mappings)
├── docs/                        # Diese Dokumentation
├── logs/                        # dbt-Logs (nicht versioniert)
└── target/                      # Kompilierte Artefakte (nicht versioniert)
```
