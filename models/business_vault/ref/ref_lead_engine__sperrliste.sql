{#
    Referenz: ref_lead_engine__sperrliste
    Sperrliste aus der Landing-Quelle sperrliste (eintraege[], juengste Datei): Firmen, die nie als Lead erscheinen sollen.
    Abgleich ueber Firmenbuchnummer, Domain oder normalisierten Namen (bv_firma_sperre). Abgelaufene Eintraege (gueltig_bis) entfallen,
    die Beispielzeile ("Zeile loeschen") wird ignoriert.
    Version: 2026-11-02 V1.0 Initialversion
#}
{{ config(materialized='table', as_columnstore=false, tags=['business_vault']) }}

with neueste as (
    select top 1 payload
    from {{ source('lead_engine', 'lead_engine_datei') }}
    where source = 'sperrliste'
    order by fetched_at desc, run_id desc
)
select
    e.firma,
    {{ lead_engine_name_norm('e.firma') }}                                                  as firma_norm,
    {{ lead_engine_domain('e.domain') }}                                                    as domain,
    nullif(lower(replace(replace(replace(e.firmenbuchnummer, ' ', ''), '-', ''), 'fn', '')), '') as fn,
    e.grund, try_cast(e.gueltig_bis as date) as gueltig_bis, e.bemerkung
from neueste n
cross apply openjson(n.payload, '$.eintraege') with (
    firma            nvarchar(500)  '$.firma',
    domain           nvarchar(500)  '$.domain',
    firmenbuchnummer nvarchar(50)   '$.firmenbuchnummer',
    grund            nvarchar(500)  '$.grund',
    gueltig_bis      nvarchar(30)   '$.gueltig_bis',
    bemerkung        nvarchar(1000) '$.bemerkung'
) e
where coalesce(e.firma, e.domain, e.firmenbuchnummer) is not null
  and lower(coalesce(e.firma, '')) not like '%zeile löschen%'
  and (try_cast(e.gueltig_bis as date) is null or try_cast(e.gueltig_bis as date) >= cast(getdate() as date))
