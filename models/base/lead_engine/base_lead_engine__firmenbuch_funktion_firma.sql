{#
    Sicht: base_lead_engine__firmenbuch_funktion_firma
    Funktionen (base_lead_engine__firmenbuch_funktion) des jeweils juengsten Auszugs je FN, zugeordnet zu den Firmen der Lead-Engine ueber
    sichere Firmenbuch-Zuordnungen. Je Firma genau ein Stand (eine Gruppe mit einem Ladezeitpunkt), wie ihn ein Multi-Active-Satellit braucht.
    Quelle fuer das Staging von sat_firma__firmenbuch_funktion.
#}
{{ config(materialized='view', post_hook=["EXEC sp_refreshview '{{ this.schema }}.{{ this.identifier }}'"]) }}
select fu.run_id, fu.fetched_at, zf.firma_quelle, zf.firma_bk, fu.fn,
       fu.funktion_code, fu.funktion, fu.pnr, fu.titel, fu.titel_nach, fu.vorname, fu.nachname, fu.ist_person, fu.seit
from {{ ref('base_lead_engine__firmenbuch_funktion') }} fu
join (select fn, max(run_id) as run_id from {{ ref('base_lead_engine__firmenbuch_funktion') }} group by fn) l
  on l.fn = fu.fn and l.run_id = fu.run_id
join (select distinct firma_quelle, firma_bk, fn from {{ ref('base_lead_engine__firmenbuch_zuordnung') }}
      where qualitaet = 'sicher' and fn is not null) zf on zf.fn = fu.fn
