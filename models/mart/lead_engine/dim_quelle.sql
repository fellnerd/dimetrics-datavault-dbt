{#
    Mart: dim_quelle
    Grain: 1 Zeile je Lead-Engine-Quelle (karriere, theirstack, website) + Unbekannt-Zeile (-1). SCD1.
    Quellen: hub_stelle (collision_code)
#}
{{ config(materialized='table', as_columnstore=false, tags=['dimension']) }}

WITH basis AS (
    SELECT
        h.collision_code,
        MIN(h.dss_load_date)                  AS dss_load_date
    FROM {{ ref('hub_stelle') }} h
    GROUP BY h.collision_code
)
SELECT
    {{ surrogate_key('b.collision_code') }}                       AS quelle_key,
    CAST(b.collision_code AS NVARCHAR(255))                       AS quelle_id,
    CAST(b.collision_code AS NVARCHAR(255))                       AS quelle_code,
    ISNULL({{ lead_engine_quelle_name('b.collision_code') }}, N'UNKNOWN') AS quelle_name,
    b.dss_load_date,
    CAST(N'lead-engine' AS NVARCHAR(50))                          AS dss_record_source
FROM basis b
UNION ALL
SELECT CAST(-1 AS BIGINT), N'-1', N'-1', N'Unbekannt', CAST('1900-01-01' AS DATETIME2), N'SYSTEM'
