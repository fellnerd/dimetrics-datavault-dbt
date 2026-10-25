---
title: "Transaction Satellite für Messdaten: Anti-Join über den Zeitraum begrenzen"
tags:
  - lessons-learned
---
[Dokumentation](../README.md) › [Lessons Learned](00-lessons-learned.md)

# Transaction Satellite für Messdaten: Anti-Join über den Zeitraum begrenzen

**Muster:** Mess- und Sensorwerte gehören in einen **append-only Transaction Satellite** mit Schlüssel `(hash_key, zeitstempel)`, nicht in einen Multi-Active oder SCD2-Satelliten. Ein Messwert ist ein Fakt: er hat keine Historie, es gibt ihn oder es gibt ihn nicht.

**Problem:** Liefert die Quelle ein rollierendes Zeitfenster (überlappt also mit bereits Geladenem), lässt sich kein reiner HWM-Filter verwenden — er würde nachträgliche Korrekturen verwerfen. Es braucht einen Anti-Join gegen den Satelliten, und der wird mit wachsender Historie teuer (vgl. `sat_<ereignis>__<quelle>`: 9.4M Zeilen → Hash Match über die ganze Tabelle → 45+ Minuten).

**Lösung — zwei Hebel:**

1. **Anti-Join über den Zeitraum der Quelle begrenzen.** Nur Satellitenzeilen ab dem frühesten Messzeitpunkt des aktuellen Exports prüfen:

   ```sql
   WHERE s.messzeitpunkt >= (SELECT MIN(...) FROM <quelle>)
   ```

   Die Schranke muss aus der **Quelle** kommen, nicht aus dem Satelliten: ein Backfill liefert ältere Zeitpunkte, und eine satellitenseitige Schranke würde sie am Vergleich vorbeilassen → Duplikate.

2. **Zusammengesetzter Index** `(hash_key, zeitstempel) INCLUDE (hashdiff)` — deckt den Anti-Join vollständig ab (Index Seek statt Scan) und trägt gleichzeitig die typische Mart-Abfrage "Werte einer Serie in einem Zeitraum".

**Messfalle beim Optimieren:** SQL Server wertet eine mehrfach referenzierte CTE **mehrfach** aus. Wird die Zeitschranke aus derselben CTE berechnet wie die Nutzdaten, läuft die komplette Staging-Kette (Dedup-Fensterfunktion + Join + Hashing über die External Table) zweimal. Gemessen an einem Sensordaten-Satelliten:

| Variante | Laufzeit inkrementeller Lauf (0 neue Zeilen) |
|---|---|
| Schranke aus `source_data` (CTE, doppelte Auswertung) | 51,7 s |
| Schranke direkt aus der External Table | **37,4 s** |

Die Schranke aus der Rohtabelle ist dabei gleich korrekt oder weiter — das Staging filtert nur, es fügt keine Zeitpunkte hinzu.

**Wo die Zeit wirklich liegt** (Einzelmessung, 169.248 Zeilen):

| Zugriff | Zeit |
|---|---|
| Staging-View-Kette über die External Table | **12.986 ms** |
| `COUNT(*)` auf dem Satelliten (indiziert) | 16 ms |
| Current-View (`ROW_NUMBER` über die volle Tabelle) | 426 ms |

→ Der Flaschenhals ist das wiederholte Lesen der Parquet-Dateien, **nicht** der Anti-Join. Wer hier weiter optimieren will, braucht eine **PSA** (Staging einmal materialisieren), nicht mehr Indizes.

Betroffene Objekte (Beispiel): `models/staging/iot_sensor_messung_dedup.sql`, `models/raw_vault/<concept>/satellites/sat_sensor_messung_tl__<quelle>.sql`.

---

◀ [Multi-Active Satellite: Load Date muss ein BATCH-Wert sein](14-multi-active-satellite-load-date.md) · [Übersicht](00-lessons-learned.md)
