# AI Assistant Instructions - Data Vault dbt Project

## Interaction Style

### Always Ask Before Acting

**Before creating any Data Vault object**, present options to the user and wait for selection:

```
Which type of object do you want to create?

1. Hub
   Core business entity (e.g., hub_customer, hub_product)
2. Satellite
   Attributes with history tracking
3. Link
   Relationship between entities
4. Staging View
   Prepare source data with hash calculations
5. Mart View
   Flattened view for BI/reporting
6. Type something else
```

### Confirm Destructive Actions

**Always ask for confirmation before:**
- `dbt run --full-refresh` (loses history!)
- Deleting a model
- Any ALTER TABLE or DROP statements
- Modifying existing models

### Present Choices Clearly

When multiple options exist, use numbered lists:

```
Which entity should the satellite belong to?

1. company
   Existing: hub_company, sat_company
2. project
   Existing: hub_project, sat_project
3. invoice
   Existing: hub_invoice, sat_invoice
4. Create new entity
```

### Validate Before Executing

After gathering requirements, **always summarize and confirm**:

```
I'll create the following:

models/staging/stg_product.sql
   - Hash Key: hk_product (SHA256 of object_id)
   - Hash Diff: hd_product
   - Payload: name, price, category, description

models/raw_vault/hubs/hub_product.sql
models/raw_vault/satellites/sat_product.sql

Proceed? (y/n)
```

## Data Vault Workflow

### Creating a New Entity (Full Flow)

1. **Ask for entity name** and source table
2. **Show available columns** from the external table
3. **Ask which columns** for Business Key vs Payload
4. **Show preview** of files to be created
5. **Wait for confirmation**
6. **Create files** (staging view, hub, satellite)
7. **Run dbt** and show results

### Adding Attributes to an Existing Satellite

1. **List current attributes** in the satellite
2. **Show available attributes** from the source
3. **Ask which to add**
4. **Explain impact** (new columns will have NULL for existing rows)
5. **Confirm and execute**

### Creating a Mart View

1. **Ask purpose** (current data, historical, aggregated?)
2. **Show available entities** and their relationships
3. **Ask which entities to join**
4. **Ask which columns to include**
5. **Preview the SQL**
6. **Confirm and create**

## Tool Usage Rules

### DO NOT:
- Use `cat >` or `echo >` to create SQL files where a proper editor tool is available
- Modify the database directly (only via dbt)
- Run `--full-refresh` without explicit user confirmation

## Schema Information

```
Schemas:
- <staging_schema>.*          External Tables + Staging Views
- <schema_prefix>.*           Hubs, Satellites, Links, PITs
- <mart_schema>_<domain>.*    Business context views (per-domain marts)

Naming:
- Hub:       hub_<entity>
- Satellite: sat_<entity>
- Link:      link_<entity1>_<entity2>
- Staging:   stg_<entity>
- Mart:      v_<descriptive_name>
```

## Common Workflows

### "Create a new entity"
-> Ask: What's the entity name? What's the source table?
-> Show: External table columns
-> Ask: Which columns for business key? Which for payload?
-> Confirm: Preview files
-> Execute: staging view -> hub -> satellite -> dbt run

### "Add attribute to satellite"
-> Show: Current attributes + available from source
-> Ask: Which to add?
-> Warn: Existing rows will have NULL
-> Confirm: Edit model
-> Execute: edit model -> dbt run (with on_schema_change: append_new_columns)

### "Run dbt"
-> Ask: Which models? (if not specified)
-> Execute: dbt run
-> Show: Formatted results with model status table
