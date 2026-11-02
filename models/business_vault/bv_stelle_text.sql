{#
    Business Vault: bv_stelle_text
    Hilfstabelle fuer bv_stelle_thema: Titel und Text je Stelle einmalig normalisiert (klein, Satzzeichen/Bindestriche zu Leerzeichen,
    Mehrfach-Leerzeichen zusammengefasst, Leerzeichen an beiden Enden). Der Text wird auf die ersten 4.000 Zeichen gekuerzt (wie im Mart).
    Eigene Tabelle, weil SQL Server eine CTE mit der teuren Normalisierung je Begriff neu berechnet (106 Begriffe x 1.800 Stellen).
    Binaere Sortierung (Latin1_General_BIN2) fuer schnelle Zeichenketten-Suche auf den kleingeschriebenen Texten.
    Grain: 1 Zeile je hk_stelle.
    Version: 2026-10-26 V1.0 Initialversion
#}
{{ config(materialized='table', as_columnstore=false, tags=['business_vault']) }}

select hk_stelle,
       cast({{ lead_engine_text_norm('titel') }} as nvarchar(max)) collate Latin1_General_BIN2 as titel_n,
       cast({{ lead_engine_text_norm('left(text, 4000)') }} as nvarchar(max)) collate Latin1_General_BIN2 as text_n
from {{ ref('bv_stelle_merkmale') }}
