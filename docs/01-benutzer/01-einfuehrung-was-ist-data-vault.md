---
title: "Einführung: Was ist Data Vault?"
tags:
  - benutzer
---
[Dokumentation](../README.md) › [Data Vault 2.1 – Benutzer-Dokumentation](00-benutzerhandbuch.md)

# Einführung: Was ist Data Vault?

### Für wen ist diese Dokumentation?

Diese Dokumentation richtet sich an **alle Benutzer** des Data Vault Systems - von Analysten, die Daten abfragen möchten, bis zu Entwicklern, die neue Datenquellen einbinden.

### Was macht unser Data Warehouse?

Stellen Sie sich das Data Vault wie ein **intelligentes Archiv** vor:

```
🏢 Ihre Quellsysteme        →    📊 Data Vault         →    📈 Ihre Berichte
(PostgreSQL, SAP, etc.)          (Azure SQL)               (Power BI, Excel)
```

**Das Data Vault sammelt Daten aus verschiedenen Systemen und:**
- ✅ Speichert **alles** - nichts geht verloren
- ✅ Merkt sich **wann** sich etwas geändert hat
- ✅ Weiß **woher** jede Information stammt
- ✅ Kann **rückwirkend** zeigen, wie Daten aussahen

### Warum Data Vault 2.1?

| Traditionell | Data Vault 2.1 |
|--------------|----------------|
| Daten werden überschrieben | Alle Änderungen werden aufbewahrt |
| "Wie war der Stand vor 3 Monaten?" - Keine Antwort | Vollständige Zeitreise möglich |
| Änderungen am Schema = Datenverlust | Schema-Änderungen jederzeit möglich |
| Eine Quelle = Ein System | Beliebig viele Quellen kombinierbar |

---

[Übersicht](00-benutzerhandbuch.md) · [Grundkonzepte](02-grundkonzepte.md) ▶
