{#
    Mart: fakt_stelle
    Grain: 1 Zeile je Stelle und Quelle (Lebenszyklus der Anzeige aus den Sichtungen).
    Quellen: sat_stelle_sichtung__{karriere,theirstack,website,freelancer}, hub_stelle,
             link_stelle_firma (juengste Zuordnung), hub_firma
    datum_key = Datum der ersten Sichtung; zuletzt_gesehen_datum_key = Datum der letzten Sichtung.
    ist_online = 1, wenn die Stelle im juengsten Lauf ihrer Quelle noch gefunden wurde.
#}
{{ config(materialized='table', as_columnstore=false, tags=['fact']) }}

WITH sichtung AS (
    SELECT hk_stelle, run_id, dss_load_date
    FROM {{ ref('sat_stelle_sichtung__karriere') }}
    UNION ALL
    SELECT hk_stelle, run_id, dss_load_date
    FROM {{ ref('sat_stelle_sichtung__theirstack') }}
    UNION ALL
    SELECT hk_stelle, run_id, dss_load_date
    FROM {{ ref('sat_stelle_sichtung__website') }}
    UNION ALL
    SELECT hk_stelle, run_id, dss_load_date
    FROM {{ ref('sat_stelle_sichtung__freelancer') }}
),

je_stelle AS (
    SELECT
        hk_stelle,
        COUNT(DISTINCT run_id)   AS anzahl_laeufe,
        MIN(dss_load_date)       AS erstmals_gesehen,
        MAX(dss_load_date)       AS zuletzt_gesehen,
        MAX(run_id)              AS letzter_run_id
    FROM sichtung
    GROUP BY hk_stelle
),

letzter_run_je_quelle AS (
    SELECT h.collision_code, MAX(j.letzter_run_id) AS letzter_run_id
    FROM je_stelle j
    JOIN {{ ref('hub_stelle') }} h ON h.hk_stelle = j.hk_stelle
    GROUP BY h.collision_code
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
    CONVERT(INT, FORMAT(CAST(j.erstmals_gesehen AS DATE), 'yyyyMMdd'))           AS datum_key,
    CONVERT(INT, FORMAT(CAST(j.zuletzt_gesehen AS DATE), 'yyyyMMdd'))            AS zuletzt_gesehen_datum_key,
    CAST(j.anzahl_laeufe AS INT)                                                 AS anzahl_laeufe,
    CAST(DATEDIFF(DAY, j.erstmals_gesehen, j.zuletzt_gesehen) + 1 AS INT)        AS tage_sichtbar,
    CAST(CASE WHEN j.letzter_run_id = r.letzter_run_id THEN 1 ELSE 0 END AS INT) AS ist_online,
    j.letzter_run_id,
    j.zuletzt_gesehen                                                            AS dss_load_date,
    h.dss_record_source
FROM je_stelle j
JOIN {{ ref('hub_stelle') }} h ON h.hk_stelle = j.hk_stelle
JOIN letzter_run_je_quelle r ON r.collision_code = h.collision_code
LEFT JOIN link_aktuell la ON la.hk_stelle = j.hk_stelle
LEFT JOIN {{ ref('hub_firma') }} f ON f.hk_firma = la.hk_firma
