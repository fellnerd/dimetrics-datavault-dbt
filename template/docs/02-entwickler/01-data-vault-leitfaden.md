---
title: "Data Vault 2.1 Leitfaden"
tags:
  - entwickler
---
[Dokumentation](../README.md) › [Data Vault 2.1 – Developer Guide](00-entwicklerhandbuch.md)

# Data Vault 2.1 Leitfaden

> **Wann**, **Warum** und **Wie** werden Data Vault Objekte verwendet?

### Grundprinzip

Data Vault trennt strikt zwischen:

| Aspekt | Frage | Objekt |
|--------|-------|--------|
| **Identität** | Was existiert? | Hub |
| **Beziehung** | Wie hängt etwas zusammen? | Link |
| **Historie** | Wie hat es sich über Zeit verändert? | Satellite |

**Ziele:** Auditierbarkeit, Historisierung, Skalierbarkeit, Entkopplung von Quelle & Reporting

---

### Entscheidungslogik

```
┌─────────────────────────────────────────────────────────────────┐
│  Gibt es einen stabilen Business Key?                          │
│  └─ JA → HUB                                                    │
│                                                                 │
│  Ändern sich Attribute über Zeit?                               │
│  └─ JA → SATELLITE                                              │
│                                                                 │
│  Beschreibt es eine Beziehung zwischen Objekten?                │
│  └─ JA → LINK                                                   │
│  └─ Hat die Beziehung eigene Attribute? → LINK SATELLITE        │
│                                                                 │
│  Mehrere Werte ohne eigene Identität (z.B. Telefonnummern)?     │
│  └─ JA → DEPENDENT CHILD SATELLITE                              │
│                                                                 │
│  Mehrere Werte gleichzeitig gültig (z.B. mehrere Rollen)?       │
│  └─ JA → MULTI-ACTIVE SATELLITE                                 │
│                                                                 │
│  Stabile Lookup-Werte (Länder, Status)?                         │
│  └─ JA → REFERENCE TABLE (kein Hub!)                            │
│                                                                 │
│  Performance-Problem bei Zeitabfragen?                          │
│  └─ JA → PIT TABLE                                              │
└─────────────────────────────────────────────────────────────────┘
```

---

### Hub

| Aspekt | Beschreibung |
|--------|--------------|
| **Zweck** | Repräsentiert **Business Keys**, identifiziert fachliche Objekte eindeutig |
| **Wann?** | Es gibt einen stabilen, fachlichen Schlüssel |
| **Beispiele** | MitarbeiterNr, KundenNr, VertragsNr, Projekt-ID |
| **Eigenschaften** | Keine fachlichen Attribute, keine Historie, ein Eintrag pro BK |
| **Schlüssel** | Hash Key (technisch), Business Key bleibt erhalten |

```sql
-- Struktur
hk_<entity>         -- Hash Key (PK)
<business_key>      -- Business Key (z.B. object_id)
dss_business_key    -- Normierter Business Key (CONCAT_WS-basiert)
dss_load_date       -- Ladezeitpunkt
dss_create_datetime -- Erstellungszeitpunkt
dss_record_source   -- Quelle
```

---

### Satellite

| Aspekt | Beschreibung |
|--------|--------------|
| **Zweck** | Trägt **Attribute und Historie** |
| **Wann?** | Attribute ändern sich über Zeit, Historisierung ist relevant |
| **Best Practice** | 1 Thema = 1 Satellite, nach Änderungsfrequenz schneiden |
| **Historisierung** | Jede fachliche Änderung = neuer Datensatz |

```sql
-- Struktur
hk_<entity>         -- Hash Key (FK zum Hub)
dss_load_date       -- Ladezeitpunkt (Teil des PK)
hd_<entity>__<quelle>         -- Hash Diff (Änderungserkennung)
<attribute_1>       -- Fachliche Attribute
<attribute_n>       
dss_create_datetime -- Erstellungszeitpunkt
dss_is_current      -- 'Y' = aktuell, 'N' = historisch
dss_end_date        -- Gültigkeitsende (NULL = aktuell)
```

