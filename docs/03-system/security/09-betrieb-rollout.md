---
title: "Betrieb & Rollout"
tags:
  - system/security
---
[Dokumentation](../../README.md) › [Data Vault 2.1 – Systemdokumentation](../00-systemdokumentation.md) › [Security](00-security.md)

# Betrieb & Rollout

## Wer deployt was

| Artefakt | Wo | Von wem |
|---|---|---|
| `sec`-Schema, Tabellen, Prüffunktionen | SSMS, manuell | DB-Admin |
| Entra-Gruppen als DB-User | SSMS, **Entra-authentifiziert** | Entra-Admin |
| Berechtigungszeilen (`sec_*`) | SSMS, manuell | DB-Admin nach Freigabe |
| View-Grants | `dbt run` (`on-run-end`-Hook) | automatisch |
| Filter in Models, Schlüsselspalten | `dbt run` | automatisch |

> **Security-DDL läuft bewusst nicht über dbt.** Ein Seed oder Model würde produktive Berechtigungszeilen bei jedem Run überschreiben. Zusätzlich blockiert ein Werkzeugfilter `DROP SECURITY POLICY` und ähnliche DDL auch bei explizitem Approval — solche Schritte führt der Mensch aus.

## Reihenfolge beim Erst-Rollout

Vollständiges Runbook: [security/DEPLOYMENT.md](../../../security/DEPLOYMENT.md).

```
1. ddl/01_schema_sec.sql          Schema + drei Tabellen
2. ddl/02_fn_check_rls.sql        Prüffunktion RLS
3. ddl/03_fn_check_cls.sql        Prüffunktion CLS
4. privileges/insert_sec_special_user_privilege.sql
                                  ⚠️ Service-User-Ausnahme — VOR allem anderen
5. ols/users/create_user_entra_groups.sql
                                  Entra-Gruppen als DB-User (Entra-Admin!)
6. ols/ols_*.sql                  Alte Schema-Grants zurücknehmen + View-Grants
7. dbt run                        Hook setzt die View-Grants
8. privileges/insert_sec_*.sql    Die eigentlichen Berechtigungen
9. dbt test -s tests/security     Muss grün sein
```

Schritt 4 ist der kritische: Fehlt die Service-User-Ausnahme, liefern alle folgenden dbt-Läufe und Tests **leere Ergebnisse ohne Fehlermeldung**.

## Umgebungen

| Target | Datenbank | Stand (je Projekt pflegen) |
|---|---|---|
| `<mandant>-dev` | `datavault-dev` | ⬜ ausstehend |
| `<mandant>-test` | `datavault-test` | ⬜ ausstehend |
| `<mandant>` | `datavault` | ⬜ ausstehend |

Für test/prod sind alle neun Schritte zu wiederholen. Die Berechtigungszeilen sind umgebungsspezifisch — der Testuser `rls_test` gehört **nicht** nach prod.

## Power BI — Betriebsvoraussetzung

> **Ohne Entra-SSO-Passthrough wirkt die ganze RLS nicht.** Der Power-BI-Service verbindet sich dann mit einem festen Principal, und alle Report-Nutzer sehen dieselben Zeilen — nämlich die des Verbindungs-Users.

Zu prüfen:

- [ ] Datenquelle auf **DirectQuery** (bei Import greift DB-seitige RLS gar nicht)
- [ ] SSO-Passthrough auf der Gateway-/Cloud-Verbindung aktiviert
- [ ] Mit **zwei** Test-Nutzern unterschiedlicher Rechte geöffnet — die Zeilenzahlen müssen sich unterscheiden

## Laufender Betrieb

### Grant-Audit

```sql
SELECT pr.name AS principal, pe.class_desc, pe.permission_name,
       COALESCE(s3.name, s1.name + '.' + o.name) AS objekt, o.type_desc
FROM sys.database_permissions pe
JOIN sys.database_principals pr ON pr.principal_id = pe.grantee_principal_id
LEFT JOIN sys.schemas s3 ON pe.class = 3 AND s3.schema_id = pe.major_id
LEFT JOIN sys.objects o  ON pe.class = 1 AND o.object_id  = pe.major_id
LEFT JOIN sys.schemas s1 ON s1.schema_id = o.schema_id
WHERE pr.name NOT IN ('public', 'dbo', 'guest') AND pe.permission_name = 'SELECT';
```

Erwartung: ausschließlich `OBJECT_OR_COLUMN` auf `type_desc = VIEW`. Keine Zeile mit `SCHEMA`, keine mit `USER_TABLE`. Automatisiert im Test `assert_only_views_granted_in_mart`.

### Wer hat welche Rechte?

```sql
SELECT user_name, security_context, sec_value_key, description, created_at, created_by
FROM sec.sec_user_privilege
ORDER BY user_name, security_context;
```

### Wirken alle Rechte?

Ein Recht, dessen Schlüssel keine Dimension trifft, bewirkt still nichts — die Abfrage dazu steht in [05 – Berechtigung vergeben](05-berechtigung-vergeben.md#schritt-4-prüfen-dass-das-recht-nicht-ins-leere-läuft).

## Änderungen an den Dimensionen

Zwei Fälle brauchen Aufmerksamkeit:

**Neue Kostenstelle / neues Konto.** Liegt sie in einem bereits berechtigten Bereich, ist sie durch die Prefix-Logik automatisch abgedeckt — kein Eingriff nötig. Das ist der Vorteil des Pfad-Schlüssels.

**Umbenannte Hierarchiestufe.** Der Schlüssel enthält das Label (`<mandant>||3 Vertrieb`). Wird der Bereich im Sharepoint umbenannt, greifen bestehende Rechte nicht mehr — und zwar **still**. Nach Stammdatenänderungen deshalb die Prüfabfrage aus Schritt 4 laufen lassen.

---

◀ [Fallstricke](10-fallstricke.md) · [Übersicht](00-security.md) · [Das sec-Schema](02-sec-schema.md) ▶
