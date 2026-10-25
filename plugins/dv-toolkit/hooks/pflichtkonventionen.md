# dv-toolkit: Pflichtkonventionen (Data Vault 2.1 / dbt / automate_dv)

Gelten in jedem Projekt dieses Standards. Die Konvention hat Vorrang vor Bestandsmodellen: ein
bestehendes Modell ist nur dann Vorlage, wenn es konform ist (siehe Audit unten). Abweichungen im
Bestand melden, nicht kopieren.

Vor dem Anlegen/Ändern eines Objekts den passenden Skill laden bzw. Agent nutzen:
Staging → `dv-staging` / staging-engineer · Raw Vault → `dv-patterns` / vault-architect ·
Mart → `dv-marts` / mart-architect · Doku und Konzeptseiten → `dv-docs` · Diagramme → `dv-design-sync`.

Staging (automate_dv.stage):
- derived_columns: `dss_record_source`, `dss_load_date`, `dss_create_datetime` (`CAST(GETDATE() AS DATETIME2)`), `dss_business_key`
  = `CONCAT_WS('||','default','default', ISNULL(LTRIM(RTRIM(CAST(<bk> AS NVARCHAR(MAX)))),'-1') …)`
  (Segment 1 Mandant, Segment 2 Collision-Code — projektabhängig, z. B. Quelle; BK-Spalten wie in
  hashed_columns, gleiche Reihenfolge; derived_columns referenzieren einander nicht → Ausdruck wiederholen)
- FK-Hub (Fremdschlüssel eines Stagings) → eigene FK-Staging-View `<staging>__<entity>`

Raw Vault:
- Hub: `src_extra_columns: [dss_business_key, dss_create_datetime]` — genau ein `dss_business_key`
  ohne Suffix — und `src_extra_columns=` an `automate_dv.hub()` übergeben
- Satellite (auch DC): `dss_create_datetime` in `src_extra_columns` (nie im Payload); MA/Eff/TL empfohlen
- `src_hashdiff` mit `alias: "hashdiff"`; Post-Hooks `create_hash_index` + `update_satellite_current_flag`
- Naming: `hub_<e>`, `link_<e1>_<e2>`, `link_<e>_tl`, `sat_<e>__<quelle>`, `sat_<e>_ma__<quelle>`, Hash Diff im Staging `hd_<e>__<quelle>`
- `as_columnstore=false`; insert-only; `--full-refresh` nur nach ausdrücklicher Freigabe

Mart:
- `dim_<name>` / `fakt_<name>` als Tabelle + publizierte View `dim_<name>_v` / `fakt_<name>_v`
- `<dim>_key` BIGINT via `{{ surrogate_key(...) }}` (nie hk_*), Unbekannt-Zeile `<dim>_key = -1`
- Dimension: `<dim>_id`, `<dim>_code`, `<dim>_name` mit ISNULL-Fallbacks bis 'UNKNOWN'
- Stern, kein Snowflake: keine Keys zwischen Dimensionen — Zugehörigkeit als Attribut in der
  Dimension (`sorte_code`/`sorte_name`), der `<dim>_key` gehört in die Fakten
- Fakt: gleicher `surrogate_key()`-Ausdruck wie die Dimension, `datum_key` JJJJMMTT gegen `dim_date`
- `dss_load_date`, `dss_record_source` durchreichen; `tags=['dimension']` / `['fact']`

Nach jeder Änderung: Schema-YAML mit Tests, ER-Diagramm (`design/`), Changelog-Zeile.
Der PostToolUse-Lint (`dv_lint.py`) prüft diese Regeln nach jedem Schreiben — Befunde nicht ignorieren.
