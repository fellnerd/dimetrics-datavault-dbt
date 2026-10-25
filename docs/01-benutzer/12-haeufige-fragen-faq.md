---
title: "Häufige Fragen (FAQ)"
tags:
  - benutzer
  - typ/faq
---
[Dokumentation](../README.md) › [Data Vault 2.1 – Benutzer-Dokumentation](00-benutzerhandbuch.md)

# Häufige Fragen (FAQ)

## Für Analysten und Endanwender

**Wo finde ich die Daten für meinen Bericht?**
In den `_v`-Views der Schemas `mart` (geteilte Dimensionen wie `dim_date_v`) und `mart_<domain>` (z. B. `mart_finance.fakt_buchungen_v`). Welche es gibt, zeigt `dbt docs serve` bzw. `SELECT name FROM sys.views WHERE SCHEMA_NAME(schema_id) LIKE 'mart%'`.

**Wie aktuell sind die Daten?**
So aktuell wie der letzte Ladelauf: `SELECT MAX(completed_at) FROM vault.load_status WHERE status = 'completed'`. Den Ladeplan je Quelle beschreibt die [projektspezifische Dokumentation](../04-mandant-architektur/00-mandant-architektur.md).

**Wie sehe ich den aktuellen Stand eines Objekts?**

```sql
SELECT * FROM vault.sat_<entity>__<quelle>_current_v WHERE hk_<entity> = '<hash>';
-- oder
SELECT * FROM vault.sat_<entity>__<quelle> WHERE dss_is_current = 'Y' AND hk_<entity> = '<hash>';
```

**Wie finde ich den Hash zu einem Business Key?**

```sql
SELECT hk_<entity>, dss_business_key FROM vault.hub_<entity> WHERE <bk> = '<wert>';
```

**Wie sah ein Datensatz am 30.06. aus?**

```sql
SELECT * FROM vault.sat_<entity>__<quelle>
WHERE hk_<entity> = '<hash>'
  AND dss_load_date <= '2026-06-30' AND (dss_end_date > '2026-06-30' OR dss_end_date IS NULL);
```

**Warum sehe ich andere Summen als meine Kollegin?**
Zeilenfilter: Jeder sieht nur seine berechtigten Kostenstellen/Konten ([Datenzugriff](09-datenzugriff-berechtigungen.md)).

**Werden gelöschte Datensätze der Quelle im Vault gelöscht?**
Nein. Der Raw Vault ist insert-only; was die Quelle einmal geliefert hat, bleibt erhalten. Ob ein Satz noch aktiv ist, zeigen Effectivity Satellites (`dss_is_active`) oder fachliche Status-Attribute. Datenschutzbedingte Löschungen sind ein eigener, abgestimmter Prozess.

## Für Entwickler

**Wie füge ich ein neues Attribut hinzu?**
Staging-Hashdiff und Satellite-Payload erweitern — mit Folgen für die Historie; vorher [Attribut hinzufügen](../02-entwickler/04-objekte-anlegen/raw-vault/09-attribut-hinzufuegen.md) lesen.

**Warum schreibt mein Satellite bei jedem Lauf neue Versionen?**
Payload und Hashdiff-Spalten stimmen nicht überein, oder eine Lineage-Spalte bzw. `dss_create_datetime` steckt im Hashdiff ([Satellite](../02-entwickler/04-objekte-anlegen/raw-vault/02-satellite.md)).

**Brauche ich nach einer Änderung einen Full Refresh?**
Nur wenn sich die Berechnung bestehender Zeilen ändert (Hash-Input, Datentyp, Business Key). Neue Spalten nicht. Siehe [dbt-Befehle → Full Refresh](06-dbt-befehle.md).

**Was bedeutet „Hash Diff hat sich geändert“?**
Mindestens ein Attribut im Hashdiff hat einen anderen Wert — der Satellite schreibt eine neue Version und setzt die bisherige auf `dss_is_current = 'N'`.

**Wie komme ich an Test oder Produktion?**
Über Merge Requests und die Pipeline ([Deployment Workflow](../02-entwickler/06-deployment-workflow.md)).

---

◀ [Troubleshooting](11-troubleshooting.md) · [Übersicht](00-benutzerhandbuch.md) · [Glossar](13-glossar.md) ▶
