---
title: "Datenzugriff & Berechtigungen"
tags:
  - benutzer
  - system/security
---
[Dokumentation](../README.md) › [Data Vault 2.1 – Benutzer-Dokumentation](00-benutzerhandbuch.md)

# Datenzugriff & Berechtigungen

Was du sehen darfst, regeln drei unabhängige Schichten. Technische Referenz für Entwickler und Betrieb: [Security](../03-system/security/00-security.md).

## Die drei Schichten

| Schicht | Regelt | Fehlt die Berechtigung … | Vergeben über |
|---------|--------|---------------------------|---------------|
| **OLS** – Objektzugriff | Welche Views du öffnen darfst | Fehlermeldung „The SELECT permission was denied“ | Entra-ID-Gruppe deines Bereichs |
| **RLS** – Zeilenfilter | Welche Zeilen du darin siehst (z. B. Kostenstellen, Konten) | **0 Zeilen, ohne Fehlermeldung** | Gruppenrecht (alles) oder Einzelrecht (eingeschränkt) |
| **CLS** – Spaltenmaskierung | Ob du personenbezogene Spalten im Klartext siehst | `***` statt des Werts | Einzelfreigabe durch den Data Owner |

Faustregel für die Diagnose: **Fehlermeldung = OLS, null oder zu wenige Zeilen = RLS, Sternchen = CLS.**

## Was grundsätzlich wie erreichbar ist

| Bereich | Für Endanwender | Für Entwickler |
|---------|-----------------|----------------|
| `mart`, `mart_<domain>` – nur `_v`-Views | ✅ mit Gruppe, gefiltert durch RLS/CLS | ✅ |
| `mart_<domain>` – Tabellen `dim_*`/`fakt_*` | ❌ nie (ungefiltert) | Dev ✅, Test/Prod nur Lesen im Bedarfsfall |
| `vault`, `vault_<concept>` (Raw Vault) | ❌ | Dev ✅, Test/Prod lesend |
| `stg` (Staging, Rohdaten) | ❌ | Dev ✅ |
| `sec` (Rechtetabellen) | ❌ | nur Betrieb/Security-Verantwortliche |

Besonders schützenswerte Daten (z. B. Sozialversicherungsnummern) erscheinen **in keinem** Mart-Objekt — sie liegen nur im Raw Vault ohne Endanwender-Zugriff.

## Zugriff beantragen

Für Berichte brauchst du **immer** die Schritte 1 und 2 — sonst siehst du die Views, aber null Zeilen. Das ist der häufigste Fall bei neuen Nutzern.

| # | Was | Beispiel | Wo beantragen | Wer gibt frei |
|---|-----|----------|---------------|---------------|
| 1 | **Objektzugriff**: Aufnahme in die Lesegruppe deines Bereichs | `<gruppen-prefix>-finance-employees-ro` | IT (Entra ID) | Vorgesetzte |
| 2a | **Alle Zeilen** sehen: Aufnahme in die Vollzugriffsgruppe | `<gruppen-prefix>-finance-full-ro` | IT (Entra ID) | fachlicher Data Owner |
| 2b | **Eingeschränkt** sehen (bestimmte Kostenstellen, Konten …) | „Kostenstellen 2030, 2040; alle Konten“ | Jira-Ticket | fachlicher Data Owner; Umsetzung durch den Betrieb |
| 3 | **Personenbezogene Spalten** im Klartext | Namen in der Personaldimension | Jira-Ticket (eigenes) | fachlicher Data Owner |

Bei eingeschränktem Zugriff (2b) immer **beide Achsen** angeben, z. B. Kostenstellen *und* Konten — auf der Achse ohne Einschränkung lautet das Recht „alles“. Fehlt eine Achse, bleibt der Bericht leer. Ablauf auf Betriebsseite: [Berechtigung vergeben](../03-system/security/05-berechtigung-vergeben.md).

Änderungen wirken nach dem nächsten dbt-Lauf bzw. nach **Ab- und wieder Anmelden** (Gruppenmitgliedschaften stehen im Anmelde-Token).

## Power BI und andere BI-Tools

- Berichte greifen per **DirectQuery mit SSO** auf die `_v`-Views zu: Jeder sieht genau das, was ihm die Datenbank unter seinem eigenen Konto zeigt.
- Import-Modelle oder ein technisches Konto hebeln die Zeilenfilter aus — sie sind für gefilterte Daten nicht zulässig.
- Geteilte Berichte zeigen jedem Leser seine eigenen Zahlen. Unterschiedliche Summen bei Kolleginnen und Kollegen sind deshalb kein Fehler.

## Selbst prüfen

In SSMS, Azure Data Studio oder VS Code (angemeldet mit deinem Entra-Konto):

```sql
SELECT ORIGINAL_LOGIN() AS mein_login;                       -- dieser Name steht in den Einzelrechten
SELECT IS_MEMBER('<gruppen-prefix>-finance-employees-ro');   -- 1 = Mitglied
SELECT COUNT(*) FROM mart_finance.fakt_buchungen_v;          -- 0 = Zeilenrecht fehlt
```

## Häufige Fragen

**Ich sehe 0 Zeilen oder weniger als erwartet.** Zeilenrecht fehlt oder ist zu eng — oft auf der zweiten Achse. Gruppenmitgliedschaft prüfen (IT), sonst Ticket mit Screenshot und Uhrzeit.

**Eine Spalte zeigt nur `***`.** Spaltenmaskierung, kein Fehler. Freigabe per Ticket (3).

**Fehlermeldung „permission denied“.** Gruppe aus Schritt 1 fehlt oder die Anmeldung ist älter als die Gruppenaufnahme — ab- und wieder anmelden.

**In Power BI sehen alle dasselbe oder niemand etwas.** SSO der Datenquelle ist nicht aktiv bzw. der Bericht läuft unter einem technischen Konto — BI-Administration informieren.

**Ich brauche Rohdaten aus dem Vault.** Nicht für Endanwender vorgesehen. Fachliche Anforderung als Ticket; es wird eine passende Mart-View gebaut.

---

◀ [Daten prüfen](08-daten-pruefen.md) · [Übersicht](00-benutzerhandbuch.md) · [Best Practices](10-best-practices.md) ▶
