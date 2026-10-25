---
title: "Deployment Workflow"
tags:
  - entwickler
---
[Dokumentation](../README.md) › [Data Vault 2.1 – Developer Guide](00-entwicklerhandbuch.md)

# Deployment Workflow

Wie eine Änderung vom lokalen Rechner in die Produktion kommt: Git-Branches, Merge Request, Review, fachliche Abnahme, Pipelines und Release. Technische Details der Pipeline-Jobs: [CI/CD Pipeline](../03-system/allgemein/10-ci-cd-pipeline.md).

## Branches und Umgebungen

```
feat/<thema> ──MR──► dev ──MR──► test ──MR──► main ──Tag vX.Y.Z──► Produktion
                      │           │             │
                  Dev-DB       Test-DB       (Freigabe)
                automatisch   manuell /     automatisch
                              ADF-Trigger   beim Tag
```

| Branch | Zweck | Datenbank / Target | Deployment | Direkt pushen? |
|--------|-------|--------------------|------------|----------------|
| `feat/<thema>`, `fix/<thema>` | Entwicklung einer Änderung | lokal gegen Dev | — | ja (eigener Branch) |
| `dev` | Integration aller Änderungen | `<datenbank>-dev` / `<mandant>-dev` | automatisch nach Merge | nein, nur per MR |
| `test` | Fachliche Abnahme | `<datenbank>-test` / `<mandant>-test` | manuell bzw. automatisch nach Quell-Load | nein, nur per MR |
| `main` | Produktionsstand | `<datenbank>` / `<mandant>` | beim Release-Tag `v*` | nein, nur per MR |

Branches `dev`, `test` und `main` sind geschützt (Push nur per Merge Request, Merge nur mit Freigabe und grüner Pipeline).

## Ablauf einer Änderung

### 1. Auftrag und Branch

- Jede Änderung hat ein Ticket (Jira/Issue) mit fachlicher Anforderung und Akzeptanzkriterien.
- Branch vom aktuellen `dev`:

  ```bash
  git switch dev && git pull
  git switch -c feat/<thema>
  ```

### 2. Entwickeln und lokal prüfen

```bash
dbt build --select +<geänderte_modelle>+           # bauen + testen gegen Dev
dbt compile --select <modell>                      # erzeugtes SQL lesen
dbt test --exclude tag:nightly path:models/staging # entspricht der MR-Validierung
```

> [!WARNING]
> Die Dev-Datenbank ist **gemeinsam**. Ein lokaler `dbt run` überschreibt die Objekte für alle. Nur die eigenen Modelle selektieren, nie `--full-refresh` auf Vault-Tabellen, Umbenennungen und Löschungen vorher abstimmen.

Zu jeder Änderung gehören: Modell-YAML (Beschreibung, Spalten, Tests), Design-Diagramm unter `design/` (Skill `dv-design-sync`), Doku-Kapitel falls betroffen und ein [Changelog](../changelog.md)-Eintrag.

### 3. Commit und Push

Commit-Nachrichten nach Conventional Commits, Deutsch, im Imperativ bzw. Nominalstil:

```
<typ>(<bereich>): <kurzbeschreibung>

<optional: Warum, Auswirkungen, Migrationshinweise, Ticket>
```

| Typ | Verwendung |
|-----|-----------|
| `feat` | neues Objekt, neue Quelle, neue Spalte |
| `fix` | Fehlerbehebung in Modell, Macro, Pipeline |
| `refactor` | Umbau ohne fachliche Änderung |
| `docs` | nur Dokumentation |
| `test` | nur Tests |
| `chore` | Konfiguration, Abhängigkeiten, Aufräumen |
| `!` nach dem Typ | Breaking Change (z. B. Full Refresh nötig, Spalte entfällt) |

```bash
git add models/… docs/… design/…
git commit -m "feat(crm): hub_auftrag, sat_auftrag__crm und link_auftrag_kunde"
git push -u origin feat/<thema>
```

### 4. Merge Request nach `dev`

Beschreibung des Merge Requests:

