---
title: "Changelog"
aliases:
  - "Changelog"
  - "Änderungsprotokoll"
tags:
  - typ/changelog
---
[Dokumentation](README.md)

# Changelog

Alle fachlich oder technisch relevanten Änderungen an Modellen, Macros, Pipeline, Security und Dokumentation — neueste zuerst. **Wird von Entwicklern und den Claude-Agents (`dv-toolkit`, Skill `dv-docs`) bei jeder Änderung fortgeschrieben**, im selben Commit wie die Änderung.

<!-- Format (nicht entfernen, Agents lesen es):
| JJJJ-MM-TT | Version | Bereich | Änderung (was + Wirkung, Objekte in `code`) | Ticket/Commit |
- Neue Zeile direkt unter dem Tabellenkopf einfügen.
- Version: leer bis zum Release, dann vX.Y.Z nachtragen.
- Bereich: staging | raw-vault | business-vault | mart | security | macros | pipeline | doku | betrieb
- Breaking Changes (Full Refresh, entfallene Objekte/Spalten) mit "BREAKING:" beginnen.
-->

| Datum | Version | Bereich | Änderung | Ticket/Commit |
|-------|---------|---------|----------|---------------|
| 2026-10-26 | | pipeline | Lead-Engine Delta-Verarbeitung: Staging liest über `base_lead_engine__*_stelle_delta` (Macro `lead_engine_delta`) nur Läufe mit `run_id` > höchste `run_id` im Sichtungs-Satelliten der Quelle; Sichtungs-Satelliten laden je Quelle zuletzt (`-- depends_on`). Aufwand je dbt-Lauf unabhängig von der Historie (ca. 21 s bei 4 Läufen). Base-Tabellen übernehmen Läufe erst nach 30 Min. Ruhezeit, weil das Laufprotokoll seit Collector 0.3.0 (Dagster) eine andere `run_id` hat als die Dateien | |
| 2026-10-26 | | pipeline | Lead-Engine Performance: Base-Modelle `base_lead_engine__*_stelle` als inkrementelle Tabellen (nur vollständige Läufe mit `run_id` > Maximum), Staging `stg_lead_engine__*` als Tabellen (`automate_dv.sat()` liest die Quelle mehrfach; als View dauerte ein Satellit bis zu 16 Min). Gesamtlauf von über 12 Min auf ca. 3 Min | |
| 2026-10-26 | | raw-vault | Alle Satelliten mit `meta={'apply_source_filter': true}`: ohne Filter wurde die Staging-Historie bei jedem Lauf erneut eingefügt (Duplikate in `sat_stelle__karriere`). `profil_ids` in den Sichtungs-Satelliten auf `NVARCHAR(4000)` verbreitert, 14 exakte Duplikate bereinigt | |
| 2026-10-25 | | raw-vault | Lead-Engine Suchprofile: Collector liefert je Landing-Datei die `profil_id` (Suchprofil-Tabelle). Neue Spalte `profil_ids` in `base_lead_engine__{karriere,theirstack,website}_stelle`, im Hashdiff `hd_stelle_sichtung__*` und als Payload in `sat_stelle_sichtung__*` (append_new_columns, ältere Zeilen NULL = data-bi); `profil_id` in `base_lead_engine__lauf_abfrage`. Mart: `fakt_stelle_sichtung` jetzt Grain Stelle × Lauf × Suchprofil mit `profil_id` (degenerierte Dimension) – `anzahl_sichtungen` nur je Profil summieren. | |
| 2026-10-25 | | business-vault | Lead-Engine: virtuelle View `vault.bv_stelle_neu` (neue Leads = im jüngsten Lauf der Quelle erstmals gesehen, mit Titel, Firma, Ort, URL) | |
| 2026-10-25 | | mart | Lead-Engine-Mart in Schema `mart_lead_engine`: `dim_quelle`, `dim_firma`, `dim_stelle`, `fakt_stelle` (Lebenszyklus je Stelle, `ist_online`), `fakt_stelle_sichtung` (je Stelle und Lauf) plus `_v`-Views; Macro `lead_engine_quelle_name`; ER-Diagramm `design/mart/lead_engine/er-mart-lead-engine.mmd` | |
| 2026-10-25 | | pipeline | Lead-Engine: dlt-Ladestrecke `scripts/lead_engine/load_landing.py` (Storage -> `landing.lead_engine_datei`/`_lauf`), erster Lauf geladen (94 Dateien, 1 Lauf), Staging und Raw Vault gebaut, 59 Tests grün | |
| 2026-10-25 | | staging | Lead-Engine angebunden: Landing-Tabellen `landing.lead_engine_datei`/`_lauf` (dlt-Ladestrecke `scripts/lead_engine/load_landing.py`), Base-Views `base_lead_engine__{karriere,theirstack,website}_stelle` und `base_lead_engine__lauf_abfrage` (neuer Ordner `models/base/`), Staging `stg_lead_engine__*_stelle` samt FK-Staging `__firma` | |
| 2026-10-25 | | raw-vault | Lead-Engine: `hub_stelle`, `hub_firma`, `link_stelle_firma`, `sat_stelle__{karriere,theirstack,website}`, `sat_firma__{karriere,theirstack}`, `sat_stelle_sichtung__{karriere,theirstack,website}` (Sichtungs-Satelliten je Quelle, da `automate_dv.sat()` nur ein `source_model` kennt) | |
| 2026-09-30 | v1.4.3 | mart | Regel „Stern, kein Snowflake“: Dimensionen führen keine Keys anderer Dimensionen — Zugehörigkeit als Attribut (`<x>_code`/`<x>_name`), der `<dim>_key` gehört in die Fakten. In Doku, Skill `dv-marts`, Pflichtkonventionen und DV-Lint (Pflichtbefund) ergänzt | |
| 2026-09-30 | v1.4.2 | pipeline | Python-Abhängigkeiten über `requirements.txt` gepinnt (dbt-core 1.11.2, dbt-sqlserver 1.9.0, dbt-fabric 1.9.3, pyodbc 5.1.0, azure-identity 1.25.3); CI-, Docs- und Deploy-Workflows sowie README/Erste Schritte installieren per `pip install -r requirements.txt`. Grund: ungepinnt zog pip dbt-sqlserver 1.12, dort ist `pyodbc` optional → Verbindungsfehler im pyodbc-Backend | |
| 2026-09-30 | v1.4.1 | doku | Konventionen präzisiert: `dss_create_datetime` Pflicht im Standard- und DC-Satellite, empfohlen in MA/Eff/TL (Vorlagen ergänzt, MA-Vorlage mit Post-Hooks und `__<quelle>`-Naming); `dss_create_datetime` als `CAST(GETDATE() AS DATETIME2)`; Segment 2 von `dss_business_key` projektabhängig (Collision-Code, z. B. Quelle) inkl. Ausnahme zur Reihenfolge-Regel; Hinweis, dass `derived_columns` einander nicht referenzieren können | |
| 2026-09-30 | v1.4.0 | pipeline | Plugin `dv-toolkit` 1.8.0: Pflichtkonventionen + Konventions-Audit beim Sitzungsstart, Lint für Staging/Raw Vault/Mart, plattformfester Hook-Start (`pyrun.sh`), Skills/Agents nach „Konvention vor Bestand“ | |
| 2026-09-30 | | raw-vault | BREAKING: Beispiel-Satellites nach Konvention `sat_<entity>__<quelle>` umbenannt (`sat_kunde` → `sat_kunde__adworks` usw.), Hash-Diff-Spalten im Staging auf `hd_<entity>__adworks`; bestehende Beispiel-Tabellen unter altem Namen bleiben liegen und können gelöscht werden | |
| 2026-09-30 | | doku | Beispiele vereinheitlicht und neutralisiert (Vertrieb/CRM: `hub_kunde`, `hub_bestellung`, `hub_vertrag`; Sensordaten: `hub_sensor`, `sat_sensor_messung_tl__iot`), Hashdiff-Alias einheitlich `hashdiff` | |
| 2026-09-27 | | doku | Dokumentation neu gegliedert: Inhaltsverzeichnisse `00-*.md`, Base je Handbuch, Kapitel Namenskonventionen, `04-objekte-anlegen/` (Staging, Raw Vault, Business Vault, Mart), Transaction Link, SCD1/SCD2, Deployment Workflow, zentraler Changelog, `04-mandant-architektur/` | |
| 2026-09-27 | | macros | Aus dem Referenzprojekt übernommen: `surrogate_key`, `satellite_current_view`, `create_clustered_index`, `create_load_status_table`/`log_load_status`, `log_row_counts`, `measure_rls_overhead`, Security-Macros (`tenant_key`, `rls_filter`, `cls_mask`, `security_policy`, `grant_select_on_views`) und `security/ddl` | |
| 2026-09-26 | | doku | Dokumentation als Obsidian-Vault (Frontmatter, Callouts, Graph, Lesezeichen, Vorlagen, Bases) | |
