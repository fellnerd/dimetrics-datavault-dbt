# Lead-Engine: Landing & dbt-Staging

Oct 25, 2026 · @Daniel

Der Collector legt Rohdaten unverändert als JSON in `load/lead-engine` ab. Diese Anleitung beschreibt Aufbau und Felder der Dateien und schlägt vor, wie du sie in die Datenbank lädst und in dbt stagest.

## Überblick

Jede Landing-Datei ist ein JSON-Dokument mit einem festen Umschlag und der unveränderten Antwort der Quelle im Feld `payload`. Ins Staging gehört deshalb immer zweierlei: die Metadaten des Umschlags und die Anzeigen aus dem Payload.

1. **Collector** (`collect.py`) fragt die Quellen ab und schreibt pro Abfrage bzw. Seite eine Datei.
2. **Load** holt neue Dateien aus dem Storage Account in eine Landing-Tabelle der Datenbank, eine Zeile pro Datei.
3. **dbt-Staging** zerlegt den Payload mit `OPENJSON` in eine Zeile pro Anzeige und berechnet Business Keys, Hash Keys und Hashdiffs.
4. **Raw Vault**: Hubs Stelle und Firma, Link Stelle–Firma, Satelliten pro Quelle.

**Ablage**

| Was | Pfad im Storage Account `stdimetricsdvweumcpp` |
| --- | --- |
| Rohdaten | `load/lead-engine/raw/<quelle>/<jjjj>/<mm>/<tt>/<run_id>/<query_id>[__pNN].json` |
| Laufprotokoll | `load/lead-engine/raw/_runs/<jjjj>/<mm>/<tt>/<run_id>.json` |
| Code, Konfiguration, `LANDING.md` | `apps/lead-engine/collector/` |

**Grundregeln**

- Dateien werden nie überschrieben. `run_id` ist der UTC-Startzeitpunkt des Laufs, z. B. `20261025T141113Z`.
- Quellen derzeit: `karriere`, `website`, `theirstack`. Neue Portale kommen mit demselben Umschlag dazu.
- Der Account hat einen hierarchischen Namespace. Ordner erscheinen beim Auflisten als eigene Einträge, deshalb nur `*.json` laden.
- Dieselbe Anzeige taucht in mehreren Dateien auf: unter mehreren Abfragen, auf mehreren Seiten und in jedem Lauf erneut. Das Deduplizieren ist Aufgabe von Staging und Vault.

## Landing-Datei: Umschlag und Laufprotokoll

Alle Landing-Dateien haben dieselben Felder auf oberster Ebene (`schema = lead-engine.landing.v1`). Nur `payload` unterscheidet sich je Quelle.

| Feld | Typ | Bedeutung | Verwendung im Staging |
| --- | --- | --- | --- |
| `schema` | Text | Formatversion | bei neuer Version Staging prüfen |
| `collector_version` | Text | Version des Collectors, derzeit `0.2.0` | Metadaten |
| `source` | Text | `karriere`, `website`, `theirstack` | Teil von `dss_record_source`, Kollisionscode im BK |
| `run_id` | Text | UTC-Startzeit des Laufs, `JJJJMMTTTHHMMSSZ` | Lauf-Referenz |
| `fetched_at` | Text, ISO 8601 UTC | Abrufzeitpunkt dieser Datei | **`dss_load_date`** |
| `query_id` | Text | stabile ID der Abfrage, z. B. `kw-controller__kaernten` | Herkunft der Anzeige |
| `query_label` | Text | lesbarer Name der Abfrage | optional |
| `query_params` | Objekt | Parameter laut Konfiguration (Region, Berufsfeld, Stichwort, Start-URL) | Region und Suchkriterium ableiten |
| `request` | Objekt | tatsächliche Anfrage: URL oder Body, `config_version` | Nachvollziehbarkeit |
| `page` | Zahl oder null | Seitennummer bei karriere und theirstack | optional |
| `total_reported` | Text oder Zahl | Gesamtzahl laut Quelle. Bei karriere als Text, z. B. `"52"` | Vollständigkeit, mit `TRY_CAST` lesen |
| `item_count` | Zahl | Anzeigen in dieser Datei | Abgleich mit Staging-Zeilen |
| `payload` | Objekt | **Rohantwort der Quelle** | siehe nächster Abschnitt |

