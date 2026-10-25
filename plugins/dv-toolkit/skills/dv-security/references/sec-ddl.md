# sec-Schema: Tabellen und Prüffunktion

Wird **manuell deployed** (SSMS, dev → test → prod), nicht über dbt. Grund: ein dbt-Seed
oder -Model würde produktive Berechtigungszeilen bei jedem Run überschreiben. Azure-SQL-
kompatibel (kein `USE`, keine Cross-DB-Referenzen), idempotent.

## Drei Tabellen — wozu welche

| Tabelle | beantwortet | Pflege |
|---|---|---|
| `sec_user_privilege` | Wer darf was — eine Person | in der DB, eine Zeile je Person und Achse |
| `sec_group_privilege` | Nur was — eine Verzeichnisgruppe | Mitgliedschaft im Verzeichnis, eine Zeile je Gruppe |
| `sec_special_user_privilege` | Ausnahme: Filter gilt gar nicht | nur Service-User und Security-Admins |

Der Unterschied zwischen den ersten beiden ist allein, **wo die Mitgliedschaft gepflegt
wird**. Gruppenrechte sind der Regelfall, weil On-/Offboarding dann ohne SQL läuft.

```sql
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'sec') EXEC('CREATE SCHEMA sec');
GO

CREATE TABLE sec.sec_user_privilege (
    sec_user_privilege_key INT IDENTITY(1,1) PRIMARY KEY,
    user_name        NVARCHAR(255) NOT NULL,   -- UPN bzw. Login-Name, Matching via ORIGINAL_LOGIN()
    security_context NVARCHAR(100) NOT NULL,   -- die Achse, z. B. '<domain>_<achse>'
    sec_value_key    NVARCHAR(500) NOT NULL,   -- Pfad-Schluessel, siehe SKILL.md
    valid_from       DATETIME2(0)  NULL,
    valid_to         DATETIME2(0)  NULL,
    description      NVARCHAR(500) NULL,
    created_at       DATETIME2(0)  NOT NULL DEFAULT SYSUTCDATETIME(),
    created_by       NVARCHAR(255) NOT NULL DEFAULT ORIGINAL_LOGIN()
);
CREATE NONCLUSTERED INDEX ix_sec_user_privilege_user_context
    ON sec.sec_user_privilege (user_name, security_context)
    INCLUDE (sec_value_key, valid_from, valid_to);
GO

CREATE TABLE sec.sec_group_privilege (
    sec_group_privilege_key INT IDENTITY(1,1) PRIMARY KEY,
    group_name       NVARCHAR(255) NOT NULL,   -- Name des Verzeichnis-Principals
    security_context NVARCHAR(100) NOT NULL,
    sec_value_key    NVARCHAR(500) NOT NULL,
    description      NVARCHAR(500) NULL,
    created_at       DATETIME2(0)  NOT NULL DEFAULT SYSUTCDATETIME(),
    created_by       NVARCHAR(255) NOT NULL DEFAULT ORIGINAL_LOGIN()
);
CREATE NONCLUSTERED INDEX ix_sec_group_privilege_context
    ON sec.sec_group_privilege (security_context) INCLUDE (group_name, sec_value_key);
GO

CREATE TABLE sec.sec_special_user_privilege (
    sec_special_user_privilege_key INT IDENTITY(1,1) PRIMARY KEY,
    user_name        NVARCHAR(255) NOT NULL,
    security_context NVARCHAR(100) NULL,       -- NULL bei no_sec = 1
    no_sec           TINYINT       NOT NULL CHECK (no_sec IN (1, 2)),
    description      NVARCHAR(500) NULL,
    created_at       DATETIME2(0)  NOT NULL DEFAULT SYSUTCDATETIME(),
    created_by       NVARCHAR(255) NOT NULL DEFAULT ORIGINAL_LOGIN()
);
CREATE NONCLUSTERED INDEX ix_sec_special_user_privilege_user
    ON sec.sec_special_user_privilege (user_name) INCLUDE (security_context, no_sec);
GO
```

Schreibzugriff auf alle drei Tabellen auf Service-User und DB-Administratoren beschränken.

## Prüffunktion

**Inline-TVF mit `SCHEMABINDING`** — eine skalare Funktion wäre hier ein Performance-Fehler
(zeilenweise Ausführung ohne Inlining).

