{#
    Monitoring-View: base_lead_engine__lauf_abfrage
    Quelle: landing.lead_engine_lauf (Laufprotokoll, schema lead-engine.run.v1)
    Grain: eine Zeile je Lauf und Abfrage. Kein Vault-Feed, daher ohne Hashes.
    Zweck: Vollstaendigkeit pruefen (items gegen total_reported, truncated, error).
    Version: 2026-10-25 V1.0 Initialversion
    Version: 2026-10-25 V1.1 profil_ids (Suchprofil, das die Stelle im Lauf gefunden hat)
#}
SELECT
    l.run_id,
    q.[source],
    q.query_id,
    ISNULL(q.profil_id, 'data-bi') AS profil_id,
    q.total_reported,
    TRY_CAST(q.total_reported AS INT) AS total_reported_int,
    q.[items],
    q.pages,
    q.truncated,
    q.error
FROM {{ source('lead_engine', 'lead_engine_lauf') }} l
CROSS APPLY OPENJSON(l.queries) WITH (
    [source]       NVARCHAR(50)  '$.source',
    query_id       NVARCHAR(200) '$.query_id',
    profil_id      NVARCHAR(50)  '$.profil_id',
    total_reported NVARCHAR(20)  '$.total_reported',
    [items]        INT           '$.items',
    pages          INT           '$.pages',
    truncated      BIT           '$.truncated',
    error          NVARCHAR(MAX) '$.error'
) q
