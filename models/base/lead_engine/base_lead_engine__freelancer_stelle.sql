{#
    Base-View: base_lead_engine__freelancer_stelle
    Fuehrt Liste und Detail zusammen: eine Zeile je Lauf (run_id) und Auftrags-ID aus base_lead_engine__freelancer_liste,
    ergaenzt um die juengste Detaildatei dieses Auftrags bis einschliesslich dieses Laufs
    (Detail fehlt im Lauf -> aelteres Detail; noch gar keins -> nur Listendaten).
    BK Stelle: stelle_bk (Auftrags-ID) · BK Firma: firma_bk = '-1' (Auftraggeber unbekannt, meist Vermittler)
    Version: 2026-10-26 V1.0 Initialversion
    Version: 2026-10-26 V1.1 profil_ids aus Liste und Detail vereinigt, Vorgabe 'ohne-treffer'
#}
{{ config(materialized='view') }}

select
    l.run_id,
    l.fetched_at,
    l.auftrags_id                                           as stelle_bk,
    '-1'                                                    as firma_bk,
    coalesce(a.titel, l.titel)                              as title,
    coalesce(a.url, l.url)                                  as url,
    coalesce(a.beschreibung, l.beschreibung_kurz)           as beschreibung,
    a.kategorie_pfad                                        as kategorie,
    coalesce(a.budget, l.budget)                            as budget,
    coalesce(a.ort, l.ort)                                  as location,
    coalesce(a.status, l.status)                            as status,
    coalesce(a.veroeffentlicht_am, l.platziert_am)          as veroeffentlicht_am,
    l.zuletzt_geaendert_am,
    l.antworten,
    a.anzahl_reaktionen,
    case when a.run_id = l.run_id then 'details,liste' else l.query_ids end as query_ids,
    -- Profile aus Liste und Detail desselben Laufs vereinigt. Die Listenseiten durchsuchen nur den gekuerzten Text,
    -- die Detailseiten den vollen. Ohne Treffer: 'ohne-treffer' (kein data-bi: das gilt nur fuer Altdaten der anderen Quellen).
    coalesce((select string_agg(x.p, ',') within group (order by x.p)
                from (select distinct ltrim(rtrim(sp.[value])) as p
                        from string_split(concat_ws(',', l.profil_ids, case when a.run_id = l.run_id then a.profil_ids end), ',') sp
                       where ltrim(rtrim(sp.[value])) <> '') x),
             'ohne-treffer')                                as profil_ids
from {{ ref('base_lead_engine__freelancer_liste') }} l
outer apply (
    select top 1 d.*
    from {{ ref('base_lead_engine__freelancer_auftrag') }} d
    where d.auftrags_id = l.auftrags_id and d.run_id <= l.run_id
    order by d.run_id desc
) a
