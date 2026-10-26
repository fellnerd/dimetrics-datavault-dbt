{#
    Mart: dim_stelle
    Grain: 1 Zeile je Stelle und Quelle (hub_stelle) + Unbekannt-Zeile (-1). SCD1 (aktueller Stand).
           Stern, kein Snowflake: die Firma steht nur als Attribut (firma_code/firma_name) in der Dimension,
           der firma_key gehoert in die Fakten.
    Quellen: hub_stelle, link_stelle_firma (juengste Zuordnung), hub_firma,
             sat_stelle__karriere, sat_stelle__theirstack, sat_stelle__website, sat_stelle__freelancer, sat_stelle__adzuna (jeweils aktueller Stand)
#}
{{ config(materialized='table', as_columnstore=false, tags=['dimension']) }}

WITH link_aktuell AS (
    SELECT hk_stelle, hk_firma
    FROM (
        SELECT l.hk_stelle, l.hk_firma,
               ROW_NUMBER() OVER (PARTITION BY l.hk_stelle ORDER BY l.dss_load_date DESC, l.hk_firma) AS rn
        FROM {{ ref('link_stelle_firma') }} l
    ) x
    WHERE rn = 1
),

firma_name AS (
    SELECT f.hk_firma, f.collision_code, f.firma_bk,
           COALESCE(k.company_name, t.company_name, fp.firma_name, ad.firma_name)    AS firma_name_quelle,
           CASE f.collision_code WHEN 'karriere' THEN k.company_slug
                                 WHEN 'theirstack' THEN t.company_domain END        AS firma_code_quelle
    FROM {{ ref('hub_firma') }} f
    LEFT JOIN {{ ref('sat_firma__karriere') }} k
        ON k.hk_firma = f.hk_firma AND k.dss_is_current = 'Y'
    LEFT JOIN {{ ref('sat_firma__theirstack') }} t
        ON t.hk_firma = f.hk_firma AND t.dss_is_current = 'Y'
    LEFT JOIN {{ ref('sat_firma__firmenprofil') }} fp
        ON fp.hk_firma = f.hk_firma AND fp.dss_is_current = 'Y'
    LEFT JOIN {{ ref('sat_firma__adzuna') }} ad
        ON ad.hk_firma = f.hk_firma AND ad.dss_is_current = 'Y'
),

basis AS (
    SELECT
        {{ surrogate_key("CONCAT_WS('||', h.collision_code, h.stelle_bk)") }} AS stelle_key,
        CAST(h.stelle_bk AS NVARCHAR(255))                                    AS stelle_id,
        CAST(COALESCE(k.title, t.title, w.title, fl.title, az.title) AS NVARCHAR(500))            AS stelle_name_quelle,
        h.collision_code                                                      AS quelle_code,
        {{ lead_engine_quelle_name('h.collision_code') }}                     AS quelle_name,
        CAST(COALESCE(k.link, t.url, w.url, fl.url, az.url) AS NVARCHAR(1000))                AS url,
        CAST(COALESCE(k.locations, t.location, fl.location, az.location_name) AS NVARCHAR(500))              AS ort,
        CAST(COALESCE(k.employment_types, az.contract_type) AS NVARCHAR(255))                             AS beschaeftigungsart,
        CAST(COALESCE(k.salary, fl.budget,
             CASE WHEN az.salary_min IS NOT NULL THEN CONCAT(CAST(CAST(az.salary_min AS INT) AS NVARCHAR(20)), ' - ', CAST(CAST(az.salary_max AS INT) AS NVARCHAR(20)), CASE WHEN az.salary_is_predicted = '1' THEN N' (geschaetzt)' ELSE N'' END) END) AS NVARCHAR(255))                  AS gehalt,
        CAST(t.seniority AS NVARCHAR(100))                                    AS seniority,
        CAST(COALESCE(k.is_home_office, t.is_remote) AS INT)                  AS ist_homeoffice,
        CAST(COALESCE(k.posted_date, t.date_posted, fl.veroeffentlicht_am, az.created_am) AS DATE)                  AS veroeffentlicht_am,
        CAST(t.closed_at AS DATE)                                             AS geschlossen_am,
        CASE WHEN k.hk_stelle IS NOT NULL THEN CAST(k.is_active AS INT)
             WHEN t.hk_stelle IS NOT NULL THEN CASE WHEN t.closed_at IS NULL THEN 1 ELSE 0 END
             WHEN fl.hk_stelle IS NOT NULL THEN CASE WHEN fl.status = 'Offen' THEN 1 ELSE 0 END
             ELSE 1 END                                                       AS ist_aktiv,
        CASE WHEN fn.firma_bk = '-1' THEN NULL
             ELSE ISNULL(fn.firma_code_quelle, CAST(fn.firma_bk AS NVARCHAR(255))) END AS firma_code,
        CASE WHEN fn.firma_bk = '-1' THEN NULL
             ELSE ISNULL(fn.firma_name_quelle, ISNULL(fn.firma_code_quelle, N'UNKNOWN')) END AS firma_name,
        COALESCE(k.dss_load_date, t.dss_load_date, w.dss_load_date, fl.dss_load_date, az.dss_load_date, h.dss_load_date) AS dss_load_date,
        COALESCE(k.dss_record_source, t.dss_record_source, w.dss_record_source, fl.dss_record_source, az.dss_record_source, h.dss_record_source) AS dss_record_source
    FROM {{ ref('hub_stelle') }} h
    LEFT JOIN {{ ref('sat_stelle__karriere') }} k
        ON k.hk_stelle = h.hk_stelle AND k.dss_is_current = 'Y'
    LEFT JOIN {{ ref('sat_stelle__theirstack') }} t
        ON t.hk_stelle = h.hk_stelle AND t.dss_is_current = 'Y'
    LEFT JOIN {{ ref('sat_stelle__website') }} w
        ON w.hk_stelle = h.hk_stelle AND w.dss_is_current = 'Y'
    LEFT JOIN {{ ref('sat_stelle__freelancer') }} fl
        ON fl.hk_stelle = h.hk_stelle AND fl.dss_is_current = 'Y'
    LEFT JOIN {{ ref('sat_stelle__adzuna') }} az
        ON az.hk_stelle = h.hk_stelle AND az.dss_is_current = 'Y'
    LEFT JOIN link_aktuell la ON la.hk_stelle = h.hk_stelle
    LEFT JOIN firma_name fn ON fn.hk_firma = la.hk_firma
)
SELECT
    stelle_key,
    stelle_id,
    stelle_id                                                                 AS stelle_code,
    ISNULL(stelle_name_quelle, N'UNKNOWN')                                    AS stelle_name,
    quelle_code,
    quelle_name,
    firma_code,
    firma_name,
    url,
    ort,
    beschaeftigungsart,
    gehalt,
    seniority,
    ist_homeoffice,
    veroeffentlicht_am,
    geschlossen_am,
    ist_aktiv,
    dss_load_date,
    dss_record_source
FROM basis
UNION ALL
SELECT CAST(-1 AS BIGINT), N'-1', N'-1', N'Unbekannt', N'-1', N'Unbekannt', NULL, NULL,
       NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
       CAST('1900-01-01' AS DATETIME2), N'SYSTEM'
