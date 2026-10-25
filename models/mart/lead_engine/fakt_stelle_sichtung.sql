{#
    Mart: fakt_stelle_sichtung
    Grain: 1 Zeile je Stelle, Lauf und Suchprofil (Sichtung). Findet ein Lauf dieselbe Anzeige ueber zwei
           Suchprofile, entstehen zwei Zeilen -> anzahl_sichtungen nur je profil_id summieren
           (profilübergreifend: DISTINCTCOUNT ueber stelle_key/run_id).
    profil_id: degenerierte Dimension (Suchprofil aus der Tabelle, z. B. data-bi, online-marketing);
               Sichtungen vor Einfuehrung der Suchprofile (25.10.2026) = data-bi.
    Quellen: sat_stelle_sichtung__{karriere,theirstack,website}, hub_stelle,
             link_stelle_firma (juengste Zuordnung), hub_firma
    Keys: gleiche surrogate_key()-Ausdruecke wie dim_stelle, dim_firma, dim_quelle; datum_key = Abrufdatum der Sichtung
#}
{{ config(materialized='table', as_columnstore=false, tags=['fact']) }}

WITH sichtung AS (
    SELECT hk_stelle, run_id, query_ids, profil_ids, dss_load_date, dss_record_source
    FROM {{ ref('sat_stelle_sichtung__karriere') }}
    UNION ALL
    SELECT hk_stelle, run_id, query_ids, profil_ids, dss_load_date, dss_record_source
    FROM {{ ref('sat_stelle_sichtung__theirstack') }}
    UNION ALL
    SELECT hk_stelle, run_id, query_ids, profil_ids, dss_load_date, dss_record_source
    FROM {{ ref('sat_stelle_sichtung__website') }}
),

link_aktuell AS (
    SELECT hk_stelle, hk_firma
    FROM (
        SELECT l.hk_stelle, l.hk_firma,
               ROW_NUMBER() OVER (PARTITION BY l.hk_stelle ORDER BY l.dss_load_date DESC, l.hk_firma) AS rn
        FROM {{ ref('link_stelle_firma') }} l
    ) x
    WHERE rn = 1
)

SELECT
    {{ surrogate_key("CONCAT_WS('||', h.collision_code, h.stelle_bk)") }}        AS stelle_key,
    CASE WHEN f.hk_firma IS NULL OR f.firma_bk = '-1' THEN CAST(-1 AS BIGINT)
         ELSE {{ surrogate_key("CONCAT_WS('||', f.collision_code, f.firma_bk)") }} END AS firma_key,
    {{ surrogate_key('h.collision_code') }}                                      AS quelle_key,
    CONVERT(INT, FORMAT(CAST(s.dss_load_date AS DATE), 'yyyyMMdd'))              AS datum_key,
    CAST(LTRIM(RTRIM(pr.[value])) AS NVARCHAR(50))                              AS profil_id,
    s.run_id,
    s.query_ids,
    CAST(1 AS INT)                                                               AS anzahl_sichtungen,
    CAST(CASE WHEN s.query_ids IS NULL OR s.query_ids = '' THEN 0
              ELSE LEN(s.query_ids) - LEN(REPLACE(s.query_ids, ',', '')) + 1 END AS INT) AS anzahl_abfragen,
    s.dss_load_date,
    s.dss_record_source
FROM sichtung s
CROSS APPLY STRING_SPLIT(ISNULL(NULLIF(s.profil_ids, ''), 'data-bi'), ',') pr
JOIN {{ ref('hub_stelle') }} h ON h.hk_stelle = s.hk_stelle
LEFT JOIN link_aktuell la ON la.hk_stelle = s.hk_stelle
LEFT JOIN {{ ref('hub_firma') }} f ON f.hk_firma = la.hk_firma
