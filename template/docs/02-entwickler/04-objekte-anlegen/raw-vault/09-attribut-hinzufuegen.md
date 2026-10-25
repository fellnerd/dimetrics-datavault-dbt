---
title: "Attribut hinzufügen"
tags:
  - entwickler/raw-vault
---
[Dokumentation](../../../README.md) › [Data Vault 2.1 – Developer Guide](../../00-entwicklerhandbuch.md) › [Objekte anlegen](../00-objekte-anlegen.md) › [Raw Vault](00-raw-vault.md)

# Attribut hinzufügen

Die Quelle liefert eine neue Spalte, die in den Vault soll. Das ist **kein Routinevorgang**: Ein Satellite erkennt Änderungen am Hash Diff. Kommt eine Spalte in den Hash Diff, ändert sich der Hash **jedes** Schlüssels — beim nächsten Lauf schreibt der Satellite für alle Schlüssel eine neue Version, obwohl sich fachlich nichts geändert hat. Faktisch wird der Satellite einmal komplett neu geladen (Zeilenzahl verdoppelt sich, alle bisherigen Versionen werden auf `dss_is_current = 'N'` gesetzt).

## Welcher Weg?

| Weg | Vorgehen | Historie | Aufwand | Empfehlung |
|-----|----------|----------|---------|------------|
| **A — neuer Satellite** | Neue Attribute in einen eigenen Satellite `sat_<entity>_<gruppe>__<quelle>` mit eigenem Hash Diff | bestehender Satellite bleibt unberührt; neuer beginnt ab heute | gering | **Standard** — DV-konform, kein Delta-Sprung |
| B — Satellite erweitern, ohne Full Refresh | Spalte in Hash Diff + Payload aufnehmen | bleibt erhalten; einmalig eine Zusatzversion je Schlüssel, alte Versionen haben NULL in der neuen Spalte | gering | nur bei kleinen Satellites und wenn der Delta-Sprung für Auswertungen unkritisch ist |
| C — Satellite erweitern mit Full Refresh | wie B, dann `--full-refresh` | **Historie aus Zeiten, die die Quelle nicht mehr liefert, geht verloren** | gering, Risiko hoch | nur wenn die Quelle die komplette Historie liefert oder der Satellite noch nicht produktiv ist |
| D — nur durchreichen | Spalte in Payload, **nicht** in Hash Diff | Änderungen dieser Spalte werden nicht historisiert | gering | nur für rein technische/informative Spalten |

Weg A ist auch die richtige Wahl, wenn die neuen Attribute sich anders oft ändern oder vertraulicher sind als der Rest (Satellite-Split nach Änderungsrate bzw. Schutzbedarf).

## Weg A — neuer Satellite

1. **External Table** um die Spalte erweitern (`sources.yml`) und neu anlegen:

   ```bash
   dbt run-operation stage_external_sources --args 'select: staging.ext_<concept>_<entity>' --vars 'ext_full_refresh: true'
   ```

2. **Staging View**: zweiten Hash Diff ergänzen, bestehenden **nicht** ändern:

   ```yaml
   hashed_columns:
     hk_<entity>: "<BK>"
     hd_<entity>__<quelle>:              # unverändert
       is_hashdiff: true
       columns: ["<ALT_A>", "<ALT_B>"]
     hd_<entity>_<gruppe>__<quelle>:     # neu
       is_hashdiff: true
       columns: ["<NEU_X>"]
   ```

3. **Neuer Satellite** `sat_<entity>_<gruppe>__<quelle>.sql` nach der [Satellite-Vorlage](02-satellite.md) mit `src_hashdiff: hd_<entity>_<gruppe>__<quelle>` und `src_payload: ["<NEU_X>"]`, dazu Current View und YAML.

4. **Mart**: Dimension/Fakt joint zusätzlich den neuen Satellite (bzw. dessen Current View).

## Weg B — Satellite erweitern

1. External Table erweitern (wie oben).
2. Spalte in **Hash Diff und `src_payload`** aufnehmen — beide Listen müssen identisch bleiben. automate_dv sortiert die Hash-Diff-Spalten alphabetisch; die Reihenfolge in der Liste ist egal.
3. Bauen **ohne** Full Refresh:

   ```bash
   dbt run --select <concept>_<entity> sat_<entity>__<quelle>
   ```

   `on_schema_change: append_new_columns` ergänzt die Spalte, bestehende Zeilen bleiben NULL; der Lauf erzeugt für jeden Schlüssel eine neue Version.
4. Im Changelog vermerken, ab welchem `dss_load_date` die Spalte gefüllt ist und dass die Versionen dieses Laufs keine fachliche Änderung darstellen.

## Prüfen

```sql
-- wie viele Versionen hat der letzte Lauf erzeugt?
SELECT dss_load_date, COUNT(*) FROM vault.sat_<entity>__<quelle>
GROUP BY dss_load_date ORDER BY dss_load_date DESC;

-- ist die neue Spalte gefüllt?
SELECT COUNT(*) AS gesamt, COUNT(<NEU_X>) AS gefuellt
FROM vault.sat_<entity>__<quelle> WHERE dss_is_current = 'Y';
```

## Spalte entfällt in der Quelle

Nicht aus Hash Diff und Payload entfernen, solange die External Table sie noch kennt — sonst ändert sich wieder jeder Hash. Liefert die Quelle sie nicht mehr, wird sie NULL; der Satellite schreibt dann einmalig neue Versionen. Die Spalte bleibt in der Tabelle (Historie). Entfernen erst nach Abstimmung und mit Changelog-Eintrag.

---

◀ [Reference Table erstellen](08-reference-table.md) · [Übersicht](00-raw-vault.md)