**Varianten:**

| Typ | Wann verwenden? | Beispiel |
|-----|-----------------|----------|
| **Standard Satellite** | Normale Attribute | `sat_company` |
| **Dependent Child (DC)** | Entity ohne eigene Identität, identifiziert über Parent-Beziehung + DCK | `sat_contact_contractor_dc` |
| **Multi-Active (MA)** | Mehrere gleichzeitig gültige Werte | Mitarbeiter mit mehreren Rollen |
| **Extension Satellite** | Zusätzliche Attribute für Teilmenge | `sat_company_client_ext` (nur für Clients) |

---

### Dependent Child (DC) Satellite

| Aspekt | Beschreibung |
|--------|--------------|
| **Zweck** | Erfasst Entities **ohne eigenen stabilen Business Key** |
| **Wann?** | Entity existiert nur im Kontext eines Parent (z.B. Ansprechpartner zu Firma) |
| **Identifikation** | Parent-FK + Dependent Child Keys (DCK) bilden zusammen den logischen Schlüssel |
| **Struktur** | DC Satellite hängt am **Link**, nicht am Hub |

**Beispiel: Contact als Dependent Child von Contractor**

```
                hub_contractor
                      │
                      │ hk_contractor
                      │
              link_contact_contractor
              (hk_link = HASH(FK + DCK))
                      │
                      │ hk_link_contact_contractor
                      │
            sat_contact_contractor_dc
            (DCK: name, email1 im Payload)
```

**Staging für DC Pattern:**
```sql
-- Alle Hashes werden im Staging berechnet (automate_dv Best Practice)
hk_contractor                -- FK Hash zum Parent Hub
hk_link_contact_contractor   -- Link Hash = HASH(company_contractor ^^ name ^^ email1)
hd_contact_contractor_dc     -- Hashdiff für Änderungserkennung
```

**Link Model (nur 1 FK für Pure DC):**
```yaml
src_pk: "hk_link_contact_contractor"
src_fk: "hk_contractor"  # Nur Parent-FK, kein zweiter Hub
src_ldts: "dss_load_date"
src_source: "dss_record_source"
```

**DC Satellite Model:**
```yaml
src_pk: "hk_link_contact_contractor"  # Referenziert Link, nicht Hub
src_hashdiff: 
  source_column: "hd_contact_contractor_dc"
  alias: "hashdiff"
src_payload:
  - "name"       # DCK Column
  - "email1"     # DCK Column
  - "phone"      # Weitere Attribute
  - "..."
```

---

### Multi-Active (MA) Satellite

| Aspekt | Beschreibung |
|--------|--------------|
| **Zweck** | Erfasst **mehrere gleichzeitig gültige Werte** |
| **Wann?** | Entity hat multiple aktive Zustände (z.B. mehrere Rollen) |
| **Eigenschaften** | Zusätzliches Attribut als Teil des PK zur Unterscheidung |

---

### Link

| Aspekt | Beschreibung |
|--------|--------------|
| **Zweck** | Modelliert **Beziehungen zwischen Hubs** |
| **Wann?** | n:m- oder 1:n-Beziehungen, Beziehung ist fachlich relevant |
| **Beispiele** | Mitarbeiter ↔ Projekt, Kunde ↔ Vertrag, Company ↔ Country |
| **Eigenschaften** | Enthält nur Schlüssel der beteiligten Hubs, keine Attribute |

```sql
-- Struktur (Standard Link)
hk_link_<e1>_<e2>   -- Link Hash Key (PK)
hk_<entity_1>       -- FK zu Hub 1
hk_<entity_2>       -- FK zu Hub 2
dss_load_date       -- Ladezeitpunkt
dss_record_source   -- Quelle
```

**Link-Varianten:**

| Typ | FKs | Hash-Berechnung | Beispiel |
|-----|-----|-----------------|----------|
| **Standard Link** | 2+ Hub-FKs | `HASH(FK1 ^^ FK2)` | `link_company_country` |
| **DC Link (Pure)** | 1 Hub-FK | `HASH(FK ^^ DCK1 ^^ DCK2)` | `link_contact_contractor` |
| **DC Link (Hybrid)** | 2 Hub-FKs + DC | `HASH(FK1 ^^ FK2 ^^ DCK)` | Contact mit eigenem Hub + Parent |

