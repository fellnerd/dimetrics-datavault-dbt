{#
    Business Vault (virtuell): bv_stelle_neu
    Zweck: neue Leads. Stellen, die im juengsten Lauf ihrer Quelle erstmals aufgetaucht sind.
    Grain: 1 Zeile je Stelle und Quelle (hub_stelle).
    Regel: erster Lauf der Stelle (kleinste run_id) = juengster Lauf der Quelle (groesste run_id).
           run_id ist ein UTC-Zeitstempel (JJJJMMTTTHHMMSSZ) und damit chronologisch sortierbar.
    Quellen: hub_stelle, sat_stelle_sichtung__*, sat_stelle__* (aktueller Stand),
             link_stelle_firma (juengste Zuordnung), hub_firma, sat_firma__* (aktueller Stand)
#}
{{ config(materialized='view', tags=['business_vault']) }}

WITH sichtung AS (
    SELECT hk_stelle, run_id, query_ids, dss_load_date FROM {{ ref('sat_stelle_sichtung__karriere') }}
    UNION ALL
    SELECT hk_stelle, run_id, query_ids, dss_load_date FROM {{ ref('sat_stelle_sichtung__theirstack') }}
    UNION ALL
    SELECT hk_stelle, run_id, query_ids, dss_load_date FROM {{ ref('sat_stelle_sichtung__website') }}
    UNION ALL
    SELECT hk_stelle, run_id, query_ids, dss_load_date FROM {{ ref('sat_stelle_sichtung__freelancer') }}
    UNION ALL
    SELECT hk_stelle, run_id, query_ids, dss_load_date
    FROM {{ ref('sat_stelle_sichtung__adzuna') }}
),

erster_lauf AS (
    SELECT hk_stelle, MIN(run_id) AS run_id, MIN(dss_load_date) AS erstmals_gesehen
    FROM sichtung
    GROUP BY hk_stelle
),

letzter_lauf_quelle AS (
    SELECT h.collision_code, MAX(s.run_id) AS run_id
    FROM sichtung s
    JOIN {{ ref('hub_stelle') }} h ON h.hk_stelle = s.hk_stelle
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
    h.hk_stelle,
    h.collision_code                                                  AS quelle,
    h.stelle_bk,
    COALESCE(k.title, t.title, w.title, fl.title, az.title)                               AS titel,
    CASE WHEN f.firma_bk = '-1' THEN NULL
         ELSE COALESCE(fk.company_name, ft.company_name, ffp.firma_name, fad.firma_name, f.firma_bk) END AS firma,
    COALESCE(k.locations, t.location, fl.location, az.location_name)                                 AS ort,
    COALESCE(k.link, t.url, w.url, fl.url, az.url)                                    AS url,
    COALESCE(k.salary, fl.budget,
             CASE WHEN az.salary_min IS NOT NULL THEN CONCAT(CAST(CAST(az.salary_min AS INT) AS NVARCHAR(20)), ' - ', CAST(CAST(az.salary_max AS INT) AS NVARCHAR(20))) END)                                     AS gehalt,
    t.seniority                                                       AS seniority,
    COALESCE(k.posted_date, t.date_posted, fl.veroeffentlicht_am, az.created_am)                            AS veroeffentlicht_am,
    e.erstmals_gesehen,
    e.run_id,
    sc.query_ids,
    e.erstmals_gesehen                                                AS dss_load_date,
    h.dss_record_source
FROM erster_lauf e
JOIN {{ ref('hub_stelle') }} h ON h.hk_stelle = e.hk_stelle
JOIN letzter_lauf_quelle l ON l.collision_code = h.collision_code AND l.run_id = e.run_id
LEFT JOIN sichtung sc ON sc.hk_stelle = e.hk_stelle AND sc.run_id = e.run_id
LEFT JOIN {{ ref('sat_stelle__karriere') }} k ON k.hk_stelle = h.hk_stelle AND k.dss_is_current = 'Y'
LEFT JOIN {{ ref('sat_stelle__theirstack') }} t ON t.hk_stelle = h.hk_stelle AND t.dss_is_current = 'Y'
LEFT JOIN {{ ref('sat_stelle__website') }} w ON w.hk_stelle = h.hk_stelle AND w.dss_is_current = 'Y'
LEFT JOIN {{ ref('sat_stelle__freelancer') }} fl ON fl.hk_stelle = h.hk_stelle AND fl.dss_is_current = 'Y'
LEFT JOIN {{ ref('sat_stelle__adzuna') }} az ON az.hk_stelle = h.hk_stelle AND az.dss_is_current = 'Y'
LEFT JOIN link_aktuell la ON la.hk_stelle = h.hk_stelle
LEFT JOIN {{ ref('hub_firma') }} f ON f.hk_firma = la.hk_firma
LEFT JOIN {{ ref('sat_firma__karriere') }} fk ON fk.hk_firma = f.hk_firma AND fk.dss_is_current = 'Y'
LEFT JOIN {{ ref('sat_firma__theirstack') }} ft ON ft.hk_firma = f.hk_firma AND ft.dss_is_current = 'Y'
LEFT JOIN {{ ref('sat_firma__firmenprofil') }} ffp ON ffp.hk_firma = f.hk_firma AND ffp.dss_is_current = 'Y'
LEFT JOIN {{ ref('sat_firma__adzuna') }} fad ON fad.hk_firma = f.hk_firma AND fad.dss_is_current = 'Y'