| Abschnitt | Inhalt |
|-----------|--------|
| Was / Warum | Ticket, fachlicher Zweck |
| Objekte | neue/geänderte Modelle, Schemas |
| Datenwirkung | neue Versionen im Satellite? Full Refresh nötig? Laufzeit? |
| Prüfung | ausgeführte Prüfabfragen und Ergebnis (Zeilenzahlen, Eindeutigkeit) |
| Checkliste | [Checklisten → Pre-Merge](08-checklisten.md) abgehakt |

Automatisch läuft die **CI-Validierung** gegen die Dev-Datenbank: `stage_external_sources` → `dbt compile` → `dbt test` (ohne `tag:nightly` und Staging-Tests). Ein Merge ist nur mit grüner Pipeline möglich.

**Review** (mindestens eine zweite Person, „Vier-Augen-Prinzip“) prüft:

- DV-Regeln: Business Key, Hash Diff = Payload, keine Lineage im Hash Diff, Post-Hooks
- Namenskonventionen, Schema, Tags
- Tests und YAML vollständig, Doku/Changelog/Design nachgezogen
- Security bei Mart-Objekten: nur `_v`-Views publiziert, RLS/CLS angewendet
- Datenwirkung: kein unbeabsichtigter Full Refresh, keine Historienverluste

Merge-Art: **Squash** für Feature-Branches (ein Commit je Änderung auf `dev`). Nach dem Merge deployt die Pipeline automatisch nach Dev (`stage_external_sources` → `dbt run` → `dbt test`) und der Feature-Branch wird gelöscht.

### 5. Promotion nach `test` und fachliche Abnahme

- Merge Request `dev` → `test` (gesammelte Änderungen, Titel mit Kurzliste). Merge-Art: **Merge Commit**, damit die Historie der einzelnen Änderungen erhalten bleibt.
- Deployment nach Test: manuell per Pipeline-Button oder automatisch mit dem nächsten Quell-Load (ADF-Übergabe, siehe [CI/CD](../03-system/allgemein/10-ci-cd-pipeline.md)).
- **Fachliche Abnahme** durch den Fachbereich in der Test-Umgebung: Berichte bzw. Views gegen Akzeptanzkriterien und Vergleichszahlen (Quellsystem, Altbericht) prüfen. Ergebnis im Ticket festhalten (Abnahme erteilt / Mängel). Ohne Abnahme keine Produktion.

### 6. Release nach Produktion

1. Merge Request `test` → `main`; Freigabe durch fachlichen Verantwortlichen **und** technisch Verantwortlichen.
2. Release-Tag setzen (Semantic Versioning):

   ```bash
   git switch main && git pull
   git tag -a v1.5.0 -m "Release 1.5.0: <Kurzliste>"
   git push origin v1.5.0
   ```

   | Stelle | Wann erhöhen |
   |--------|--------------|
   | MAJOR | Breaking Change: Full Refresh, entfallene Objekte/Spalten, Schema-Umbau |
   | MINOR | neue Objekte, Quellen, Spalten |
   | PATCH | Fehlerbehebungen ohne Strukturänderung |

3. Der Tag startet das Produktions-Deployment. Danach: Pipeline-Ergebnis und `vault.load_status` prüfen, Changelog-Einträge mit der Version versehen.

## Standard-Pipelines

| Auslöser | Was läuft | GitLab (`.gitlab-ci.yml`) | GitHub Actions (`.github/workflows/`) |
|----------|-----------|---------------------------|----------------------------------------|
| Merge/Pull Request | Validierung: External Tables, compile, test (ohne nightly) | `ci:validate` | `ci.yml` |
| Merge nach `dev` | Deploy Dev: External Tables, run, test | `deploy:dev` | Deploy-Workflow `dev` |
| Button / Push auf `test` | Deploy Test | `deploy:test` | Deploy-Workflow `test` |
| Zeitplan alle 30 Min. | Deploy Test, nur wenn ein neuer Quell-Load vorliegt | `deploy:test:adf-triggered` | — |
| Tag `v*` | Deploy Produktion | `deploy:prod` | Deploy-Workflow `prod` |
| Button, mit Bestätigung | Full Refresh je Umgebung | `deploy:<env>:full-refresh` | manueller Workflow |
| Button | Massendaten-Domäne laden | `deploy:<env>:<domain>-load` | manueller Workflow (`dbt-load`) |
| Zeitplan nachts | Langsame Tests (`tag:nightly`, Staging) | `ci:nightly-tests` | geplanter Workflow |
| Push auf `main` | dbt-Doku veröffentlichen | — | `docs.yml` |

