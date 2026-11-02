# Auftrag: Lead-Engine Bewertung v2 (dbt-Teil)

Stand 26.10.2026 · Quelle: Plan-Dokument „Lead-Engine: Bewertung v2 – Plan“ (Teil 2 + Bewertungsmodell)

Ziel ist eine Mart-View `lead_gelegenheiten_v`: eine Zeile je Gelegenheit (Auftrag oder Stelle) mit Lead-Typ, Vorscore und dessen Bausteinen, Text, Region und Status. Dazu `lead_firmen_v` als Nachfolger von `lead_kandidaten_v`. Claude liest danach über den MCP-Server die besten ~40 Gelegenheiten im Volltext und erstellt die Tagesliste.

## Kontext und Regeln

- **Repo** `dimetrics-datavault-dbt`, Quelle `lead_engine` (Tabelle `landing.lead_engine_datei`, eine Zeile je Landing-Datei, `source` = Quelle, `payload` = JSON). Bestand: `base_lead_engine__*`, `stg_lead_engine__*`, `hub_stelle`, `hub_firma`, `link_stelle_firma`, Satelliten `sat_stelle__<quelle>`, `sat_stelle_sichtung__<quelle>`, `sat_firma__<quelle>`. Mart im Schema `mart_lead_engine` mit `_v`-Views.
- **Projektregeln:** Neue Vault-Objekte vor dem Anlegen mit Daniel abstimmen. Kein `--full-refresh` auf historisierten Satelliten. Datenbank-Tools nur lesend.
- **Keine bestehenden Satelliten erweitern.** Neue Attribute in neue Satelliten (`sat_stelle__<quelle>_detail`), damit sich der Hashdiff der bestehenden nicht ändert.
- **Konfiguration nicht hart codieren.** Begriffe und Gewichte kommen aus der Landing-Quelle `suchprofil` (Blätter Themen, Gewichte, Lead-Status der Google-Tabelle), immer der jüngste Stand.

## Landing-Felder ab Collector 0.4.0 (live seit 26.10.)

Details: `collector/LANDING.md` im Repo `lead-engine`.

| Quelle (`source`) | Wo | Felder |
| --- | --- | --- |
| `suchprofil` | `payload` | `themen[]` (begriff, thema, gewicht, nur_titel, aktiv), `gewichte[]` (bereich, schluessel, punkte, bemerkung), `lead_status[]` (gelegenheit_id, firma, status, grund, datum), `profile[]` |
| `karriere` | `query_id = projektarbeit__oesterreich` | alle Projektarbeit-Anzeigen in Österreich, `profil_id` null. Suchliste liefert außerdem `summary`, `date` (TT.MM.JJJJ), `isHomeOffice`, `employmentTypes`, `salary` |
| `karriere_detail` | `payload`, Datei `stelle__<id>` | id (= karriere-Job-ID), titel, beschreibung, date_posted, valid_through, employment_type, `orte[]` (postalCode, addressLocality, addressRegion, addressCountry), base_salary, firma, relevanz |
| `freelancer` | `payload.items[].norm` (Liste) bzw. `payload.norm` (Detail) | veroeffentlicht_am, zuletzt_geaendert_am (ISO), reaktionen, status, ist_remote, ort, land, budget_min, budget_max, budget_einheit (stunde/pauschal), relevanz |
| `theirstack` | `query_id = <profil>__projekte` | Projekt-, befristete und Teilzeit-Stellen inkl. Personalvermittler (Typ A2). Jobs haben `description`, `state_code`, `latitude`, `longitude`, `reposted`, `employment_statuses`; `company_object` hat `city`, `postal_code`, `country_code`, `technology_names`, `employee_count`, `is_recruiting_agency` |
| `website` | `payload.jobs[]` | zusätzlich `profile[]` (leer = ohne Treffer; ersetzt das Profil der Firma), `relevanz`, `detail` (quelle, beschreibung, date_posted, valid_through, employment_type, plz, ort, region) |
| `website` | `payload` | `impressum` (fn, uid, plz, ort, firmenname, konzern_hinweis), `fremde_jobdomain`. Firmen „UNKNOWN“ (z. B. pewag.com, treibacher.com): Name aus `company.name` bzw. `impressum.firmenname` übernehmen |
| `ted` | `payload.notices[]` | publication-number, notice-title, notice-type, buyer-name, buyer-city, publication-date, deadline-receipt-tender-date-lot, description-lot, place-of-performance, classification-cpv, links |
| `referenz_ort` | `payload.zeilen[]` | plz, ortschaft, gemeinde, gemeinde_kz, bezirk, bezirk_kz, bundesland, bundesland_kz (Statistik Austria, CC BY 4.0, monatlich) |

## Bewertungsmodell (Startwerte stehen im Blatt „Gewichte“)

### Lead-Typen