```sql
CREATE OR ALTER FUNCTION sec.fn_check_rls
(
    @sec_value_key    NVARCHAR(500),
    @security_context NVARCHAR(100)
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
SELECT 1 AS is_allowed
WHERE
    -- (1) Global-Bypass: Service-User, Security-Admins
    EXISTS (SELECT 1 FROM sec.sec_special_user_privilege sp
            WHERE sp.user_name = ORIGINAL_LOGIN() AND sp.no_sec = 1)
    -- (2) Bypass innerhalb einer Achse
    OR EXISTS (SELECT 1 FROM sec.sec_special_user_privilege sp
               WHERE sp.user_name = ORIGINAL_LOGIN() AND sp.no_sec = 2
                 AND sp.security_context = @security_context)
    -- (3) Einzelrecht, hierarchisch per Prefix, mit Gueltigkeitszeitraum
    OR EXISTS (SELECT 1 FROM sec.sec_user_privilege up
               WHERE up.user_name = ORIGINAL_LOGIN()
                 AND up.security_context = @security_context
                 AND (@sec_value_key = up.sec_value_key
                      OR @sec_value_key LIKE up.sec_value_key + N'||%')
                 AND (up.valid_from IS NULL OR up.valid_from <= SYSUTCDATETIME())
                 AND (up.valid_to   IS NULL OR up.valid_to   >= SYSUTCDATETIME()))
    -- (4) Gruppenrecht
    OR EXISTS (SELECT 1 FROM sec.sec_group_privilege gp
               WHERE gp.security_context = @security_context
                 AND (@sec_value_key = gp.sec_value_key
                      OR @sec_value_key LIKE gp.sec_value_key + N'||%')
                 AND IS_MEMBER(gp.group_name) = 1);
GO
```

**`ORIGINAL_LOGIN()`, nicht `USER_NAME()`.** Meldet sich ein User über Gruppen­mitgliedschaft
an (die Gruppe ist der DB-Principal), liefert `USER_NAME()` den *Gruppennamen* — Einzelrechte
wären damit unbrauchbar. `ORIGINAL_LOGIN()` liefert den tatsächlichen Login, bei
SQL-Auth wie bei Verzeichnis-Auth. Nebeneffekt: stabil unter `EXECUTE AS`, weshalb sich
Impersonation nicht zum Testen eignet.

Die vier Zweige sind mit **`OR`** verknüpft: ein pauschales Gruppenrecht auf den Wurzelwert
hebt jede Einzeleinschränkung auf. Wer eingeschränkt werden soll, darf nicht in der
Gruppe mit dem Wurzelrecht sein.

## Pflicht-Baseline vor der ersten Absicherung

```sql
INSERT INTO sec.sec_special_user_privilege (user_name, security_context, no_sec, description)
VALUES (N'<service-user>', NULL, 1, N'ETL/dbt-Service-User — Bypass');
```

Fehlt diese Zeile, liefern Builds und Tests **leere Ergebnisse ohne Fehlermeldung**. Per
Test überwachen (`references/verification.md`).

## Column Level Security

Keine native CLS auf SQL Server. Umsetzung in der View: sensible Spalten werden maskiert,
wenn der User keinen Eintrag für den Kontext hat. Binäre Variante der Prüffunktion:

```sql
CREATE OR ALTER FUNCTION sec.fn_check_cls (@security_context NVARCHAR(100))
RETURNS TABLE WITH SCHEMABINDING AS
RETURN SELECT 1 AS is_allowed
WHERE EXISTS (SELECT 1 FROM sec.sec_special_user_privilege sp
              WHERE sp.user_name = ORIGINAL_LOGIN() AND sp.no_sec = 1)
   OR EXISTS (SELECT 1 FROM sec.sec_user_privilege up
              WHERE up.user_name = ORIGINAL_LOGIN() AND up.security_context = @security_context)
   OR EXISTS (SELECT 1 FROM sec.sec_group_privilege gp
              WHERE gp.security_context = @security_context AND IS_MEMBER(gp.group_name) = 1);
GO
```

Regel dazu: **maskierungspflichtige Spalten gehören nicht in physische Mart-Tabellen** —
nur in Views oder gar nicht in den Mart.
