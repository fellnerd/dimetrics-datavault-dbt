# Lead-Engine: Landing-Ladestrecke (dlt)

Liest die JSON-Dateien aus `az://load/lead-engine/raw` und schreibt sie nach `landing.lead_engine_datei` (je Datei eine Zeile)
und `landing.lead_engine_lauf` (je Laufprotokoll). Inkrementell über das Änderungsdatum, `append`.

```bash
python3 -m venv .venv-dlt && .venv-dlt/bin/pip install -r scripts/lead_engine/requirements.txt
az login
export LEAD_ENGINE_STORAGE_ACCOUNT=stdimetricsdvweumcpp
export SQL_SERVER=... SQL_DATABASE=... SQL_USER=... SQL_PASSWORD=...
export SSL_CERT_FILE=$(.venv-dlt/bin/python -c "import certifi;print(certifi.where())")   # falls SSL-Zertifikatsfehler
.venv-dlt/bin/python scripts/lead_engine/load_landing.py
```

Hinweise
- `run_id` ist Text (sieht aus wie ein Zeitstempel, dlt würde es sonst als `datetimeoffset` anlegen) — deshalb die Typ-Hints im Skript.
- Pro Glob ein eigener Resource-Name (`filesystem`, `filesystem_runs`): der Incremental-Zustand ist je Name getrennt.
- Zustand liegt in `landing._dlt_pipeline_state`; Tabellen nie ohne Zurücksetzen des Zustands löschen (sonst wird nicht neu geladen).
- Danach: `dbt run --select path:models/base/lead_engine path:models/staging/stg_lead_engine__* path:models/raw_vault/_common`

Verarbeitung in dbt (inkrementell)
- Base-Tabellen übernehmen nur vollständige Läufe: Das Laufprotokoll (`landing.lead_engine_lauf`) wird erst geschrieben, wenn alle Quellen
  des Laufs fertig sind, und dlt lädt es vor dbt. Ein Lauf ohne Protokoll (abgebrochen oder manuell erzeugt) wird nicht übernommen.
- Welche Läufe noch fehlen, entscheidet ein Anti-Join (`run_id` noch nicht in der Base-Tabelle) über die letzten `lead_engine_nachholtage` (Standard 7).
  So wird ein Lauf nachgeholt, dessen Protokoll erst nach einem neueren Lauf geladen wurde. Die Satelliten verarbeiten die Läufe dagegen strikt in
  der Reihenfolge der `run_id`: Ein älterer Lauf, der nach einem neueren eintrifft, landet in der Base-Tabelle, aber nicht mehr in den Satelliten.
- Quellen ohne Modell werden zwar geladen, aber nicht verarbeitet. Aktuell modelliert: karriere, theirstack, website, freelancer, firmenprofil (Firmenattribute an `hub_firma`).

Neuaufbau und Wächter
- Vollständiger Neuaufbau (Entwicklung): Vault-Tabellen der Lead-Engine löschen, dann `dbt run --full-refresh --select path:models/base/lead_engine path:models/staging/stg_lead_engine__* path:models/raw_vault/_common path:models/business_vault path:models/mart/lead_engine`
  (ca. 1 Minute bei 7 Läufen). Das Ergebnis ist identisch mit dem inkrementellen Stand. Wichtig: erst die Vault-Tabellen löschen, sonst liest das Delta-Staging ab dem alten Wasserstand und der Satellit bleibt leer.
- Läufe ohne Laufprotokoll (manuell erzeugt oder abgebrochen) werden nicht übernommen, weil ein unvollständiger Lauf Stellen fälschlich als „nicht mehr online“ zeigt. Geprüfte Ausnahmen stehen in `lead_engine_freigegebene_laeufe` (`dbt_project.yml`).
- `dbt test` meldet mit `lead_engine_laeufe_fehlen_im_vault` (Warnung) Läufe der letzten 7 Tage mit Treffern, die nicht im Vault sind, und prüft mit `lead_engine_satelliten_duplikate` die Satelliten auf doppelte Zeilen.