| Typ | Woher | Typ-Punkte |
| --- | --- | --- |
| A1 Auftrag direkt | freelancer.at | 25 |
| A2 Projekt über Vermittler | Vermittler-Stellen mit Vertragsart freiberuflich, Projekt, befristet, Werkvertrag; karriere Projektarbeit; TheirStack `__projekte` | 20 |
| A3 Öffentliche Ausschreibung | TED | 20 |
| B1 Überbrückungsbedarf | Firmenstelle im Thema mit Interim, Karenz, befristet, Elternzeit, `tage_online` > 45 oder neu ausgeschrieben | 15 |
| B2 Bedarfssignal | Festanstellung im Thema | 8 |
| C Partner | IT-Dienstleister oder Beratung sucht BI-/Data-Leute (Subunternehmer, wie ppmc) | 15 |
| ausgeschlossen | Festanstellung über Vermittler, Sperrliste, Lead-Status beworben/kontaktiert/kein Fit/erledigt | – |

### Bausteine des Vorscores (0–100)

| Baustein | Punkte | Regel |
| --- | --- | --- |
| Thema | 0–35 | je Thema der stärkste Begriff, Titel zählt doppelt (`titel_faktor`), Summe gedeckelt (`deckel`). Ohne Kernthema (Datenplattform, BI und Reporting, KI, Controlling) im Titel höchstens 20. Negativ-Begriffe zählen nur im Titel |
| Typ | 0–25 | siehe Lead-Typen |
| Region | 0–20 | Kärnten 20, remote 20, Steiermark/Salzburg/Osttirol 15, Oberösterreich/Nordtirol 8, Wien/NÖ/Burgenland/Vorarlberg 6 (+4 bei hybrid), DACH 3, unbekannt 5 |
| Frische | 0–15 | nach Veröffentlichung: bis 3 Tage 15, bis 7 Tage 12, bis 14 Tage 8, bis 30 Tage 4, älter 0 |
| Passung | 0–5 | Stundensatz ab 60 € oder Budget genannt 3, Firmengröße 20–500 2 |
| Bonus | bis +15 | +5 lange offen (> 45 Tage) oder neu ausgeschrieben, +5 höchstens 3 Reaktionen, +5 zweite relevante Gelegenheit derselben Firma in 60 Tagen |
| Abzug | bis −25 | −10 Konzern oder Konzerntochter, −15 Negativbegriff im Titel |

Tagesliste: A (A1–A3) ab 55, höchstens 8; B (B1, B2) ab 60, höchstens 8, je Firma nur die beste; C ab 50, höchstens 3.

Treffer-Regeln der Begriffe (wie im Collector, `relevanz.py`): groß/klein egal, Leerzeichen und Bindestrich gleichwertig; Begriffe ab 6 Zeichen auch als Teil eines Kompositums („Finanzcontroller“), kürzere nur als eigenes Wort; deutsche Endungen (in, innen, en, n, s, e, er, ern) erlaubt.

## Phase A: vorhandene Daten nutzen (sofort möglich)

1. `sat_stelle__karriere_text`: `summary` aus dem Suchergebnis. `date` (TT.MM.JJJJ) als `veroeffentlicht_am` prüfen, falls `posted_date` es nicht korrekt abbildet.
2. `sat_stelle__theirstack_detail`: `description`, `state_code`, `country_code`, `latitude`, `longitude`, `short_location`, `reposted`, `employment_statuses`, `keyword_slugs`.
3. `sat_firma__theirstack_detail`: aus `company_object` `city`, `postal_code`, `country_code`, `technology_names`, `num_jobs_last_30_days`, `industry_id`.
4. Adzuna: `description`, `contract_type`, `contract_time` sind im Satelliten und werden nur weitergereicht.

## Phase B: neue Landing-Quellen

1. `karriere_detail` und Website-Details → `sat_stelle__karriere_detail` und `sat_stelle__website_detail` (beschreibung, date_posted, valid_through, plz, ort, region, employment_type). karriere_detail hängt über die karriere-Job-ID am bestehenden `stelle_bk`.
2. freelancer.at normalisiert → `sat_stelle__freelancer_detail` (veroeffentlicht_am, zuletzt_geaendert_am, reaktionen, budget_min, budget_max, budget_einheit, ist_remote, ort).
3. Website: Stellen-Profil künftig aus `jobs[].profile` (leer = `ohne-treffer`) statt vom Firmenprofil.
4. Impressum → `sat_firma__impressum` (fn, uid, plz, ort, firmenname, konzern_hinweis, fremde_jobdomain).
5. `suchprofil` → Referenz-Views `ref_lead_engine__thema` und `ref_lead_engine__gewicht` (jüngster Stand). Lead-Status → `sat_stelle__lead_status` und `sat_firma__lead_status`, historisiert.
6. `referenz_ort` → `ref_lead_engine__ort` (plz, ortschaft, gemeinde, bezirk, bundesland).
7. TED → `hub_stelle` mit Record Source `lead-engine/ted` und `sat_stelle__ted`.
8. Firmenbuch, wenn der Token da ist → `sat_firma__firmenbuch` und `sat_firma__firmenbuch_ereignis` (nur Ereignistyp und Datum).

## Phase C: Business Vault