**Laufprotokoll** (`raw/_runs/…/<run_id>.json`, `schema = lead-engine.run.v1`)

| Feld | Inhalt |
| --- | --- |
| `run_id`, `started_at`, `finished_at` | Lauf und Dauer |
| `sources.<quelle>` | `status` (`ok` oder `failed`), `seconds`, `queries`, `items`, `errors`, `truncated` |
| `queries[]` | je Abfrage: `source`, `query_id`, `total_reported`, `items`, `pages`, `truncated`, `error` |
| `files[]` | alle Landing-Dateien dieses Laufs, relativ zu `load/lead-engine/` |

Das Laufprotokoll gibt ein eigenes kleines Staging-Modell für das Monitoring der Vollständigkeit: `items` gegen `total_reported`, `truncated` und `error` je Abfrage und Lauf.

## Payload je Quelle

Pro Quelle ein Pfad zum Array der Anzeigen und die Felder, die für Hub, Link und Satellit gebraucht werden. Alle weiteren Felder bleiben im Rohdokument und lassen sich später nachziehen.

### karriere

Anzeigen: `$.payload.data.jobsSearchList.activeItems.items[*].jobsItem`. Einträge ohne `jobsItem`, etwa die Job-Alarm-Box, überspringen.

| JSON-Pfad (ab `jobsItem`) | Typ | Bedeutung |
| --- | --- | --- |
| `$.id` | Text, z. B. `"7712780"` | **stabile Anzeigen-ID** |
| `$.companyId` | Text, z. B. `"3927"` | **stabile Firmen-ID** auf karriere.at |
| `$.title` | Text | Jobtitel |
| `$.link` | Text | URL der Anzeige |
| `$.date` | Text, relativ | z. B. „Heute“, „Gestern“, „vor 4 Tagen veröffentlicht“, „17.10.2026“. Mit `fetched_at` in ein Datum umrechnen. |
| `$.employmentTypes` | Text | z. B. „Vollzeit, Teilzeit“ |
| `$.salary` | Text | z. B. „ab 48.165 € jährlich“ |
| `$.isHomeOffice` | bool |  |
| `$.isActive` | bool |  |
| `$.pushedJob` | bool | gesponserte Anzeige, kann auf mehreren Seiten erscheinen |
| `$.summary`, `$.snippet` | Text | Kurztext der Anzeige |
| `$.locations[*].name` | Array | Orte der Stelle |
| `$.company.name` | Text | Firmenname |
| `$.company.slug` | Text | URL-Name der Firma |
| `$.company.employees` | Text | Größenklasse: `1 - 10`, `11 - 30`, `31 - 50`, `51 - 100`, `101 - 500`, `501+`, `501 - 2500`, `2501 - 10000`, `10000+` |
| `$.company.mainLocation` | Text | Hauptsitz laut Profil |
| `$.company.link` | Text | Firmenprofil auf karriere.at |

Zusätzlich in `$.payload.data.jobsSearchList`: `jobsListHeader.count` (Gesamtzahl als Text) und `loadMoreJobsButton.active`.

### theirstack

Anzeigen: `$.payload.data[*]`. Metadaten in `$.payload.metadata`.

| JSON-Pfad (ab Anzeige) | Typ | Bedeutung |
| --- | --- | --- |
| `$.id` | **Zahl** | stabile Anzeigen-ID, für den BK in Text umwandeln |
| `$.job_title` | Text | Jobtitel |
| `$.url`, `$.source_url`, `$.final_url` | Text | Links zur Anzeige |
| `$.date_posted` | Text `JJJJ-MM-TT` | Veröffentlichung |
| `$.discovered_at` | Text ISO 8601 | Fund durch TheirStack |
| `$.closed_at` | Text oder null | Schließung erkannt |
| `$.long_location`, `$.state_code`, `$.country_code` | Text | Ort |
| `$.seniority`, `$.remote`, `$.hybrid` | Text, bool |  |
| `$.technology_slugs`, `$.keyword_slugs` | Array | erkannte Technologien und Stichworte |
| `$.description` | Text, lang | Volltext der Anzeige, nicht in den Hashdiff |
| `$.company_object.id` | Text | **stabile Firmen-ID** bei TheirStack |
| `$.company_object.name`, `.domain`, `.linkedin_url` | Text | Firmendaten, oft null |
| `$.company_object.employee_count`, `.employee_count_range`, `.industry` | Zahl, Text | Größe und Branche, oft null |
| `$.company_object.is_recruiting_agency` | bool | Personalvermittler |

