{#
    Mart: dim_firma
    Grain: 1 Zeile je Firma und Quelle (hub_firma) + Unbekannt-Zeile (-1). SCD1.
           Dieselbe Firma aus mehreren Quellen bleibt getrennt, bis ein Same-as-Link im Business Vault existiert.
           Firmen mit firma_bk '-1' (anonym/unbekannt) entfallen: Fakten verweisen dafuer auf -1.
    Quellen: hub_firma, sat_firma__karriere, sat_firma__theirstack, sat_firma__firmenprofil, sat_firma__adzuna (jeweils aktueller Stand)
#}
{{ config(materialized='table', as_columnstore=false, tags=['dimension']) }}

WITH basis AS (
    SELECT
        {{ surrogate_key("CONCAT_WS('||', h.collision_code, h.firma_bk)") }} AS firma_key,
        CAST(h.firma_bk AS NVARCHAR(255))                                    AS firma_id,
        CAST(CASE h.collision_code
                 WHEN 'karriere'   THEN k.company_slug
                 WHEN 'theirstack' THEN t.company_domain
             END AS NVARCHAR(255))                                           AS firma_code_quelle,
        CAST(COALESCE(k.company_name, t.company_name, fp.firma_name, ad.firma_name) AS NVARCHAR(255)) AS firma_name_quelle,
        h.collision_code                                                     AS quelle_code,
        {{ lead_engine_quelle_name('h.collision_code') }}                    AS quelle_name,
        CAST(COALESCE(k.company_size, t.employee_count_range) AS NVARCHAR(255)) AS groesse_klasse,
        CAST(t.employee_count AS INT)                                        AS mitarbeiter_anzahl,
        CAST(k.company_main_location AS NVARCHAR(255))                       AS hauptsitz,
        CAST(t.industry AS NVARCHAR(255))                                    AS branche,
        CAST(t.company_domain AS NVARCHAR(255))                              AS domain,
        CAST(fp.profil_url AS NVARCHAR(1000))                                AS profil_url,
        CAST(fp.website_url AS NVARCHAR(1000))                               AS website,
        CAST(t.is_recruiting_agency AS INT)                                  AS ist_vermittler,
        COALESCE(k.dss_load_date, t.dss_load_date, fp.dss_load_date, ad.dss_load_date, h.dss_load_date)          AS dss_load_date,
        COALESCE(k.dss_record_source, t.dss_record_source, fp.dss_record_source, ad.dss_record_source, h.dss_record_source) AS dss_record_source
    FROM {{ ref('hub_firma') }} h
    LEFT JOIN {{ ref('sat_firma__karriere') }} k
        ON k.hk_firma = h.hk_firma AND k.dss_is_current = 'Y'
    LEFT JOIN {{ ref('sat_firma__theirstack') }} t
        ON t.hk_firma = h.hk_firma AND t.dss_is_current = 'Y'
    LEFT JOIN {{ ref('sat_firma__firmenprofil') }} fp
        ON fp.hk_firma = h.hk_firma AND fp.dss_is_current = 'Y'
    LEFT JOIN {{ ref('sat_firma__adzuna') }} ad
        ON ad.hk_firma = h.hk_firma AND ad.dss_is_current = 'Y'
    WHERE h.firma_bk <> '-1'
)
SELECT
    firma_key,
    firma_id,
    ISNULL(firma_code_quelle, firma_id)                                      AS firma_code,
    ISNULL(firma_name_quelle, ISNULL(firma_code_quelle, N'UNKNOWN'))         AS firma_name,
    quelle_code,
    quelle_name,
    groesse_klasse,
    mitarbeiter_anzahl,
    hauptsitz,
    branche,
    domain,
    profil_url,
    website,
    ist_vermittler,
    dss_load_date,
    dss_record_source
FROM basis
UNION ALL
SELECT CAST(-1 AS BIGINT), N'-1', N'-1', N'Unbekannt', N'-1', N'Unbekannt',
       NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
       CAST('1900-01-01' AS DATETIME2), N'SYSTEM'
