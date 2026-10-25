# DV 2.1 Objekt-Leitlinien (kuratiert aus dem Developer Guide)

Wann, warum und wie die einzelnen Data-Vault-Objekte eingesetzt werden. Kuratierte, geprüfte Fassung — bei Widerspruch zu einer projektlokalen `docs/entwickler/` gilt: erst prüfen, welche Generation aktueller ist (ältere Guides enthalten teils handgeschriebene Incremental-Templates aus der Zeit vor automate_dv).

## Grundprinzip

| Aspekt | Frage | Objekt |
|--------|-------|--------|
| **Identität** | Was existiert? | Hub |
| **Beziehung** | Wie hängt etwas zusammen? | Link |
| **Historie** | Wie hat es sich verändert? | Satellite |

Ziele: Auditierbarkeit, Historisierung, Skalierbarkeit, Entkopplung von Quelle & Reporting.

> **Merksatz:** Hubs identifizieren. Satellites historisieren. Links verbinden. Dependent Children ergänzen. Multi-Active gilt parallel. PIT beschleunigt. Information Marts erklären.

## Häufige Fehlannahmen

| Falsch | Richtig |
|--------|---------|
| Hubs sind historisiert | Hubs haben nur Ladezeitpunkt, keine fachliche Historie |
| Alles braucht einen Hub | Lookup-Werte → Reference Table |
| PIT ist Pflicht | PIT nur bei Performance-Bedarf |
| Referenzdaten in Satellites | Reference Tables sind eigenständig |
| Mart ist eigenes DWH | Mart ist nur (View-)Schicht auf dem Vault, keine eigene Historisierung |
| Full Refresh ist harmlos | Auf historisierten Sats/Hubs/Links vernichtet er die Historie; neue Spalten kommen über `on_schema_change: append_new_columns` **ohne** Full Refresh an |

## Objekttypen im Detail

### Satellite-Varianten

| Typ | Wann? | Merkmale |
|-----|-------|----------|
| **Standard** | Normale Attribute mit Historie | 1 Thema = 1 Satellite, nach Änderungsfrequenz schneiden |
| **Dependent Child (DC)** | Entity ohne eigenen BK (Positionen, Ansprechpartner) | Hängt am **Link**; Link-Hash enthält die DCKs |
| **Multi-Active (MA)** | Mehrere gleichzeitig gültige Werte (Rollen, Telefonnummern) | `src_cdk` unterscheidet; braucht Hub-BK (Unterschied zu DC!) |
| **Extension** | Zusatzattribute für eine Teilmenge | z. B. `sat_company_client_ext` nur für Clients |
| **Effectivity** | Gültigkeitszeiträume von Beziehungen | Am Link; `dss_start_date`/`dss_end_date`/`dss_is_active`; post_hook `update_effectivity_end_dates()` |

### DC vs. MA — der entscheidende Unterschied

- **DC Sat:** Entity hat **keinen eigenen** stabilen BK → Identifikation über Parent-FK + DCK; der Link-Hash enthält die DCKs (`Hash(FK, DCK1, DCK2)`); Link hat bei „Pure DC" nur 1 Hub-FK. Staging braucht einen eigenen `hd_*_dc` (inkl. DCK-Spalten).
- **MA Sat:** Entity **hat** einen BK (Hub existiert), aber mehrere parallel gültige Attributsätze → `src_cdk` in der automate_dv-Config, eigener `hd_*_ma` (inkl. CDK-Spalten). Naming: `sat_<entity>_ma__<source>`.

### Link-Varianten

| Typ | FKs | Hash-Inhalt |
|-----|-----|-------------|
| Standard Link | 2+ Hub-FKs | BKs aller Hubs |
| DC Link (Pure) | 1 Hub-FK | Parent-BK + DCKs |
| DC Link (Hybrid) | 2 Hub-FKs + DC | beide BKs + DCK |
| Transaction Link (`_tl`) | 2+ Hub-FKs | **Event-ID** + BKs; `incremental_strategy='append'`, kein Hashdiff |

### Reference Table

