{#
    FK-Staging: stg_lead_engine__website_stelle__firma
    Speist hub_firma und sat_firma__website aus stg_lead_engine__website_stelle.
    Die Firma kommt aus karriere_company_id / theirstack_company_id (Kollisionscode karriere bzw. theirstack,
    gleicher hk_firma wie in den Quellen karriere/theirstack), sonst aus der Domain (website).
    dss_business_key bildet den Schluessel der Firma (nicht der Stelle). firma_name = Name aus payload.company.name.
    Dedupliziert je Firma und Lauf, damit der Satellit eine Zeile je Lauf bekommt.
    Version: 2026-10-25 V1.0 Initialversion
    Version: 2026-10-26 V1.1 als Tabelle materialisiert (siehe stg_lead_engine__website_stelle)
    Version: 2026-10-26 V1.2 Kollisionscode der Firma = firma_quelle
    Version: 2026-11-02 V1.3 firma_name und hd_firma__website fuer sat_firma__website, Deduplizierung je Firma und Lauf
#}
{{ config(
    materialized='table',
    as_columnstore=false,
    post_hook=["{{ create_hash_index('hk_firma') }}"]
) }}
SELECT
    hk_firma,
    firma_quelle                                                     AS collision_code,
    firma_bk,
    CONCAT_WS('||', 'default', firma_quelle,
              ISNULL(LTRIM(RTRIM(CAST(firma_bk AS NVARCHAR(MAX)))), '-1')) AS dss_business_key,
    hd_firma__website,
    company_name                                                     AS firma_name,
    dss_create_datetime,
    dss_load_date,
    dss_record_source
FROM (
    SELECT s.*,
           ROW_NUMBER() OVER (PARTITION BY hk_firma, run_id ORDER BY dss_load_date) AS rn
    FROM {{ ref('stg_lead_engine__website_stelle') }} s
) x
WHERE rn = 1
