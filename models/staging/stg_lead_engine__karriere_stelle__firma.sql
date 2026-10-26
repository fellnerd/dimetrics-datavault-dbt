{#
    FK-Staging: stg_lead_engine__karriere_stelle__firma
    Speist hub_firma und sat_firma__karriere aus stg_lead_engine__karriere_stelle.
    dss_business_key bildet den Schluessel der Firma (nicht der Stelle).
    Dedupliziert je Firma und Lauf, damit der Satellit eine Zeile je Lauf bekommt.
    Version: 2026-10-25 V1.0 Initialversion
    Version: 2026-10-26 V1.1 als Tabelle materialisiert (siehe stg_lead_engine__karriere_stelle)
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
    CONCAT_WS('||', 'default', 'karriere',
              ISNULL(LTRIM(RTRIM(CAST(firma_bk AS NVARCHAR(MAX)))), '-1')) AS dss_business_key,
    hd_firma__karriere,
    company_name,
    company_slug,
    company_size,
    company_main_location,
    company_link,
    dss_create_datetime,
    dss_load_date,
    dss_record_source
FROM (
    SELECT s.*,
           ROW_NUMBER() OVER (PARTITION BY hk_firma, run_id ORDER BY dss_load_date) AS rn
    FROM {{ ref('stg_lead_engine__karriere_stelle') }} s
) x
WHERE rn = 1
