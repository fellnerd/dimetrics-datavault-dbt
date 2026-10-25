---
name: dv-staging
description: Erstellt Data-Vault-Staging-Views auf SQL Server/Azure SQL — von der External Table über sources.yml bis zur fertigen Hash-berechnenden View (manuelles HASHBYTES-Pattern oder automate_dv.stage()), inkl. optionaler PSA. Immer verwenden bei "Staging erstellen", "Quelle anbinden", "External Table einbinden", "stage() View", "PSA", neuen Parquet-Dateien oder wenn eine Quelltabelle für Hub/Satellite/Link vorbereitet werden muss.
---

# DV Staging (Hash-Berechnung für den Raw Vault)

Staging-Views sind die einzige Stelle, an der Hash Keys und Hash Diffs berechnet werden — Fehler hier (falscher Typ-Cast, vergessene Spalte im Hashdiff, inkonsistenter Separator) pflanzen sich in den gesamten Vault fort und sind nachträglich teuer zu korrigieren.

## Zuerst: Projektmuster identifizieren

Es gibt zwei etablierte Staging-Patterns — **beim Hash-Weg gewinnt das bestehende Projektmuster** (vorhandene Views in `models/staging/` ansehen!). Das gilt nur für die Wahl des Hash-Wegs: die Pflichtspalten unten gelten immer, auch wenn Bestands-Views sie nicht haben (dann Abweichung dem User melden, nicht kopieren).

| Pattern | Erkennungszeichen | Hash-Separator |
|---------|-------------------|----------------|
| **A: automate_dv.stage()** (Standard, Boilerplate ≥ v1.2) | `yaml_metadata`-Block mit `derived_columns`/`hashed_columns` | `concat_string`-Var (`'||'`), Overrides in `hash_override.sql` |
| **B: Manuelles Hashing** (Legacy/Altbestand) | `CONVERT(CHAR(64), HASHBYTES('SHA2_256', …), 2)` direkt im SQL | typ. `'^^'` (im Projekt prüfen) |

⚠️ Die beiden Wege erzeugen für dieselben Spalten **unterschiedliche Hashes**. Innerhalb einer Entity (und bei Multi-Source-Hubs über alle Quellen!) strikt einen Weg verwenden. Vollständige Templates für beide: [references/stage-template.md](references/stage-template.md)

## Workflow

### 1. Quellschema ermitteln

```bash
# Parquet-Schema aus der Landing Zone (Macro im Projekt):
dbt run-operation get_parquet_schema --args '{"folder_path": "<ordner>", "file_name": "<datei>.parquet"}'
# Oder vorhandene External Table auf der DB prüfen:
dbt run-operation run_sql --args '{"sql": "SELECT c.name, t.name AS type_name, c.precision, c.scale FROM sys.columns c JOIN sys.types t ON c.user_type_id = t.user_type_id WHERE c.object_id = OBJECT_ID('"'"'[stg].[ext_<tabelle>]'"'"') ORDER BY c.column_id"}'
```

### 2. Typen prüfen (bekannte Fallen)

- `DECIMAL(38,10)` aus Schema-Inferenz → real meist `DECIMAL(38,18)` (Parquet-Numeric-Scale)
- Binärdaten, die als `NVARCHAR(4000)` erkannt wurden → `VARBINARY(8000)`; **Binärspalten nie in den Hashdiff!**
- Business Keys typstabil normalisieren: `CAST(CAST(col AS BIGINT) AS NVARCHAR(MAX))` — sonst matchen Multi-Source-Hashes nicht

### 3. sources.yml ergänzen

External Table unter dem `staging`-Source eintragen (Muster vorhandener Einträge übernehmen; `external.location`, `file_format`, `data_source` für `dbt run-operation stage_external_sources` bzw. einzeln via `create_external_table`).

### 4. Optional: PSA dazwischenschalten

Bei großen Datenmengen/häufigen Runs die External Table in eine **Persistent Staging Area** cachen (`psa_<quelle>_<entity>`, incremental `merge`/`append`, HWM auf `dss_load_date`) und die Staging View auf `ref('psa_…')` statt `source(…)` stellen. Details: [references/stage-template.md](references/stage-template.md) unten.

### 5. Staging View schreiben

Pflicht in beiden Patterns:

