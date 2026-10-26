{#
    FK-Staging: stg_lead_engine__theirstack_stelle__firma
    Speist hub_firma und sat_firma__theirstack aus stg_lead_engine__theirstack_stelle.
    dss_business_key bildet den Schluessel der Firma (nicht der Stelle).
    Dedupliziert je Firma und Lauf, damit der Satellit eine Zeile je Lauf bekommt.
    Version: 2026-10-25 V1.0 Initialversion
    Version: 2026-10-26 V1.1 als Tabelle materialisiert (siehe stg_lead_engine__theirstack_stelle)
#}
{{ config(
    materialized='table',
    as_columnstore=false,
    post_hook=["{{ create_hash_index('hk_firma') }}"]
) }}
SELECT
    hk_firma,
    collision_code,
    firma_bk,
    CONCAT_WS('||', 'default', 'theirstack',
              ISNULL(LTRIM(RTRIM(CAST(firma_bk AS NVARCHAR(MAX)))), '-1')) AS dss_business_key,
    hd_firma__theirstack,
    company_name,
    company_domain,
    employee_count,
    employee_count_range,
    industry,
    company_linkedin,
    is_recruiting_agency,
    dss_create_datetime,
    dss_load_date,
    dss_record_source
FROM (
    SELECT s.*,
           ROW_NUMBER() OVER (PARTITION BY hk_firma, run_id ORDER BY dss_load_date) AS rn
    FROM {{ ref('stg_lead_engine__theirstack_stelle') }} s
) x
WHERE rn = 1
