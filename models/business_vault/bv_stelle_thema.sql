{#
    Business Vault (virtuell): bv_stelle_thema
    Grain: je Stelle x Thema x Begriff mit Treffer. fundort 'titel' (Treffer im Titel, hat Vorrang) oder 'text'.
    Treffer-Regeln (wie im Collector, relevanz.py): gross/klein egal; Leerzeichen und Bindestrich gleichwertig; Begriffe ab 6 Zeichen
    auch als Teil eines Kompositums (keine linke Wortgrenze, z. B. "Finanzcontroller"), kuerzere nur als eigenes Wort; deutsche
    Endungen (in, innen, en, n, s, e, er, ern) erlaubt. Begriffe mit nur_titel und das Thema 'Negativ' zaehlen nur im Titel.
    Begriffe und Gewichte kommen aus ref_lead_engine__thema (Landing-Quelle suchprofil, juengster Stand), nur aktive Begriffe.
    Titel und Text kommen normalisiert aus bv_stelle_text (einmalig berechnet, Text auf 4.000 Zeichen gekuerzt wie im Mart).
    Materialisierung: Tabelle (Textsuche ueber alle Stellen x Begriffe, binaerer Vergleich Latin1_General_BIN2 auf kleingeschriebenen Texten).
    Version: 2026-10-26 V1.0 Erste Fassung
#}
{{ config(materialized='table', as_columnstore=false, tags=['business_vault']) }}

with s as (
    select hk_stelle, titel_n, text_n from {{ ref('bv_stelle_text') }}
),

t as (
    select cast(replace(begriff, '-', ' ') as nvarchar(200)) collate Latin1_General_BIN2 as begriff, thema, gewicht,
           case when nur_titel = 1 or thema = 'Negativ' then 1 else 0 end as nur_titel,
           len(replace(begriff, '-', ' ')) as laenge
    from {{ ref('ref_lead_engine__thema') }}
    where aktiv = 1
),

endung as (
    select cast(e as nvarchar(10)) collate Latin1_General_BIN2 as e from (values (''), ('in'), ('innen'), ('en'), ('n'), ('s'), ('e'), ('er'), ('ern')) v(e)
),

kandidat as (   -- grober Vorfilter: Begriff kommt irgendwo vor
    select s.hk_stelle, t.begriff, t.thema, t.gewicht, t.nur_titel, t.laenge, s.titel_n, s.text_n,
           case when charindex(t.begriff, s.titel_n) > 0 then 1 else 0 end as im_titel,
           case when t.nur_titel = 0 and charindex(t.begriff, s.text_n) > 0 then 1 else 0 end as im_text
    from s cross join t
    where charindex(t.begriff, s.titel_n) > 0
       or (t.nur_titel = 0 and charindex(t.begriff, s.text_n) > 0)
)

select k.hk_stelle, k.thema, cast(k.begriff as nvarchar(200)) collate database_default as begriff, k.gewicht,
       case when exists (select 1 from endung en
                          where k.im_titel = 1
                            and charindex(case when k.laenge >= 6 then '' else ' ' end + k.begriff + en.e + ' ', k.titel_n) > 0) then 'titel'
            else 'text' end as fundort
from kandidat k
where exists (select 1 from endung en
               where (k.im_titel = 1
                      and charindex(case when k.laenge >= 6 then '' else ' ' end + k.begriff + en.e + ' ', k.titel_n) > 0)
                  or (k.im_text = 1
                      and charindex(case when k.laenge >= 6 then '' else ' ' end + k.begriff + en.e + ' ', k.text_n) > 0))