- Metadaten: `dss_record_source`, `dss_load_date` (`COALESCE(TRY_CAST(… AS DATETIME2), GETDATE())`), `dss_create_datetime` (`CAST(GETDATE() AS DATETIME2)`) — Letzteres brauchen Hubs und Satellites in `src_extra_columns`
- `dss_business_key` für die **Haupt-Entität** des Stagings: `CONCAT_WS('||', 'default', 'default', ISNULL(LTRIM(RTRIM(CAST(<BK> AS NVARCHAR(MAX)))), '-1') …)` — dieselben BK-Spalten in derselben Reihenfolge wie in `hashed_columns`; Segment 1 = Mandant, Segment 2 = Collision-Code (bei quellübergreifenden Hubs mit Kollisionsgefahr das Quellsystem — ist es Teil des Hash-Keys, steht es nur in Segment 2). `derived_columns` können einander nicht referenzieren: einen abgeleiteten BK-Ausdruck in `dss_business_key` wiederholen und beide gemeinsam pflegen
- **FK-Staging-View** `<staging>__<entity>` für jeden weiteren Hub, den dieses Staging über einen Fremdschlüssel speist — bildet `dss_business_key` für *dessen* Entität (Vorlage: `dv-patterns` → `references/templates.md`, Abschnitt Hub). Nie eine zweite Spalte `dss_business_key_<x>` im Haupt-Staging
- Hash Keys `hk_*` für jedes Zielobjekt (Hub, Link — Link-Hash enthält alle beteiligten BKs, bei DC-Pattern auch die DCKs)
- Hash Diffs `hd_*` je Satellite: exakt die Payload-Spalten, nicht mehr, nicht weniger; bei Splits mehrere `hd_*`
- Header-Kommentar: Quelle, BK (+Normalisierung), Hash-Spalten mit Zielobjekten

### 6. Dokumentieren & validieren

1. Eintrag in `_staging__models.yml`: Beschreibung, Business Key, Tests (`hk_*` not_null/unique, BK not_null)
2. `dbt parse` → `dbt run --select <staging_model>` → Stichprobe via `run_sql` (Zeilen zählen, Hash-Spalten nicht NULL)

## SQL-Server-Regeln

- **Reserved Keywords escapen** (`[PLAN]`, `[LEVEL]`, `[KEY]`, `[STATUS]`, `[TYPE]`, `[ORDER]`, `[GROUP]`, `[INDEX]`, …) — bei stage() über die `_escape`-derived-column, bei manuellem SQL direkt mit `[ ]`
- Hash-Format: `CONVERT(CHAR(64), HASHBYTES('SHA2_256', …), 2)` — hex-encoded, NVARCHAR-Casts (Unicode-safe)
- `TRY_CAST` statt `CAST` für fehlertolerante Konvertierung
- Reference-Table-Quellen: schlanke View ohne Hashing reicht
- **Ad-hoc-Abfragen testen:** `dbt run-operation run_sql --args '{"sql": "SELECT TOP 10 * FROM stg.ext_<tabelle>"}' --target dev` (Macro `run_sql.sql`, führt beliebiges SQL aus). Alternative `dbt show --inline "..." --limit N` **nie mit `TOP` kombinieren** — beide erzeugen intern `OFFSET`, das kollidiert auf SQL Server. Vor der ersten Abfrage den exakten Tabellennamen aus `sources.yml` nehmen, nicht raten (Source-Block heißt meist `staging`, Tabellen tragen den vollen `ext_*`-Präfix).

## Entscheidungshilfe: Welche Hashes braucht die View?

| Ziel-Objekt | Hash-Spalten |
|-------------|--------------|
| Hub | `hk_<entity>` aus BK |
| Satellite | zusätzlich `hd_<entity>__<source>` (Payload-Spalten) |
| Link | `hk_link_…` aus allen beteiligten BKs + je Hub ein `hk_<entity>` |
| DC Satellite | Link-Hash **inkl. DCKs** + `hd_<entity>_dc__<source>` (Payload inkl. DCKs) |
| MA Satellite | `hd_<entity>_ma__<source>` (Payload inkl. CDK) |
| Multi-Satellite-Split | mehrere `hd_*` (z. B. `hd_person_stamm`, `hd_person_kontakt`) |
| Reference Table | keine |