Stabile Lookups (Länder, Status, Rollen): **kein Hub, keine Historisierung, nicht übermodellieren.** Als dbt-Seed (`seeds/ref_<name>.csv` + `column_types` in dbt_project.yml) oder als View auf eine Stammdaten-Staging-View.

### PSA (Persistent Staging Area) — optionaler Cache-Layer

Cached External-Table-Daten (PolyBase/OPENROWSET) in einer inkrementellen Tabelle, damit nicht jeder dbt-Run teuer gegen den Data Lake liest.

| Szenario | PSA? |
|----------|------|
| Kleine Parquet-Dateien, seltene Runs | ❌ |
| Große Datenmengen, häufige Runs, Merge-Logik, inkrementelle Verarbeitung | ✅ |

Datenfluss: `ext_<quelle>_<entity>` → `psa_<quelle>_<entity>` (incremental, `merge` mit unique_key oder `append`; HWM-Filter auf `dss_load_date`) → Staging View referenziert die **PSA** statt der External Table (`ref()` statt `source()`) — die Hash-Berechnung bleibt in der Staging View.

### PIT Table

Nur bei Performance-Bedarf für As-of-Abfragen über viele Satellites. Rein technisch: `hk_<entity>`, `snapshot_date`, je Satellite der Verweis auf den gültigen Stand. Kein Pflichtbestandteil.

## Betriebswissen

### dbt-Selektoren — immer pfadbasiert

Modellnamen können in mehreren Concepts existieren. Deshalb:

```bash
dbt run --select raw_vault.<concept>.hub_company     # ✅ eindeutig
dbt run --select hub_company                          # ❌ trifft alle Concepts
dbt run --select "+raw_vault.<concept>.sat_company"   # inkl. Upstream (Staging)
```

### External-Table-Workflow (neue Quelle)

```bash
dbt run-operation list_parquet_files --args '{"folder_path": "<quelle>/ordner"}'
dbt run-operation get_parquet_schema --args '{"folder_path": "<quelle>/ordner", "file_name": "<datei>.parquet"}'   # YAML für sources.yml
dbt run-operation get_parquet_data   --args '{"folder_path": "<quelle>/ordner", "file_name": "<datei>.parquet", "limit": 5}'
dbt run-operation stage_external_sources                                  # alle (idempotent)
dbt run-operation create_external_table --args '{"table_name": "ext_<name>"}'  # nur eine (schneller)
```

### Checkliste: Neue Entity

```
□ External Table in sources.yml definiert
□ Staging View (Hash Key, Hash Diff, Metadata-Spalten)
□ Hub / Satellite (post_hook Current Flag!) / ggf. Link
□ Schema-YAML mit Tests (hk unique+not_null bei Hub/Link, BK not_null)
□ ER-Diagramm im design/-Ordner aktualisiert
□ dbt run-operation stage_external_sources
□ dbt run --select "+raw_vault.<concept>.<modelle>"
□ dbt test --select raw_vault.<concept>
□ Ghost Records erweitert (optional, insert_ghost_records-Macro)
```

### Checkliste: Attribut ergänzen

```
□ sources.yml → Staging View → ggf. Hashdiff-Liste → Satellite-Payload
□ dbt run-operation stage_external_sources
□ dbt run --select <staging> <satellite>     (on_schema_change: append_new_columns
   ergänzt neue Spalten OHNE Full Refresh; bestehende Zeilen haben NULL)
□ dbt test
```

Hashdiff nur erweitern, wenn Änderungen an der Spalte historisiert werden sollen — jede Hashdiff-Änderung erzeugt beim nächsten Load für alle Schlüssel genau ein neues Delta (einmaliger „Knick" in der Historie, dokumentieren!).

### Pre-Deployment

```
□ Tests lokal grün, SQL kompiliert geprüft (dbt compile)
□ Keine hardcodierten Datenbanknamen
□ as_columnstore: false auf physischen Tabellen (Azure SQL Basic/Serverless)
□ Hash-Berechnungsweg konsistent (ein Separator je Entity — siehe templates.md)
□ Schema-YAML + design/-Diagramme aktuell
```
