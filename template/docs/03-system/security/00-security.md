---
title: "Security"
aliases:
  - "Security"
  - "Security: Berechtigungen im Data Vault"
tags:
  - system/security
  - typ/inhaltsverzeichnis
---
[Dokumentation](../../README.md) › [Data Vault 2.1 – Systemdokumentation](../00-systemdokumentation.md)

# Security: Berechtigungen im Data Vault

Wie der Zugriff auf die Mart-Daten geregelt ist — **wer** welche Objekte sieht (OLS), **welche Zeilen** darin (RLS) und **welche Spalten** (CLS).

## Wo anfangen?

| Du willst … | Lies |
|---|---|
| in 5 Minuten verstehen, wie es funktioniert | [01 – Überblick](01-ueberblick.md) |
| **jemandem eine Berechtigung geben** | [05 – Berechtigung vergeben](05-berechtigung-vergeben.md) |
| ein neues Mart-Objekt absichern | [06 – Neues Objekt absichern](06-neues-objekt-absichern.md) |
| prüfen, ob eine Berechtigung wirklich greift | [07 – Verifizieren](07-verifizieren.md) |
| wissen, warum jemand 0 Zeilen sieht | [10 – Fallstricke](10-fallstricke.md) |
| nach test/prod ausrollen | [09 – Betrieb & Rollout](09-betrieb-rollout.md) |

## Alle Kapitel

| # | Kapitel | Inhalt |
|---|---|---|
| 01 | [Überblick](01-ueberblick.md) | Drei Schichten, drei Grundentscheidungen, Objektlandkarte |
| 02 | [Das `sec`-Schema](02-sec-schema.md) | Die drei Berechtigungstabellen und die Prüffunktion |
| 03 | [OLS – Objektzugriff](03-ols-view-grants.md) | Nur Views berechtigen, Grants per dbt-Hook, Gruppenmodell |
| 04 | [RLS – Zeilenfilter](04-rls-dimensional.md) | Filter auf der Dimension, Pfad-Schlüssel, mehrere Achsen |
| 05 | [Berechtigung vergeben](05-berechtigung-vergeben.md) | **Der Arbeitsablauf**, Schritt für Schritt |
| 06 | [Neues Objekt absichern](06-neues-objekt-absichern.md) | Für Modellentwickler |
| 07 | [Verifizieren](07-verifizieren.md) | Testuser, Prüfprotokoll, Dauertests |
| 08 | [CLS & Verschlüsselung](08-cls-und-verschluesselung.md) | Spalten-Maskierung, Schutz-Tiering |
| 09 | [Betrieb & Rollout](09-betrieb-rollout.md) | Deployment, Umgebungen, Audit |
| 10 | [Fallstricke](10-fallstricke.md) | Was schiefgeht — und warum |

## Für andere Zielgruppen

- **Endnutzer:** [Datenzugriff & Berechtigungen](../../01-benutzer/09-datenzugriff-berechtigungen.md)
- **Modellentwickler (Kurzfassung):** [Security in Mart-Models](../../02-entwickler/04-objekte-anlegen/mart/03-security-rls-cls.md)
- **Betrieb:** [security/DEPLOYMENT.md](../../../security/DEPLOYMENT.md)
- **Messwerte & Begründungen:** [Lessons Learned – RLS](../../lessons-learned/03-row-level-security-native-security-policy.md)
