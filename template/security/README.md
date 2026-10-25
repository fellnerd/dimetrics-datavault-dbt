# Security-Skripte (manuelle Ausführung in SSMS)

Versionierte DB-Security-Artefakte für die Tenant-Datenbanken (z. B. `datavault`, `datavault-dev`, `datavault-test`, …).
Vollständige Architektur: [docs/03-system/security/](../docs/03-system/security/00-security.md)
**Deployment-Anleitung (Schritt für Schritt): [DEPLOYMENT.md](DEPLOYMENT.md)**

## Ausführungsreihenfolge (pro Tenant-Datenbank)

| # | Skript | Zweck | Ausführender |
|---|---|---|---|
| 1 | `ddl/01_schema_sec.sql` | Schema `sec` + 3 Berechtigungstabellen | DB-Admin (beliebige Auth) |
| 2 | `ddl/02_fn_check_rls.sql` | RLS-Prüffunktion | DB-Admin |
| 3 | `ddl/03_fn_check_cls.sql` | CLS-Prüffunktion | DB-Admin |
| 4 | `privileges/insert_sec_special_user_privilege.sql` | **Baseline: dbt-Service-User `no_sec=1`** — zwingend vor der ersten Security Policy! | DB-Admin |
| 5 | `ols/users/create_user_entra_groups.sql` | Entra-Gruppen als DB-User | **Entra-authentifizierter Admin** (nicht SQL-Auth!) |
| 6 | `ols/ols_*.sql` | Alte Schema-GRANTs zurücknehmen + **SELECT auf alle Views** der zugeordneten Mart-Schemas | DB-Admin |
| 7 | `privileges/insert_sec_group_privilege.sql` | RLS-Werte pro Gruppe | DB-Admin |
| 8 | `privileges/insert_sec_user_privilege.sql` | Einzelrechte (nur nach Freigabe) | DB-Admin |

Alle Skripte sind idempotent (`IF NOT EXISTS` / `CREATE OR ALTER`) und Azure-SQL-kompatibel (kein `USE`, keine Cross-DB-Referenzen).

> **Schritt 6 ist nur das Erst-Deployment.** Im laufenden Betrieb setzt der dbt-Hook
> `grant_select_on_views()` (`on-run-end` in `dbt_project.yml`) dieselben Grants nach
> **jedem** Run neu — nötig, weil dbt Views jedes Mal neu erstellt und objektbezogene
> Rechte mit dem Objekt sterben. Die Zuordnung Principal → Schemas steht in
> `var('ols_view_grants')`; wird sie dort geändert, die `ols_*.sql` nachziehen.

## Grundregeln

- **Business-Grants nur auf `mart*`-Schemas** — niemals auf `stg`, `vault*` oder `sec`.
- **Nur Views werden berechtigt, niemals Schema-Grants.** `GRANT SELECT ON SCHEMA::mart_finance` würde die physischen Performance-Caches (`fakt_buchungen`, `dim_konto`, `dim_beleg`) mit freigeben. Die Grant-Schleife liest aus `sys.views` — eine Tabelle kann dadurch gar nicht getroffen werden.
- **Jeder physische Mart-Cache braucht eine `_v`-Wrapper-View** — sonst ist er für Konsumenten unerreichbar.
- **Objekt-Grants überleben keinen dbt-Run** — deshalb der `on-run-end`-Hook statt eines einmaligen Skripts.
- **dbt-Service-User-Exemption (`no_sec=1`) ist Pflicht-Baseline** — ohne sie liefern dbt-Tests und Downstream-Reads auf Policy-geschützten Tabellen leere Ergebnisse.
- Einzelrechte (`sec_user_privilege`) nur nach dokumentierter Freigabe (Jira-Ticket) durch den Data Owner; Standardweg ist die Gruppenberechtigung (`sec_group_privilege` + Entra-Mitgliedschaft).

## Verifikation

```bash
# Grants neu setzen (Log-Zeile "OLS: <n> View-Grants fuer <principal> gesetzt")
dbt run --target <ziel>

# Konvention pruefen: kein Schema-Grant, kein Grant auf einer Tabelle
dbt test -s assert_only_views_granted_in_mart --target <ziel>
```
