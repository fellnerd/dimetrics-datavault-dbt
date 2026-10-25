---
applyTo: '**'
---
## PROJECT: Virtualized Data Vault 2.1 on Azure SQL / SQL Server

This project implements a virtualized Data Vault 2.1 architecture with dbt Core.

## ARCHITECTURE

### Components
- **Source:** upstream source system(s) -> ADLS Gen2 Parquet (or your own ingestion path)
- **Staging:** Azure SQL External Tables (PolyBase) -> `[stg].[ext_*]`
- **Transformation:** dbt Core
- **Target:** Azure SQL Database (`sqlbi01.database.windows.net`)

### Data flow
```
Source -> Ingestion -> External Table -> dbt View -> dbt Hub/Sat/Link
```

### Schema naming convention

| Layer | Folder | Schema | Usage |
|-------|--------|--------|------------|
| Staging | `staging/` | `stg` | All sources |
| Raw Vault (common) | `raw_vault/_common/` | `vault` | Cross-source objects |
| Raw Vault (source) | `raw_vault/<concept>/` | `vault_<concept>` | Source-system-specific objects |
| Business Vault | `business_vault/` | `vault` | PITs, Bridges |
| Mart (common) | `mart/_common/` | `mart` | Shared dimensions |
| Mart (domain) | `mart/<concept>/` | `mart_<concept>` | Domain-specific views |

**Pattern:** `_common` -> base schema, `<concept>` -> `<base>_<concept>`

## NAMING CONVENTIONS

### Tables/Views
- Hub: `vault_<concept>.hub_<entity>` (e.g. `vault_adworks.hub_kunde`)
- Satellite: `vault_<concept>.sat_<entity>__<source>` (e.g. `vault_adworks.sat_kunde__adworks`)
- Link: `vault_<concept>.link_<entity1>_<entity2>` (e.g. `vault_adworks.link_kunde_adresse`)
- Common Hub: `vault.hub_<entity>` (integrated across sources)
- Staging View: `stg.<concept>_<entity>` (e.g. `stg.adworks_kunde`)
- External Table: `stg.ext_<concept>_<entity>` (e.g. `stg.ext_adworks_kunde`)

### Columns
- Hash Key: `hk_<entity>` (SHA2_256, CHAR(64))
- Hash Diff: `hd_<entity>` (for satellites)
- Business Key: original name or `<entity>_id`
- Metadata: `dss_` prefix (dss_load_date, dss_record_source, dss_run_id)

## DBT COMMANDS

```bash
source .venv/bin/activate

dbt debug          # test connection
dbt deps           # install packages
dbt compile        # generate SQL (no execution)
dbt run            # run all models
dbt run --select hub_kunde            # single model
dbt test           # run tests
```

## IMPORTANT SETTINGS

### Azure SQL Basic Tier limitations
- `as_columnstore: false` - columnstore not available
- Incremental strategy: `append`

### Hash calculation (SQL Server)
```sql
CONVERT(CHAR(64), HASHBYTES('SHA2_256',
    ISNULL(CAST(column AS NVARCHAR(MAX)), '')
), 2)
```

## OPEN ITEMS

- [ ] Common Vault Objects (`raw_vault/_common/`) for integrated hubs
- [ ] Business Vault views (PITs, Bridges)
- [ ] CI/CD pipeline for your deployment target
- [ ] Additional source-system entities
- [ ] Test incremental load behavior
