---
title: "Raw Vault"
aliases:
  - "Raw Vault"
  - "Raw-Vault-Objekte"
tags:
  - entwickler/raw-vault
  - typ/inhaltsverzeichnis
---
[Dokumentation](../../../README.md) › [Data Vault 2.1 – Developer Guide](../../00-entwicklerhandbuch.md) › [Objekte anlegen](../00-objekte-anlegen.md)

# Raw Vault

Der Raw Vault speichert alle Quelldaten **insert-only und vollständig historisiert** — ohne fachliche Umrechnung. Jedes Objekt ist `incremental` mit `append`, erzeugt von einem automate_dv-Makro. Schema `vault` (`models/raw_vault/_common/`) oder `vault_<concept>` (`models/raw_vault/<concept>/`).

| # | Objekt | automate_dv | Grain (eine Zeile je …) | Pflicht-Post-Hooks |
|---|--------|-------------|--------------------------|--------------------|
| 1 | [Hub](01-hub.md) | `hub()` | Business Key | `create_hash_index` |
| 2 | [Satellite](02-satellite.md) | `sat()` | Key + Änderung (Hash Diff) | `create_hash_index`, `update_satellite_current_flag` |
| 3 | [Link](03-link.md) | `link()` | Schlüsselkombination | `create_hash_index` |
| 4 | [Transaction Link](04-transaction-link.md) | `link()` / `t_link()` | Ereignis | `create_hash_index` |
| 5 | [Effectivity Satellite](05-effectivity-satellite.md) | eigenes SQL (Driving Key) | Beziehung + Gültigkeitsänderung | `create_hash_index`, `update_effectivity_end_dates` |
| 6 | [Dependent-Child Satellite](06-dependent-child-satellite.md) | `sat()` am Link | Key + Unterschlüssel + Änderung | wie Satellite |
| 7 | [Multi-Active Satellite](07-multi-active-satellite.md) | `ma_sat()` | Key + Satz aktiver Zeilen | wie Satellite |
| 8 | [Reference Table](08-reference-table.md) | — (View/Seed) | Code | — |
| 9 | [Attribut hinzufügen](09-attribut-hinzufuegen.md) | — | — | — |

## Entscheidung in Kürze

```
Stabiler, eigenständiger Business Key?                → Hub
Beschreibende Attribute, die sich ändern?             → Satellite (je Quelle einer)
Beziehung zwischen Hubs?                              → Link
   … unveränderliches Ereignis / Massendaten?         → Transaction Link
   … Beziehung beginnt und endet (Gültigkeit)?         → Effectivity Satellite am Link
Mehrere gleichzeitig gültige Werte je Key?            → Multi-Active Satellite
Zeilen nur mit Unterschlüssel eindeutig (Positionen)? → Dependent-Child Satellite
Code-/Lookup-Liste ohne Historie?                     → Reference Table
```

Ausführlich mit Begründungen: [Data Vault 2.1 Leitfaden](../../01-data-vault-leitfaden.md).
