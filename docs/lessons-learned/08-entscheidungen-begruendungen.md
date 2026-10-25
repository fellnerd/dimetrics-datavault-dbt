---
title: "Entscheidungen & Begründungen"
tags:
  - lessons-learned
---
[Dokumentation](../README.md) › [Lessons Learned](00-lessons-learned.md)

# Entscheidungen & Begründungen

### 1. dbt statt Stored Procedures
**Entscheidung:** dbt Core mit automate-dv Package statt T-SQL Stored Procedures

**Begründung:**
- Versionskontrolle (Git) nativ integriert
- Wiederverwendbare Macros für verschiedene Kunden
- Lineage und Dokumentation automatisch
- Community-Support und Best Practices (automate-dv)

### 2. Hybrid: Raw Vault physisch, Business Vault virtuell
**Entscheidung:** Raw Vault als echte Tabellen, Business Vault als Views

**Begründung:**
- Raw Vault benötigt Insert-Only Performance
- Business Vault ist nur berechnete Sichten
- Kosteneinsparung bei Azure SQL

### 3. SHA2_256 als Hash-Algorithmus
**Entscheidung:** SHA2_256 → CHAR(64) für alle Hash Keys

**Begründung:**
- Industriestandard für Data Vault
- Native Unterstützung in SQL Server (HASHBYTES)
- Keine Kollisionsgefahr bei erwarteten Datenmengen
- 64 Zeichen als feste Länge gut handhabbar

### 4. Linux VM für dbt
**Entscheidung:** dbt auf Linux VM statt Mac/Windows

**Begründung:**
- ODBC-Treiber stabiler unter Linux
- Einfachere Deployment-Vorbereitung für Container
- VS Code Remote SSH ermöglicht komfortable Entwicklung

### 5. Unified Hub Pattern statt 3 separate Hubs
**Entscheidung:** Ein `hub_company` mit `link_company_role` statt `hub_company_client`, `hub_company_contractor`, `hub_company_supplier`

**Begründung:**
- Identische Attribute in allen 3 Quellen (>90% Überlappung)
- Weniger Redundanz, einfachere Wartung
- Role als Link ermöglicht zukünftige Multi-Role-Unternehmen
- `object_id` ist NICHT global unique → Composite Key `object_id + source_table`

### 6. Hash-Separator '^^' statt '||'
**Entscheidung:** `'^^'` als Trennzeichen für Composite Hash Keys

**Begründung:**
- DV 2.1 Best Practice (selten in natürlichen Daten)
- `'||'` kann in SQL-Strings vorkommen (Oracle Concat-Operator)
- Konsistenz mit Scalefree Standards

### 7. dss_is_current + dss_end_date in Satellites
**Entscheidung:** Current-Flag und End-Dating in allen Satellites

**Begründung:**
- Effiziente Abfrage des aktuellen Stands ohne ROW_NUMBER()
- dss_end_date ermöglicht historische Point-in-Time Abfragen
- Post-Hook Macro hält Flag automatisch aktuell

---

◀ [Business-Vault-Architektur (kurz)](07-business-vault-architektur-kurz.md) · [Übersicht](00-lessons-learned.md) · [Probleme & Lösungen](09-probleme-loesungen.md) ▶
