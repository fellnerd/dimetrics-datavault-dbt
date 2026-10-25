---
title: "CLS & Verschlüsselung"
tags:
  - system/security
---
[Dokumentation](../../README.md) › [Data Vault 2.1 – Systemdokumentation](../00-systemdokumentation.md) › [Security](00-security.md)

# CLS & Verschlüsselung

Während OLS und RLS regeln, *welche Objekte und Zeilen* jemand sieht, geht es hier um *einzelne Spalten*.

## Schutz-Tiering

Nicht jede sensible Spalte wird gleich behandelt. Drei Stufen:

| Tier | Beispiele | Schutz |
|---|---|---|
| **1 — streng vertraulich** | AHV-Nr. (`SOC_INSURANCE_NR`), `ZEMIS_NR`, `BADGE_ID` | **Nicht-Exposition**: tauchen in keinem Mart-Objekt auf, liegen nur im `vault`-Schema ohne Business-Grants |
| **2 — vertraulich (PII)** | `vorname`, `nachname`, `geburtsdatum`, `geburtsort`, `nationalitaet`, `geschlecht` | CLS-Maskierung in Views (Kontext `person_pii`) |
| **3 — intern** | Beträge, Kundennummern | RLS über die Zeilenfilter |

Tier 1 wird vom Test `assert_no_tier1_columns_in_mart` überwacht — er schlägt an, sobald eine dieser Spalten in einem `mart%`-Schema auftaucht.

## CLS — Spaltenmaskierung

SQL Server hat keine native Column Level Security. Umgesetzt wird sie in der View: Die Spalte zeigt einen Ersatzwert, wenn der Nutzer keinen Eintrag für den Kontext hat.

```sql
-- in der SELECT-Liste einer View
{{ cls_mask('nachname', 'person_pii') }}              AS nachname,
{{ cls_mask('geburtsdatum', 'person_pii', 'NULL') }}  AS geburtsdatum
```

kompiliert zu:

```sql
CASE WHEN EXISTS (SELECT 1 FROM sec.fn_check_cls('person_pii'))
     THEN nachname ELSE '***' END AS nachname
```

Für Nicht-String-Spalten einen typkompatiblen `mask_value` angeben (`'NULL'`, `0`, …) — sonst bricht die View an einem Typkonflikt.

`sec.fn_check_cls` ist die binäre Variante der Prüffunktion: kein Schlüsselvergleich, nur „Eintrag vorhanden ja/nein".

### Berechtigung vergeben

```sql
INSERT INTO sec.sec_user_privilege (user_name, security_context, sec_value_key, description)
VALUES (N'<upn>', N'person_pii', N'*', N'Freigabe Data Owner, Ticket XYZ-123');
```

Konvention: `sec_value_key = '*'` für CLS-Kontexte, da kein Zeilenbezug existiert.

### Freigabeprozess

1. Anforderung per Jira-Ticket
2. Freigabe durch den **fachlichen Data Owner**, im Ticket dokumentiert
3. Erst danach der Insert — Ticketnummer in `description`

Das ist bewusst schwergängiger als eine Kostenstellen-Berechtigung: Es geht um Personendaten.

### Designregel

> **CLS-pflichtige Spalten gehören nicht in physische Mart-Tabellen.** Nur in Views (maskiert) oder gar nicht in den Mart. Seit der Umstellung auf View-Grants sind physische Tabellen ohnehin unerreichbar — die Regel bleibt trotzdem als zweite Verteidigungslinie.

## Verschlüsselung

### Was aktiv ist

- **TDE** (Transparent Data Encryption): auf Azure SQL standardmäßig aktiv, verschlüsselt im Ruhezustand.
- **Verschlüsselte Verbindungen**: `encrypt=true` in allen dbt-Profilen, ebenso für Power BI und SSMS.
- **Upstream**: Die Klartextdaten liegen ohnehin in ADLS-Parquet. Die dortige Zugriffskontrolle (RBAC/ACLs) plus Storage-Verschlüsselung ist der eigentliche Schutz der Ladestrecke.

### Always Encrypted — geprüft und verworfen

| Grund | Detail |
|---|---|
| **Power BI inkompatibel** | Power Query kann AE-Spalten weder im Import noch in DirectQuery lesen — jede Abfrage mit einer solchen Spalte bricht |
| **dbt-Load bricht** | AE verschlüsselt clientseitig; serverseitige `INSERT … SELECT` können AE-Spalten nicht befüllen |
| **Kein echter Gewinn** | Der Klartext existiert upstream in ADLS — AE nur in SQL wäre Scheinsicherheit |

Fazit: Tier-1-Daten werden durch **Nicht-Exposition** geschützt. Das ist in diesem Setup einfacher und wirksamer als spaltenweise Verschlüsselung.

### Dynamic Data Masking — optional, kein Ersatz

DDM kann zusätzlich auf Vault-PII-Spalten gelegt werden. Grenzen, die man kennen muss:

- per Inferenz umgehbar (`WHERE`-Filter auf maskierte Spalten)
- der `UNMASK`-Grant wirkt global, nicht je Spalte
- bei `--full-refresh` inkrementeller Satellites geht die Maskierung verloren (Re-Apply-Hook nötig, Muster: `create_hash_index`)

DDM ersetzt **keine** Zugriffskontrolle — es ist eine zweite Verteidigungslinie hinter OLS.

---

◀ [RLS – Zeilenfilter über Dimensionen](04-rls-dimensional.md) · [Übersicht](00-security.md)