### website

Eine Datei pro Firma, Anzeigen in `$.payload.jobs[*]`.

| JSON-Pfad | Typ | Bedeutung |
| --- | --- | --- |
| `$.payload.company.name`, `.url`, `.region` | Text | Eintrag aus `companies.json` |
| `$.payload.jobs_url` | Text | gefundene Jobliste |
| `$.payload.jobs[*].title` | Text | Jobtitel |
| `$.payload.jobs[*].url` | Text | Link. Oft die Jobliste selbst, also **nicht eindeutig** |
| `$.payload.pages_visited[*]` | Objekt | `url`, `status_code`, `error`, `job_candidates` |
| `$.payload.note` | Text | Grund, falls keine Stellen gefunden wurden |

Die Quelle hat **keine eigene Anzeigen-ID**. Der Business Key muss aus Firma und normalisiertem Titel gebildet werden.

## Laden in die Datenbank

Empfehlung: eine Landing-Tabelle mit **einer Zeile pro Datei**. Die Umschlagfelder kommen als Spalten, `payload`, `query_params` und `request` als JSON-Text (`NVARCHAR(MAX)`). Das Zerlegen übernimmt dbt mit `OPENJSON`. So bleibt die Rohantwort vollständig in der Datenbank, und eine neue Quelle braucht keine neue Ladestrecke.

Warum keine External Table: Das Format ist verschachteltes JSON mit je Quelle anderem Payload. External Tables auf SQL Server erwarten Parquet oder CSV mit festem Schema.

**Zieltabellen**

| Tabelle | Inhalt | Schlüssel |
| --- | --- | --- |
| `landing.lead_engine_datei` | eine Zeile je Landing-Datei aus `raw/<quelle>/…` | `file_path` |
| `landing.lead_engine_lauf` | eine Zeile je Laufprotokoll aus `raw/_runs/…` | `run_id` |

| Spalte in `lead_engine_datei` | Typ |
| --- | --- |
| `file_path`, `file_modified` | `NVARCHAR(400)`, `DATETIME2` |
| `schema`, `collector_version`, `source`, `run_id`, `query_id`, `query_label` | `NVARCHAR` |
| `fetched_at` | `DATETIME2` |
| `page`, `item_count` | `INT` |
| `total_reported` | `NVARCHAR(20)`, als Text laden, weil der Typ je Quelle wechselt |
| `query_params`, `request`, `payload` | `NVARCHAR(MAX)` mit JSON |

**Ladestrecke mit dlt (Vorschlag)**

Inkrementell über das Änderungsdatum der Datei. Weil Dateien nie überschrieben werden, reicht `append`. Die Namen der Felder des Datei-Objekts je nach dlt-Version prüfen.

```python
import json
import dlt
from dlt.sources.filesystem import filesystem

ENV_KEYS = ("schema", "collector_version", "source", "run_id", "fetched_at",
            "query_id", "query_label", "page", "item_count")

dateien = filesystem(bucket_url="az://load/lead-engine/raw", file_glob="**/*.json")
dateien.apply_hints(incremental=dlt.sources.incremental("modification_date"))

@dlt.transformer(name="lead_engine_datei", write_disposition="append", primary_key="file_path")
def lead_engine_datei(items):
    for f in items:
        if "/_runs/" in f["file_url"]:
            continue
        doc = json.loads(f.read_bytes())
        yield {"file_path": f["file_url"], "file_modified": f["modification_date"],
               **{k: doc.get(k) for k in ENV_KEYS},
               "total_reported": None if doc.get("total_reported") is None else str(doc["total_reported"]),
               "query_params": json.dumps(doc.get("query_params"), ensure_ascii=False),
               "request": json.dumps(doc.get("request"), ensure_ascii=False),
               "payload": json.dumps(doc.get("payload"), ensure_ascii=False)}

pipeline = dlt.pipeline("lead_engine_landing", destination="mssql", dataset_name="landing")
pipeline.run(dateien | lead_engine_datei)
```

