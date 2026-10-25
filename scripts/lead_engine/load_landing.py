"""Laedt die Lead-Engine-Landing-Dateien (JSON im Storage Account) in die Landing-Tabellen.

Ziel: landing.lead_engine_datei (eine Zeile je Datei aus raw/<quelle>/...)
      landing.lead_engine_lauf  (eine Zeile je Laufprotokoll aus raw/_runs/...)

Dateien werden vom Collector nie ueberschrieben, daher inkrementell ueber das Aenderungsdatum
und write_disposition="append". Konfiguration per Umgebungsvariablen (siehe README.md):

  LEAD_ENGINE_STORAGE_ACCOUNT   z. B. stdimetricsdvweumcpp
  LEAD_ENGINE_CONTAINER         Standard: load
  SQL_SERVER, SQL_DATABASE, SQL_USER, SQL_PASSWORD

Storage-Zugriff: Azure-Login (az login) per DefaultAzureCredential oder AZURE_STORAGE_SAS_TOKEN.
"""
import json
import os

import dlt
from dlt.sources.filesystem import filesystem

ENV_KEYS = ("schema", "collector_version", "source", "run_id", "fetched_at",
            "query_id", "query_label", "page", "item_count")
RUN_KEYS = ("schema", "collector_version", "run_id", "started_at", "finished_at")

ACCOUNT = os.environ["LEAD_ENGINE_STORAGE_ACCOUNT"]
CONTAINER = os.environ.get("LEAD_ENGINE_CONTAINER", "load")
BUCKET = f"az://{CONTAINER}/lead-engine/raw"


def _storage_credentials() -> dict:
    creds = {"azure_storage_account_name": ACCOUNT}
    if os.environ.get("AZURE_STORAGE_SAS_TOKEN"):
        creds["azure_storage_sas_token"] = os.environ["AZURE_STORAGE_SAS_TOKEN"]
    return creds


def _files(glob: str, name: str = "filesystem"):
    # eigener Resource-Name je Glob: der Incremental-Zustand (modification_date) ist je Name getrennt
    res = filesystem(bucket_url=BUCKET, file_glob=glob, credentials=_storage_credentials()).with_name(name)
    res.apply_hints(incremental=dlt.sources.incremental("modification_date"))
    return res


def _json_text(value) -> str | None:
    return None if value is None else json.dumps(value, ensure_ascii=False)


@dlt.transformer(name="lead_engine_datei", write_disposition="append",
                 primary_key="file_path",
                 columns={"run_id": {"data_type": "text"},
                          "file_modified": {"data_type": "timestamp"},
                          "fetched_at": {"data_type": "timestamp"},
                          "page": {"data_type": "bigint"},
                          "item_count": {"data_type": "bigint"}})
def lead_engine_datei(items):
    for f in items:
        if "/_runs/" in f["file_url"]:
            continue
        doc = json.loads(f.read_bytes())
        total = doc.get("total_reported")
        yield {"file_path": f["file_url"], "file_modified": f["modification_date"],
               **{k: doc.get(k) for k in ENV_KEYS},
               "total_reported": None if total is None else str(total),
               "query_params": _json_text(doc.get("query_params")),
               "request": _json_text(doc.get("request")),
               "payload": _json_text(doc.get("payload"))}


@dlt.transformer(name="lead_engine_lauf", write_disposition="append", primary_key="run_id",
                 columns={"run_id": {"data_type": "text"},
                          "started_at": {"data_type": "timestamp"},
                          "finished_at": {"data_type": "timestamp"}})
def lead_engine_lauf(items):
    for f in items:
        doc = json.loads(f.read_bytes())
        yield {"file_path": f["file_url"], "file_modified": f["modification_date"],
               **{k: doc.get(k) for k in RUN_KEYS},
               "sources": _json_text(doc.get("sources")),
               "queries": _json_text(doc.get("queries")),
               "files": _json_text(doc.get("files"))}


def main() -> None:
    destination = dlt.destinations.mssql(credentials={
        "host": os.environ["SQL_SERVER"], "port": 1433,
        "database": os.environ["SQL_DATABASE"],
        "username": os.environ["SQL_USER"], "password": os.environ["SQL_PASSWORD"],
        "driver": "ODBC Driver 18 for SQL Server",
    })
    pipeline = dlt.pipeline("lead_engine_landing", destination=destination, dataset_name="landing")
    # Ordner (Data Lake) erscheinen beim Auflisten als Eintraege, daher nur *.json
    print(pipeline.run(_files("**/*.json") | lead_engine_datei))
    print(pipeline.run(_files("_runs/**/*.json", "filesystem_runs") | lead_engine_lauf))


if __name__ == "__main__":
    main()
