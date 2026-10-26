{#
    Staging: stg_lead_engine__website_stelle
    Quelle: base_lead_engine__website_stelle_delta (nur neue Laeufe; Lead-Engine, source = 'website')
    BK Stelle: stelle_bk (Domain|normalisierter Titel) · BK Firma: firma_bk (Domain aus company.url)
    Kollisionscode: website
    Hashes: hk_stelle -> hub_stelle · hk_firma -> hub_firma (via __firma) · hk_link_stelle_firma
            hd_stelle__website -> sat_stelle__website
            hd_stelle_sichtung__website -> sat_stelle_sichtung__website
    Version: 2026-10-25 V1.0 Initialversion
    Version: 2026-10-25 V1.1 profil_ids (Suchprofil, das die Stelle im Lauf gefunden hat)
    Materialisierung: table (statt view), weil automate_dv.sat() die Quelle mehrfach liest (auch in einer korrelierten
    Unterabfrage je Zeile) und SQL Server eine View samt Hash-Berechnung sonst jedes Mal neu auswertet.
    Version: 2026-10-26 V1.2 als Tabelle materialisiert
    Version: 2026-10-26 V1.4 hk_firma aus firma_quelle (karriere/theirstack/website) + firma_bk: Stellen haengen an bestehende hub_firma-Zeilen
    Version: 2026-10-26 V1.3 Delta: liest nur Laeufe, die der Vault noch nicht verarbeitet hat
#}
{{ config(
    materialized='table',
    as_columnstore=false,
    post_hook=["{{ create_hash_index('hk_stelle') }}"]
) }}
{%- set yaml_metadata -%}
source_model: base_lead_engine__website_stelle_delta
derived_columns:
  dss_record_source: "!lead-engine/website"
  dss_load_date: "COALESCE(TRY_CAST(fetched_at AS DATETIME2), GETDATE())"
  dss_create_datetime: "CAST(GETDATE() AS DATETIME2)"
  dss_business_key: "CONCAT_WS('||', 'default', 'website', ISNULL(LTRIM(RTRIM(CAST(stelle_bk AS NVARCHAR(MAX)))), '-1'))"
  collision_code: "!website"
hashed_columns:
  hk_stelle: [collision_code, stelle_bk]
  hk_firma: [firma_quelle, firma_bk]
  hk_link_stelle_firma: [collision_code, stelle_bk, firma_bk]
  hd_stelle__website:
    is_hashdiff: true
    columns: [title, url]
  hd_stelle_sichtung__website:
    is_hashdiff: true
    columns: [run_id, query_ids, profil_ids]
{%- endset -%}

{{ automate_dv.stage(**fromyaml(yaml_metadata)) }}
