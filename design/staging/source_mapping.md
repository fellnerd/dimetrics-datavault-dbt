# Source System Mapping

## Übersicht Quellsysteme

```mermaid
flowchart TB
    subgraph Sources["🗄️ Quellsysteme"]
        SRC[(<source_system><br/>PostgreSQL)]
        AW[(AdventureWorks<br/>SQL Server)]
    end
    
    subgraph Pipeline["⚙️ Integration"]
        SYN[Synapse Pipeline]
    end
    
    subgraph Storage["☁️ ADLS Gen2"]
        direction TB
        P1[/<source_system>/*.parquet/]
        P2[/adventureworks/*.parquet/]
    end
    
    SRC --> SYN
    AW --> SYN
    SYN --> P1
    SYN --> P2
```

## Quellsystem: `<source_system>` (PostgreSQL)

| Quelltabelle | Staging View | Hub | Satellite |
|--------------|--------------|-----|-----------|
| `company_client` | `stg_company` | `hub_company` | `sat_company` |
| `countries` | `stg_country` | `hub_country` | `sat_country` |
| `project` | `stg_project` | `hub_project` | `sat_project` |
| `invoice` | `stg_invoice` | `hub_invoice` | `sat_invoice` |

## Quellsystem: AdventureWorks

| Quelltabelle | Staging View | Hub | Satellite |
|--------------|--------------|-----|-----------|
| `Customer` | `stg_aw_customer` | `hub_customer` | `sat_customer` |