Das Laufprotokoll lädst du genauso mit `file_glob="_runs/**/*.json"`, `primary_key="run_id"` und `sources`, `queries` und `files` als JSON-Text. Zugang: Account-Name und Key bzw. besser ein SAS oder eine Managed Identity in den dlt-Credentials für `az://`.

Alternative ohne dlt: eine ADF-Pipeline mit `Get Metadata` und `ForEach`, die jede neue Datei per `OPENROWSET(BULK …, SINGLE_CLOB)` als Ganzes in dieselbe Tabelle schreibt.

**`sources.yml`**

```yaml
sources:
  - name: lead_engine
    schema: landing
    tables:
      - name: lead_engine_datei
        description: Eine Zeile je Landing-Datei des Lead-Engine-Collectors (schema lead-engine.landing.v1)
        loaded_at_field: fetched_at
      - name: lead_engine_lauf
        description: Laufprotokolle des Collectors (schema lead-engine.run.v1)
```

## Staging-Modelle in dbt

Je Quelle zwei Schichten: eine **Base-View**, die den Payload mit `OPENJSON` in eine Zeile pro Anzeige zerlegt und pro Lauf dedupliziert, und darauf die **Staging-View** mit `automate_dv.stage()` für Business Keys, Hash Keys und Hashdiffs.

| Modell | Quelle | Granularität |
| --- | --- | --- |
| `base_lead_engine__karriere_stelle` | `lead_engine_datei` mit `source = 'karriere'` | eine Zeile je Lauf und Anzeigen-ID |
| `base_lead_engine__theirstack_stelle` | `source = 'theirstack'` | eine Zeile je Lauf und Anzeigen-ID |
| `base_lead_engine__website_stelle` | `source = 'website'` | eine Zeile je Lauf, Firma und normalisiertem Titel |
| `stg_lead_engine__<quelle>_stelle` | jeweilige Base-View | wie Base, plus Hashes |
| `stg_lead_engine__lauf_abfrage` | `lead_engine_lauf`, `OPENJSON(queries)` | eine Zeile je Lauf und Abfrage, für das Monitoring |

**Deduplizieren in der Base-View:** Pro `run_id` und Anzeigen-ID nur eine Zeile behalten, z. B. per `ROW_NUMBER()` nach `fetched_at`. Die Abfragen, in denen die Anzeige gefunden wurde, als `STRING_AGG(query_id)` mitführen. Über mehrere Läufe bleibt die Anzeige mehrfach, das löst der Hashdiff im Satelliten.

**Business Keys**

| Ziel | Kollisionscode | Business Key | Herkunft |
| --- | --- | --- | --- |
| Hub Stelle `hub_stelle` | Quelle | Anzeigen-ID der Quelle | karriere `jobsItem.id`, theirstack `id` als Text, website Firmen-Domain + normalisierter Titel |
| Hub Firma `hub_firma` | Quelle | Firmen-ID der Quelle | karriere `jobsItem.companyId`, theirstack `company_object.id`, website Domain aus `payload.company.url` |
| Link `link_stelle_firma` |  | beide BKs |  |

Die Quelle gehört als Kollisionscode in Segment 2 von `dss_business_key`, weil dieselbe Zahl in zwei Quellen etwas anderes meint. Dieselbe Firma aus mehreren Quellen führst du später im Business Vault über einen Same-as-Link zusammen, sobald das Firmenbuch angebunden ist.

**Metadaten**

- `dss_load_date` = `fetched_at` der Datei
- `dss_record_source` = `'lead-engine/' + source`, bei Bedarf mit `query_id`
- `dss_create_datetime` wie im Projektstandard

**Satelliten und Hashdiff-Spalten**

| Satellit | Payload im Hashdiff | bewusst nicht im Hashdiff |
| --- | --- | --- |
| `sat_stelle__karriere` | Titel, Link, `posted_date` (abgeleitet), Beschäftigungsart, Gehalt, Homeoffice, Orte als Text, `isActive` | `date` als Rohtext, weil „vor 4 Tagen“ täglich wechselt; `summary`, `snippet` |
| `sat_firma__karriere` | Name, Slug, Größenklasse, Hauptsitz, Profil-Link | Logo-URL, Branding-Flags |
| `sat_stelle__theirstack` | Titel, URL, `date_posted`, `closed_at`, Ort, Seniorität, remote, hybrid, Technologien als Text | `description`, Geodaten |
| `sat_firma__theirstack` | Name, Domain, Mitarbeiterzahl, Größenklasse, Branche, LinkedIn, Vermittler-Flag | Zähler wie `num_jobs` |
| `sat_stelle__website` | Titel, URL |  |
| `sat_stelle_sichtung` | `run_id`, `query_ids` |  |

