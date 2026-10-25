{#
    Staging: stg_lead_engine__karriere_stelle
    Quelle: base_lead_engine__karriere_stelle (Lead-Engine, source = 'karriere')
    BK Stelle: stelle_bk (jobsItem.id, Text) · BK Firma: firma_bk (jobsItem.companyId, '-1' = anonym)
    Kollisionscode: karriere (Segment 2 von dss_business_key, Teil aller Hash Keys)
    Hashes: hk_stelle -> hub_stelle · hk_firma -> hub_firma (via __firma) · hk_link_stelle_firma
            hd_stelle__karriere -> sat_stelle__karriere · hd_firma__karriere -> sat_firma__karriere
            hd_stelle_sichtung__karriere -> sat_stelle_sichtung__karriere
    Version: 2026-10-25 V1.0 Initialversion
#}
{%- set yaml_metadata -%}
source_model: base_lead_engine__karriere_stelle
derived_columns:
  dss_record_source: "!lead-engine/karriere"
  dss_load_date: "COALESCE(TRY_CAST(fetched_at AS DATETIME2), GETDATE())"
  dss_create_datetime: "CAST(GETDATE() AS DATETIME2)"
  dss_business_key: "CONCAT_WS('||', 'default', 'karriere', ISNULL(LTRIM(RTRIM(CAST(stelle_bk AS NVARCHAR(MAX)))), '-1'))"
  collision_code: "!karriere"
hashed_columns:
  hk_stelle: [collision_code, stelle_bk]
  hk_firma: [collision_code, firma_bk]
  hk_link_stelle_firma: [collision_code, stelle_bk, firma_bk]
  hd_stelle__karriere:
    is_hashdiff: true
    columns: [title, link, posted_date, employment_types, salary, is_home_office, locations, is_active]
  hd_firma__karriere:
    is_hashdiff: true
    columns: [company_name, company_slug, company_size, company_main_location, company_link]
  hd_stelle_sichtung__karriere:
    is_hashdiff: true
    columns: [run_id, query_ids]
{%- endset -%}

{{ automate_dv.stage(**fromyaml(yaml_metadata)) }}
