---
title: "Multi-Active Satellite: Load Date muss ein BATCH-Wert sein"
tags:
  - lessons-learned
---
[Dokumentation](../README.md) › [Lessons Learned](00-lessons-learned.md)

# Multi-Active Satellite: Load Date muss ein BATCH-Wert sein

**Symptom:** Ein Satellit mit Sensor-Messwerten — zunächst als Multi-Active Satellite `sat_sensor_messung_ma__iot` gebaut (automate_dv `ma_sat`), später als Transaction Satellite `sat_sensor_messung_tl__iot` neu aufgesetzt — verdoppelte sich bei jedem Lauf — 169.248 → 338.496 → … , obwohl die Quelldaten unverändert waren. Hubs, Links und SCD2-Satelliten derselben Domäne blieben stabil.

**Ursache:** In der Staging-View war `dss_load_date` der Export-Zeitstempel der **einzelnen Zeile** (aus dem Quelldateinamen abgeleitet). Da die Werte eines Hash Keys aus mehreren Exportdateien stammen, trug ein und derselbe `hk_sensor` **9 verschiedene Load Dates**.

`automate_dv.ma_sat` vergleicht beim Inkrementell-Lauf **Mengen** je Hash Key. Dazu bildet es

```
latest_records = alle Sätze mit dem HÖCHSTEN dss_load_date je Hash Key
```

Bei zeilenweise unterschiedlichen Load Dates schrumpft diese Vergleichsmenge auf die Sätze der jüngsten Datei (hier 480 statt 4.128). Alle übrigen eingehenden Sätze finden keinen Partner, gelten als neu und werden erneut eingefügt — bei jedem Lauf.

**Regel:** In einem Multi-Active Satellite müssen **alle Sätze eines Hash Keys aus einem Ladelauf dasselbe `dss_load_date` tragen.** Das Load Date ist ein Batch-Merkmal, kein Zeilenmerkmal. Bei SCD2-Satelliten (`automate_dv.sat`) fällt das nicht auf — dort wird je Hash Key nur ein Satz verglichen.

**Fix:**

```sql
-- statt: r.dss_export_datum  (je Zeile verschieden)
COALESCE(MAX(r.dss_export_datum) OVER (), CAST(GETDATE() AS DATETIME2)) AS dss_load_date
```

`MAX(...) OVER ()` statt `GETDATE()`, damit der Wert bei unverändertem Dateibestand stabil bleibt — sonst erzeugt jeder Lauf ein neues Load Date und die Läufe sind nicht reproduzierbar (der Mengenvergleich fängt das zwar ab, aber ein deterministisches Load Date ist beim Debuggen Gold wert). Der zeilenweise Zeitstempel bleibt als eigene Lineage-Spalte `dss_export_datum` erhalten.

**Prüfung, die das aufdeckt** — gehört nach jedem neuen Vault-Objekt einmal gemacht:

```sql
-- 1. Idempotenz: dbt run zweimal hintereinander, Row Counts vergleichen
-- 2. Load Dates je Hash Key: muss 1 sein
SELECT TOP 10 <hash_key>, COUNT(DISTINCT dss_load_date) AS n_ldts, COUNT(*) AS n_rows
FROM <ma_satellit>
GROUP BY <hash_key> ORDER BY COUNT(DISTINCT dss_load_date) DESC;
```

**Nachtrag: das eigentliche Problem war die Musterwahl.** Messwerte sind Fakten, keine Zustände — ein MA-Satellit war hier von vornherein falsch. Der Satellit wurde durch einen **append-only Transaction Satellite** ersetzt (`sat_sensor_messung_tl__iot`, Schlüssel `(hk_sensor, messzeitpunkt)`); der Mengenvergleich entfällt damit komplett, und das zeilenweise Load Date ist wieder zulässig und sogar präziser. Siehe nächsten Abschnitt.

---

◀ [Technische Referenz](13-technische-referenz.md) · [Übersicht](00-lessons-learned.md) · [Transaction Satellite für Messdaten: Anti-Join über den Zeitraum begrenzen](15-transaction-satellite-fuer-messdaten.md) ▶