Der letzte Satellit ist ein **Sichtungs-Satellit**: Er bekommt bei jedem Lauf eine Zeile, auch wenn sich an der Anzeige nichts ändert. Daraus leitest du „zuletzt gesehen“ und „nicht mehr online“ ab, was für die Lead-Bewertung wichtig ist.

Ableitungen wie Region, Relevanz, Vermittler- und Konzernflag oder der Firmenabgleich gehören in den Business Vault bzw. das Information Mart. Regeln dafür findest du in `apps/lead-engine/collector/prototypes/pipeline_prototype.py`.

## Beispiel-SQL für karriere.at

Skizze für SQL Server bzw. Azure SQL, ungetestet. Theirstack und website folgen demselben Muster mit ihren Pfaden aus dem Abschnitt „Payload je Quelle“.

**Base-View** `base_lead_engine__karriere_stelle.sql`

```sql
{{ config(materialized='view') }}

with items as (
    select
        f.run_id, f.query_id, f.fetched_at, f.file_path,
        j.*
    from {{ source('lead_engine', 'lead_engine_datei') }} f
    cross apply openjson(f.payload, '$.data.jobsSearchList.activeItems.items') it
    cross apply openjson(it.[value], '$.jobsItem') with (
        job_id                nvarchar(20)  '$.id',
        company_id            nvarchar(20)  '$.companyId',
        title                 nvarchar(400) '$.title',
        link                  nvarchar(400) '$.link',
        date_text             nvarchar(100) '$.date',
        employment_types      nvarchar(200) '$.employmentTypes',
        salary                nvarchar(200) '$.salary',
        is_home_office        bit           '$.isHomeOffice',
        is_active             bit           '$.isActive',
        pushed_job            bit           '$.pushedJob',
        locations_json        nvarchar(max) '$.locations' as json,
        company_name          nvarchar(400) '$.company.name',
        company_slug          nvarchar(200) '$.company.slug',
        company_size          nvarchar(30)  '$.company.employees',
        company_main_location nvarchar(200) '$.company.mainLocation',
        company_link          nvarchar(400) '$.company.link'
    ) j
    where f.source = 'karriere'
),

queries as (   -- in welchen Abfragen eines Laufs die Anzeige vorkam
    select run_id, job_id,
           string_agg(query_id, ',') within group (order by query_id) as query_ids
    from (select distinct run_id, job_id, query_id from items) d
    group by run_id, job_id
),

ranked as (
    select i.*,
           row_number() over (partition by i.run_id, i.job_id order by i.fetched_at, i.file_path) as rn
    from items i
)

select
    r.run_id, r.fetched_at, r.job_id, r.company_id, r.title, r.link,
    r.employment_types, r.salary, r.is_home_office, r.is_active, r.pushed_job,
    r.company_name, r.company_slug, r.company_size, r.company_main_location, r.company_link,
    q.query_ids,
    (select string_agg(json_value(l.[value], '$.name'), ', ')
       from openjson(r.locations_json) l) as locations,
    r.date_text,
    case
        when r.date_text like 'Heute%'      then cast(r.fetched_at as date)
        when r.date_text like 'Gestern%'    then dateadd(day, -1, cast(r.fetched_at as date))
        when r.date_text like 'vor % Tag%'  then dateadd(day,
             -try_cast(substring(r.date_text, 5, charindex(' ', r.date_text, 5) - 5) as int),
             cast(r.fetched_at as date))
        else try_convert(date, substring(r.date_text,
             patindex('%[0-9][0-9].[0-9][0-9].[0-9][0-9][0-9][0-9]%', r.date_text), 10), 104)
    end as posted_date
from ranked r
join queries q on q.run_id = r.run_id and q.job_id = r.job_id
where r.rn = 1
```

