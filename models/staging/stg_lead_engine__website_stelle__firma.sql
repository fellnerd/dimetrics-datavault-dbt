{#
    FK-Staging: stg_lead_engine__website_stelle__firma
    Speist hub_firma aus stg_lead_engine__website_stelle (kein Firmen-Satellit fuer website).
    dss_business_key bildet den Schluessel der Firma (nicht der Stelle).
    Version: 2026-10-25 V1.0 Initialversion
    Version: 2026-10-26 V1.1 als Tabelle materialisiert (siehe stg_lead_engine__website_stelle)
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
    CONCAT_WS('||', 'default', 'website',
              ISNULL(LTRIM(RTRIM(CAST(firma_bk AS NVARCHAR(MAX)))), '-1')) AS dss_business_key,
    dss_create_datetime,
    dss_load_date,
    dss_record_source
FROM {{ ref('stg_lead_engine__website_stelle') }}
