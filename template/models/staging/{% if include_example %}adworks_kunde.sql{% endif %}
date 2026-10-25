/*
 * Staging Model: adworks_kunde
 *
 * Source: ext_adventureworks_saleslt_customer
 * Business Key: CUSTOMERID
 * Hash Key Separator: '^^' (manuelles Hashing-Muster dieses Beispiels — Neuentwicklungen nutzen automate_dv.stage(), siehe docs/entwickler/)
 *
 * Hash Keys calculated here (automate_dv pattern):
 *   - hk_kunde (Entity Hash Key)
 */

{%- set hashdiff_columns = [
    'companyname',
    'emailaddress',
    'firstname',
    'lastname',
    'middlename',
    'namestyle',
    'passwordhash',
    'passwordsalt',
    'phone',
    'salesperson',
    'suffix',
    'title'
] -%}

WITH source AS (
    SELECT * FROM {{ source('staging', 'ext_adventureworks_saleslt_customer') }}
),

staged AS (
    SELECT
        -- ===========================================
        -- HASH KEY (Entity)
        -- ===========================================
        CONVERT(CHAR(64), HASHBYTES('SHA2_256', 
            ISNULL(CAST(CUSTOMERID AS NVARCHAR(MAX)), '')
        ), 2) AS hk_kunde,

        -- ===========================================
        -- HASH DIFF (Change Detection - Satellite)
        -- ===========================================
        CONVERT(CHAR(64), HASHBYTES('SHA2_256', 
            CONCAT(
                {%- for col in hashdiff_columns %}
                ISNULL(CAST({{ col }} AS NVARCHAR(MAX)), ''){{ ',' if not loop.last else '' }}
                {%- endfor %}
                {%- if hashdiff_columns | length == 1 %}, ''{%- endif %}
            )
        ), 2) AS hd_kunde__adworks,

        -- ===========================================
        -- BUSINESS KEY(S)
        -- ===========================================
        CUSTOMERID,

        -- ===========================================
        -- PAYLOAD
        -- ===========================================
        namestyle,
        title,
        firstname,
        middlename,
        lastname,
        suffix,
        companyname,
        salesperson,
        emailaddress,
        phone,
        passwordhash,
        passwordsalt,
        modifieddate,

        -- ===========================================
        -- METADATA
        -- ===========================================
        -- Klartext-Business-Key des Primaer-Hubs (hub_kunde): '<mandant>||<collision>||<BK>'.
        -- Dieselbe BK-Spalte wie im Hash-Key hk_kunde.
        CONCAT_WS('||', 'default', 'default', ISNULL(LTRIM(RTRIM(CAST(CUSTOMERID AS NVARCHAR(MAX)))), '-1')) AS dss_business_key,
        CAST(GETDATE() AS DATETIME2) AS dss_create_datetime,
        COALESCE(dss_record_source, 'adworks') AS dss_record_source,
        COALESCE(TRY_CAST(dss_load_date AS DATETIME2), GETDATE()) AS dss_load_date,
        dss_run_id

    FROM source
)

SELECT * FROM staged