Welche davon im Repository aktiv sind, steht im Kapitel [CI/CD Pipeline](../03-system/allgemein/10-ci-cd-pipeline.md). Alle Deploy-Jobs einer Umgebung laufen nacheinander (Resource Group bzw. Concurrency), nie parallel.

## Freigaben im Überblick

| Schritt | Wer gibt frei | Wo dokumentiert |
|---------|---------------|-----------------|
| Merge nach `dev` | Reviewer (Entwicklung) | Merge Request |
| Deployment nach Test | Entwicklung | Pipeline |
| Fachliche Abnahme | Fachbereich / Data Owner | Ticket |
| Merge nach `main` + Release | fachlich **und** technisch Verantwortliche | Merge Request, Tag |
| Full Refresh (jede Umgebung) | technisch Verantwortliche, bei Prod zusätzlich Fachbereich | Ticket + Bestätigungsvariable |
| Neue Berechtigungen | Data Owner | Ticket ([Berechtigung vergeben](../03-system/security/05-berechtigung-vergeben.md)) |

## Sonderfälle

**Hotfix** (Fehler in Produktion, der nicht warten kann): Branch `fix/<thema>` von `main`, Merge Request direkt nach `main` mit Freigabe, Patch-Tag (`v1.5.1`). Danach `main` in `test` und `dev` zurückführen, damit der Fix nicht verloren geht.

**Full Refresh:** nur als eigener, bestätigter Job. Empfohlen (Referenzumsetzung in GitLab): der Job verlangt eine Variable `CONFIRM_FULL_REFRESH=<jobname>@<heutiges Datum UTC>` und bricht ohne sie ab. Vorher klären, welche Historie verloren geht (Quelle liefert nur den aktuellen Stand?).

**Rollback:** Code per `git revert` auf dem betroffenen Branch zurücknehmen und neu deployen. Daten im Raw Vault sind insert-only — falsch geladene Versionen bleiben stehen und werden durch die nächste korrekte Version abgelöst; ein Entfernen ist ein abgestimmter Eingriff mit Ticket. Mart-Objekte werden beim nächsten Lauf neu gebaut.

**Manuelles Deployment** (Ausnahme, z. B. Pipeline-Störung):

```bash
dbt run-operation stage_external_sources --target <mandant>-test
dbt seed  --target <mandant>-test
dbt run   --target <mandant>-test
dbt test  --target <mandant>-test --exclude tag:nightly path:models/staging
```

## Neue Umgebung aufsetzen

1. Azure-Ressourcen: SQL Server/Datenbank, Storage, Firewall (Infrastruktur-Skripte bzw. `infra/`), Entra-Gruppen für OLS.
2. Datenbank-Grundlagen: Schemas, Credential, External Data Source `StageFileSystem`, File Format `ParquetFormat` (`scripts/`).
3. Security-Fundament **vor** dem ersten `dbt run`: `security/ddl/01–03`, Dienstbenutzer-Ausnahme, Gruppenrechte (`security/DEPLOYMENT.md`).
4. Target im Profil und in den CI-Variablen anlegen.
5. Erstbefüllung:

   ```bash
   dbt deps
   dbt run-operation stage_external_sources --target <target>
   dbt seed --target <target>
   dbt run  --target <target>
   dbt run --select tag:<domain> --target <target>      # je Massendaten-Domäne
   dbt run-operation insert_ghost_records --target <target>
   dbt test --target <target>
   ```

6. Zeitpläne (Nightly, ADF-Übergabe) in der Pipeline einrichten.

---

◀ [Tests](05-tests.md) · [Übersicht](00-entwicklerhandbuch.md) · [Troubleshooting](07-troubleshooting.md) ▶
