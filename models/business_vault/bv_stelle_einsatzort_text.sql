{#
    Business Vault: bv_stelle_einsatzort_text
    Hilfstabelle fuer bv_stelle_merkmale: der Text hinter "Einsatzort:" in der Beschreibung eines freelancer.at-Auftrags (ab dort 100 Zeichen, bis zum
    ersten Doppelpunkt = naechstes Etikett), klein, Satzzeichen zu Leerzeichen, Leerzeichen an beiden Enden.
    Eigene Tabelle, damit der lange Beschreibungstext nicht fuer jedes Paar Auftrag x Ortsname neu verarbeitet wird (Abgleich gegen 13.000 Ortsnamen).
    Grain: 1 Zeile je hk_stelle mit "Einsatzort:" im Text (aktueller Stand).
    Version: 2026-11-04 V1.0 Initialversion
#}
{{ config(materialized='table', as_columnstore=false, tags=['business_vault']) }}

select y.hk_stelle,
       cast(' ' + replace(replace(translate(case when charindex(':', y.seg0) > 0 then left(y.seg0, charindex(':', y.seg0) - 1) else y.seg0 end,
                                            '(),.;/-|+&!?"', '             '), '  ', ' '), '  ', ' ') + ' ' as nvarchar(200)) as seg
from (select fl.hk_stelle,
             cast(substring(lower(replace(replace(fl.beschreibung, char(10), ' '), char(13), ' ')),
                            charindex('einsatzort:', lower(fl.beschreibung)) + 11, 100) as nvarchar(200)) as seg0
      from {{ ref('sat_stelle__freelancer') }} fl
      where fl.dss_is_current = 'Y' and fl.beschreibung like '%einsatzort:%') y
