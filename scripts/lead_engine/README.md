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
- Base-Tabellen `base_lead_engine__*_stelle` übernehmen nur abgeschlossene Läufe (neueste Datei des Laufs ≥ 30 Min. alt) mit größerer `run_id`.
  Neue Leads erscheinen daher frühestens 30 Minuten nach Ende eines Collector-Laufs.
- Das Laufprotokoll (`landing.lead_engine_lauf`) wird dafür nicht mehr verwendet: seit Collector 0.3.0 (Dagster) hat es eine andere `run_id` als die Dateien.
- Quellen ohne Modell (z. B. `source = 'freelancer'`) werden zwar geladen, aber nicht verarbeitet.