1. **`bv_firma_same_as`:** jedem `firma_bk` einen Master zuordnen – Reihenfolge FN (Impressum, Firmenbuch) → Domain ohne `www.` → normalisierter Name (klein, Rechtsformen GmbH, AG, KG, Co, Gesellschaft m.b.H., GesmbH, e.U., OG, regGenmbH und Sonderzeichen entfernt). Ausgabe `firma_bk`, `master_firma_bk`, `abgleich_regel`.
2. **`bv_stelle_merkmale`:** eine Zeile je `stelle_bk`, aktueller Stand:
   - `text` nach Priorität: Detailseite, TheirStack, freelancer.at, Adzuna, karriere `summary`; dazu `text_quelle`
   - `veroeffentlicht_am` nach Priorität: datePosted, karriere `date`, TheirStack `date_posted`, freelancer.at, Adzuna `created`; Fallback erste Sichtung mit `datum_geschaetzt = 1`
   - erste/letzte Sichtung, `tage_online`, `ist_reposted`, `ist_online`
   - `vertragsart` normalisiert: fest, teilzeit, befristet, freiberuflich, projekt, praktikum, lehre
   - `ist_remote`, `ist_hybrid`, `plz`, `ort`, `bundesland`, `land` über `ref_lead_engine__ort` (PLZ vor Ortsname)
   - `master_firma_bk`, `ist_vermittler`, Budget/Stundensatz, `reaktionen`
3. **`bv_stelle_thema`:** je Stelle × Thema × Begriff mit Treffer, Spalten `fundort` (titel/text), `gewicht`. Wortgrenze z. B. `' ' + lower(text) + ' ' like '%[^a-zäöüß]' + begriff + '[^a-zäöüß]%'` (für lange Begriffe ohne linke Grenze, siehe Treffer-Regeln).
4. **`bv_stelle_cluster`:** dieselbe Stelle über mehrere Quellen – Schlüssel `master_firma_bk` + normalisierter Titel (klein, ohne (m/w/d)-Varianten, ohne Satzzeichen); Repräsentant = Zeile mit dem besten Text.
5. **`bv_gelegenheit_score`:** je Cluster alle Bausteine einzeln, Punkte aus `ref_lead_engine__gewicht`:
   - Lead-Typ-Regeln wie oben (Vermittler mit fester Stelle → ausgeschlossen; IT-Dienstleister/Beratung über TheirStack-Branche oder eine Liste im Sheet → C)
   - `ist_konzern`: Mitarbeiter > 2.500 (TheirStack oder karriere-Klasse) oder `konzern_hinweis` oder `fremde_jobdomain`
   - Status: jüngster Lead-Status beworben/kontaktiert/kein Fit/erledigt → ausgeschlossen, bleibt mit Kennzeichen in der Tabelle
   - Ausgabe zusätzlich `vorscore` und `begruendung_kurz`, z. B. „Thema: Power BI (Titel) · Kärnten · vor 2 Tagen · 2 Reaktionen“

## Phase D: Mart

1. **`lead_gelegenheiten_v`** – eine Zeile je Cluster, veröffentlicht oder zuletzt gesehen in den letzten 30 Tagen:
   - Schlüssel: `gelegenheit_key` und `gelegenheit_id` als **varchar** (das MCP-Blättern scheitert an großen bigint-Schlüsseln)
   - Bewertung: `lead_typ`, `vorscore`, alle Bausteine, `begruendung_kurz`, `themen` (string_agg)
   - Inhalt: `titel`, `text` (gekürzt auf 4.000 Zeichen), `url`, `quellen`
   - Firma: Name des Masters, `ist_konzern`, `groesse`, `mitarbeiter`, `technologien`
   - Ort: `ort`, `plz`, `bundesland`, `ist_remote`, `ist_hybrid`
   - Konditionen: `vertragsart`, `veroeffentlicht_am`, `datum_geschaetzt`, `tage_online`, `reaktionen`, `budget`
   - Status: `status`, `status_am`
2. **`lead_firmen_v`** – eine Zeile je Master-Firma: bester Vorscore, Zahl der Gelegenheiten mit Vorscore ab 40, Themen, Region, Größe, Konzern, Technologien, Firmenbuch-Ereignisse, Status. Ersetzt nach Umstellung des Skills `lead_kandidaten_v`.

## Tests und Abnahme

- `gelegenheit_key` eindeutig; `lead_typ` not null und in A1, A2, A3, B1, B2, C; `vorscore` zwischen −25 und 100.
- Warnungen: > 30 % ohne `bundesland`; > 20 % der Typen A und B ohne Text; keine Zeile aus dem heutigen Lauf.
- Regressionsfall: freelancer.at-Auftrag „PowerBI Experte (m/w/d)“, Klagenfurt, veröffentlicht 9.10.2026 → A1, Region Kärnten, Vorscore ab 55.
- Gegenprobe: „ServiceNow AI Control Tower Tester“ und „SAP SuccessFactors Berater“ (freelancer.at) liegen unter 40.

## Reihenfolge

Phase A und C mit den vorhandenen Daten zuerst (erste Fassung von `lead_gelegenheiten_v`), dann Phase B für die neuen Quellen. Sobald `lead_gelegenheiten_v` im Mart ist, schaltet Claude sie im MCP frei und stellt den Bewertungs-Skill um.
