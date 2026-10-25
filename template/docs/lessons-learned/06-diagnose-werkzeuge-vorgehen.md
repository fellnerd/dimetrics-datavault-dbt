---
title: "Diagnose-Werkzeuge / Vorgehen"
tags:
  - lessons-learned
---
[Dokumentation](../README.md) › [Lessons Learned](00-lessons-learned.md)

# 5. Diagnose-Werkzeuge / Vorgehen

- **`dbt show --inline`** wrappt Queries intern mit eigenem `TOP`/`OFFSET` — Konflikte mit eigenem `ORDER BY`, `SELECT DISTINCT` + `ORDER BY`, und mehrfachen Statements (`SET SHOWPLAN_XML`, `CREATE/ALTER FUNCTION` + folgendes `SELECT`). Workarounds: `ORDER BY` weglassen (stattdessen `GROUP BY` für Uniqueness), DDL wie `CREATE OR ALTER FUNCTION` als alleiniges Statement ohne Folge-SELECT senden.
- **Vor Annahme "Serverless Cold-Start ist Schuld"**: `sys.dm_db_resource_stats` (CPU/IO/Memory-Auslastung) und `sys.dm_os_sys_info.sqlserver_start_time` prüfen. Bei uns lag CPU durchgehend unter 27% — Ressourcenengpass war nicht die Ursache, obwohl die Instanz erst 43 Minuten lief.
- **Gemessene Zahl schlägt Spekulation** — mehrfach in dieser Session bestätigt: eigene erste Vermutungen (LIKE-Join als Kostentreiber, RLS-CTE-Fix würde helfen, Sortierung war Ursache für leere Result-Zeilen) waren jeweils durch Nachmessen widerlegt oder bestätigt worden — nie durch reines Nachdenken allein entschieden.

---

◀ [Zebra BI Tables](05-zebra-bi-tables.md) · [Übersicht](00-lessons-learned.md) · [Business-Vault-Architektur (kurz)](07-business-vault-architektur-kurz.md) ▶
