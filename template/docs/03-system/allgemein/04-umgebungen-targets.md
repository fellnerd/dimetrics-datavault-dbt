---
title: "Umgebungen & Targets"
tags:
  - system
---
[Dokumentation](../../README.md) › [Data Vault 2.1 – Systemdokumentation](../00-systemdokumentation.md)

# Umgebungen & Targets

### 4.1 Multi-Mandanten-Architektur

```
┌─────────────────────────────────────────────────────────┐
│              Git Repo: datavault-dbt                    │
│              (Ein Projekt für alle Mandanten)           │
├─────────────────────────────────────────────────────────┤
│  Target: <mandant>-dev │ <mandant>-test │ <mandant>     │
└──────────┬─────────────┴────────┬────────┴──────┬───────┘
           ▼                      ▼               ▼
   ┌───────────────┐      ┌───────────────┐  ┌───────────┐
   │ datavault-dev │      │ datavault-test│  │ datavault │
   │ Entwicklung   │      │ Test/Abnahme  │  │ Produktion│
   └───────────────┘      └───────────────┘  └───────────┘
```

Die Trennung erfolgt auf zwei Ebenen: eine Datenbank pro Mandant und Umgebung (stärkste Isolation) und zusätzlich ein Mandanten-Segment im `dss_sec_value_key`, abgeleitet über das Macro `tenant_key()` aus dem Target-Namen (siehe [Sicherheit](07-sicherheit.md)).

### 4.2 Target-Konvention

| Target | Datenbank | Verwendung |
|--------|-----------|------------|
| `<mandant>-dev` | Dev-Datenbank | Entwicklung, CI-Validierung von Merge Requests |
| `<mandant>-test` | Test-Datenbank | Abnahme, ADF-getriggerte Läufe |
| `<mandant>` | Produktions-Datenbank | Produktion, nur über Tag oder manuelle Freigabe |

Die Verbindung wird über `profiles.yml` definiert (Profil `datavault`, Adapter `sqlserver`); in der Pipeline wird die Datei aus CI-Variablen erzeugt. Lokal liegt sie in `~/.dbt/` ausserhalb des Repositories. Welche Targets ein Mandant hat, steht in seiner Dokumentation.
