---
title: "Business-Vault-Architektur (kurz)"
tags:
  - lessons-learned
---
[Dokumentation](../README.md) › [Lessons Learned](00-lessons-learned.md)

# 6. Business-Vault-Architektur (kurz)

- Business-Vault-Objekte, die **direkt von einem BI-Tool konsumiert werden**, gehören ins Mart-Schema (`mart_finance` etc.), nicht ins `vault`-Schema — Endnutzer sollen langfristig nur `mart`/`mart_<domain>` sehen können. Rein intern von anderen dbt-Modellen konsumierte Business-Vault-Objekte könnten weiterhin in `vault` liegen, das war hier aber nicht der Fall.
- Eine Business-Vault-Referenztabelle sollte **nur** die echte, quellsystemlose Business-Regel enthalten (Sortierung, Zuordnung, Plug-Keys) — **nicht** Labels/Namen, die bereits aus einer echten Quelle (Sharepoint etc.) kommen. Sonst entsteht dieselbe Duplizierungs-Problematik, die man eigentlich beheben wollte, nur an anderer Stelle.

---

◀ [Diagnose-Werkzeuge / Vorgehen](06-diagnose-werkzeuge-vorgehen.md) · [Übersicht](00-lessons-learned.md) · [Entscheidungen & Begründungen](08-entscheidungen-begruendungen.md) ▶
