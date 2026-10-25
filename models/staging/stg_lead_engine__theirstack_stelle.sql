{#
    Staging: stg_lead_engine__theirstack_stelle
    Quelle: base_lead_engine__theirstack_stelle (Lead-Engine, source = 'theirstack')
    BK Stelle: stelle_bk (id, Zahl -> Text) · BK Firma: firma_bk (company_object.id, '-1' = unbekannt)
    Kollisionscode: theirstack
    Hashes: hk_stelle -> hub_stelle · hk_firma -> hub_firma (via __firma) · hk_link_stelle_firma
            hd_stelle__theirstack -> sat_stelle__theirstack · hd_firma__theirstack -> sat_firma__theirstack
            hd_stelle_sichtung__theirstack -> sat_stelle_sichtung__theirstack
    Nicht im Hashdiff: description, Geodaten
    Version: 2026-10-25 V1.0 Initialversion
#}
{%- set yaml_metadata -%}
source_model: base_lead_engine__theirstack_stelle
derived_columns:
  dss_record_source: "!lead-engine/theirstack"
  dss_load_date: "COALESCE(TRY_CAST(fetched_at AS DATETIME2), GETDATE())"
  dss_create_datetime: "CAST(GETDATE() AS DATETIME2)"
  dss_business_key: "CONCAT_WS('||', 'default', 'theirstack', ISNULL(LTRIM(RTRIM(CAST(stelle_bk AS NVARCHAR(MAX)))), '-1'))"
  collision_code: "!theirstack"
hashed_columns:
  hk_stelle: [collision_code, stelle_bk]
  hk_firma: [collision_code, firma_bk]
  hk_link_stelle_firma: [collision_code, stelle_bk, firma_bk]
  hd_stelle__theirstack:
    is_hashdiff: true
    columns: [title, url, date_posted, closed_at, location, seniority, is_remote, is_hybrid, technologies]
  hd_firma__theirstack:
    is_hashdiff: true
    columns: [company_name, company_domain, employee_count, employee_count_range, industry, company_linkedin, is_recruiting_agency]
  hd_stelle_sichtung__theirstack:
    is_hashdiff: true
    columns: [run_id, query_ids]
{%- endset -%}

{{ automate_dv.stage(**fromyaml(yaml_metadata)) }}
