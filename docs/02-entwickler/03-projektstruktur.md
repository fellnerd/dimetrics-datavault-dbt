---
title: "Projektstruktur"
tags:
  - entwickler
---
[Dokumentation](../README.md) › [Data Vault 2.1 – Developer Guide](00-entwicklerhandbuch.md)

# Projektstruktur

```
datavault-dbt/
├── dbt_project.yml              # ⚙️ Projektkonfiguration (Schemas, Materialisierung, vars, Hooks)
├── packages.yml                 # 📦 Package-Abhängigkeiten (+ package-lock.yml)
├── profiles.yml                 # 🔐 In ~/.dbt/ bzw. zur Laufzeit in der CI (nicht im Repo!)
├── .gitlab-ci.yml               # 🚢 CI/CD (primär)
├── .github/workflows/           # 🚢 CI/CD (parallel gepflegt)
│
├── macros/                      # 🔧 Wiederverwendbare Macros
│   ├── generate_schema_name.sql
│   ├── hash_override.sql
│   ├── satellite_current_flag.sql
│   ├── satellite_current_view.sql
│   ├── create_hash_index.sql
│   ├── surrogate_key.sql
│   ├── ghost_records.sql
│   ├── create_load_status_table.sql   # + log_load_status (on-run-end)
│   ├── stage_external_sources_selective.sql
│   ├── list_parquet_files.sql / get_parquet_schema.sql / get_parquet_data.sql
│   └── security/                      # tenant_key, rls_filter, cls_mask,
│                                      # security_policy, grant_select_on_views
│
├── seeds/                       # 🌱 Reference Data (CSV) + schema.yml
├── tests/                       # 🧪 Singular Tests (u. a. tests/security/)
├── security/                    # 🔐 DDL, Rechte, OLS-Grants, DEPLOYMENT.md
├── scripts/                     # 🛠️ Setup-/Betriebsskripte (Runner, DB, ADF-Trigger)
├── design/                      # 📐 Modell-Design je Quelle/Domäne
│
├── models/
│   ├── staging/                # 📥 Schema: stg
│   │   ├── sources.yml         #    External Table Definitionen
│   │   ├── _staging__models.yml#    Dokumentation & Tests
│   │   ├── <concept>_<entity>.sql      # Staging Views
│   │   └── psa_<concept>_<entity>.sql  # optionale PSA
│   │
│   ├── raw_vault/              # 🏛️ Raw Vault Layer
│   │   ├── _common/            #    Schema: vault (quellübergreifend)
│   │   │   ├── hubs/
│   │   │   ├── satellites/
│   │   │   ├── links/
│   │   │   └── refs/
│   │   └── <concept>/          #    Schema: vault_<concept> (je Quellsystem/Domäne)
│   │   ├── hubs/
│   │   ├── satellites/
│   │   └── links/
│   │
│   ├── business_vault/         # 📊 Soft Rules — Schema: mart_<domain>
│   │
│   └── mart/                   # 📈 Mart Layer (für BI)
│   ├── _common/            #    Schema: mart (geteilte Dimensionen)
│   └── <domain>/           #    Schema: mart_<domain> (dim_*, fakt_*, *_v)
│
├── docs/                       # 📚 Dokumentation = Obsidian-Vault (Ordner als Vault öffnen), Start: README.md
│   ├── changelog.md        #    Änderungen an Plattform und Doku (von Agents gepflegt)
│   ├── 01-benutzer/        #    Benutzerhandbuch
│   ├── 02-entwickler/      #    Entwicklerhandbuch ← Diese Datei
│   │   └── 04-objekte-anlegen/   staging/ raw-vault/ business-vault/ mart/
│   ├── 03-system/          #    Systemdokumentation: allgemein/, security/
│   ├── 04-mandant-architektur/ #    Projektspezifisch: Projektdoku, raw-vault/, business-vault/, information-mart/
│   ├── lessons-learned/    #    Entscheidungen, Fallstricke mit Messwerten
│   ├── schulung/           #    Schulungsunterlagen
│   ├── uebersichten/       #    Obsidian-Bases über den ganzen Vault
│   └── vorlagen/           #    Notiz-Vorlagen (Kapitel, Inhaltsverzeichnis)
│
├── logs/                        # 📝 dbt-Logs (nicht versioniert)
└── target/                      # 🎯 Kompilierte Artefakte
    └── compiled/                #    Generiertes SQL
```

**Konventionen:**

- `_common` enthält Objekte, die aus mehreren Quellen gespeist werden (Schema `vault`), `<concept>` alles, was an ein Quellsystem oder eine Domäne gebunden ist (Schema `vault_<concept>`).
- Domänen mit eigenem Ladefenster (Massendaten) tragen in `dbt_project.yml` ein Tag und werden nicht vom regulären `dbt run` erfasst.
- Satellites tragen das Quellsuffix `__<quelle>`, damit dieselbe Entität aus mehreren Quellen historisiert werden kann.

---

◀ [Quick Reference](02-quick-reference.md) · [Übersicht](00-entwicklerhandbuch.md) · [Tests](05-tests.md) ▶