`fetched_at` ist UTC. Für „Heute“ und „Gestern“ ggf. vorher mit `AT TIME ZONE 'W. Europe Standard Time'` auf österreichische Zeit umrechnen.

**Staging-View** `stg_lead_engine__karriere_stelle.sql` (Pattern A, an euren Projektstandard anpassen)

```sql
{%- set yaml_metadata -%}
source_model: base_lead_engine__karriere_stelle
derived_columns:
  dss_record_source: "!lead-engine/karriere"
  dss_load_date: "COALESCE(TRY_CAST(fetched_at AS DATETIME2), GETDATE())"
  dss_create_datetime: "CAST(GETDATE() AS DATETIME2)"
  dss_business_key: "CONCAT_WS('||', 'default', 'karriere', ISNULL(LTRIM(RTRIM(CAST(job_id AS NVARCHAR(MAX)))), '-1'))"
  collision_code: "!karriere"
hashed_columns:
  hk_stelle: [collision_code, job_id]
  hk_firma: [collision_code, company_id]
  hk_link_stelle_firma: [collision_code, job_id, company_id]
  hd_stelle__karriere:
    is_hashdiff: true
    columns: [title, link, posted_date, employment_types, salary, is_home_office, locations, is_active]
  hd_firma__karriere:
    is_hashdiff: true
    columns: [company_name, company_slug, company_size, company_main_location, company_link]
  hd_stelle_sichtung:
    is_hashdiff: true
    columns: [run_id, query_ids]
{%- endset -%}

{{ automate_dv.stage(**fromyaml(yaml_metadata)) }}
```

Für `hub_firma` brauchst du nach eurem Muster zusätzlich die FK-Staging-View `stg_lead_engine__karriere_stelle__firma` mit eigenem `dss_business_key` aus `company_id`.

## Prüfungen und Stolpersteine

**Tests in `_staging__models.yml`**

- `hk_stelle`, `hk_firma`: not\_null. Unique je `run_id` in der Base-View.
- `job_id`, `company_id`: not\_null. Bei karriere fehlt `company_id` nur bei anonymen Inseraten (`company.isChiffre`).
- Abgleich je Datei: Anzahl Zeilen aus `OPENJSON` = `item_count` aus dem Umschlag.
- Abgleich je Lauf und Abfrage im Monitoring: `items` gegen `total_reported`. Kleine Abweichungen nach oben bei karriere sind normal, weil gesponserte Anzeigen auf mehreren Seiten erscheinen.

**Stolpersteine**

| Thema | Was passiert | Lösung |
| --- | --- | --- |
| Typen der IDs | theirstack liefert `id` als Zahl, karriere als Text | im BK immer `CAST(… AS NVARCHAR(MAX))` |
| `total_reported` | je Quelle Text oder Zahl | als Text laden, mit `TRY_CAST(… AS INT)` lesen |
| Relatives Datum bei karriere | „vor 4 Tagen“ ändert sich täglich | nur abgeleitetes `posted_date` in den Hashdiff |
| Gleiche Anzeige mehrfach | mehrere Abfragen, Seiten, Läufe | je Lauf in der Base-View deduplizieren, über Läufe der Hashdiff |
| website ohne ID | Link zeigt oft nur auf die Jobliste | BK aus Domain + normalisiertem Titel. Ein geänderter Titel ergibt eine neue Stelle. |
| Ordner im Storage | Data Lake listet Ordner als eigene Einträge | nur `*.json` laden |
| Neue Formatversion | `schema` oder `collector_version` ändert sich | Test auf erlaubte Werte, damit eine Änderung nicht unbemerkt durchrutscht |
| JSON-Größe | karriere-Seiten enthalten neben den Anzeigen viel Seitenballast | unkritisch für `NVARCHAR(MAX)`; ggf. PSA als Tabelle statt View |
| Leere Treffer | Abfrage ohne Anzeigen erzeugt trotzdem eine Datei mit `item_count = 0` | nicht als Fehler werten, ist Teil der Vollständigkeit |

**Bei größeren Mengen:** Die `OPENJSON`-Zerlegung in eine inkrementelle PSA-Tabelle materialisieren, mit `fetched_at` als High-Water-Mark. Die Staging-Views lesen dann aus der PSA statt direkt aus der Landing-Tabelle.