---

### Link Satellite

| Aspekt | Beschreibung |
|--------|--------------|
| **Zweck** | Attribute, die **die Beziehung** beschreiben |
| **Wann?** | Attribute gelten für die Beziehung, nicht für das Objekt |
| **Beispiele** | Rolle eines Mitarbeiters im Projekt, Vertragsstatus |

---

### Effectivity Satellite

| Aspekt | Beschreibung |
|--------|--------------|
| **Zweck** | Trackt **Gültigkeitszeiträume** von Beziehungen |
| **Wann?** | Beziehungen können enden und wieder beginnen |
| **Beispiele** | Company-Country Zuordnung über Zeit |

```sql
-- Struktur
hk_link_<e1>_<e2>   -- FK zum Link (PK)
dss_start_date      -- Beginn der Gültigkeit (PK)
dss_end_date        -- Ende (NULL = aktiv)
dss_is_active       -- 'Y' = aktiv, 'N' = beendet
```

---

### Reference Table

| Aspekt | Beschreibung |
|--------|--------------|
| **Zweck** | Stabile, kleine **Lookup-Tabellen** |
| **Wann?** | Kaum Änderungen, keine Historisierung nötig |
| **Beispiele** | Länder, Währungen, Statuscodes, Rollen |
| **Regeln** | Nicht historisieren, nicht als Satellite, nicht übermodellieren |

```sql
-- Beispiel: ref_role (als dbt Seed)
role_code           -- PK (CLIENT, CONTRACTOR, SUPPLIER)
role_name           -- Anzeigename
role_description    -- Beschreibung
```

---

### PIT Table (Point-in-Time)

| Aspekt | Beschreibung |
|--------|--------------|
| **Zweck** | **Performance-Optimierung** für "As-of"-Abfragen |
| **Wann?** | Viele Satellites, komplexe zeitbezogene Joins, BI-Performance kritisch |
| **Eigenschaften** | Rein technisch, keine fachlichen Attribute |
| **Wichtig** | **Kein Pflichtbestandteil** – nur bei Bedarf einsetzen! |

```sql
-- Struktur
hk_<entity>         -- FK zum Hub
snapshot_date       -- Zeitpunkt
hk_sat_<name>       -- Verweis auf gültigen Satellite-Zustand
dss_load_date_sat   -- Load Date des referenzierten Satellites
```

---

### Information Mart

| Aspekt | Beschreibung |
|--------|--------------|
| **Zweck** | Konsum-Schicht für **BI & Analytics** |
| **Eigenschaften** | Dimensions- und Faktenmodelle, abgeleitet aus Raw/Business Vault |
| **Inhalte** | `dim_date`, `dim_kunde`, `fakt_rechnung` |
| **Wichtig** | Keine unabhängige Modellierung, keine zusätzliche Historisierung |

---

### ❌ Häufige Fehlannahmen

| Falsch | Richtig |
|--------|---------|
| Hubs sind historisiert | Hubs haben nur Ladezeitpunkt, keine fachliche Historie |
| Alles braucht einen Hub | Lookup-Werte → Reference Table |
| PIT ist Pflicht | PIT nur bei Performance-Bedarf |
| Referenztabellen in Satellites | Reference Tables sind eigenständig |
| Information Mart ist ein eigenes DWH | Mart ist eine abgeleitete Schicht (Tabellen + publizierte `_v`-Views), jederzeit aus dem Vault neu baubar |

---

### 📌 Merksatz

> **Hubs identifizieren.**  
> **Satellites historisieren.**  
> **Links verbinden.**  
> **Dependent Children ergänzen.**  
> **Multi-Active gilt parallel.**  
> **PIT beschleunigt.**  
> **Information Marts erklären.**

---

[Übersicht](00-entwicklerhandbuch.md) · [Quick Reference](02-quick-reference.md) ▶
