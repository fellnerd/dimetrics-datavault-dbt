# Prüfprotokoll

Berechtigungen gelten erst als umgesetzt, wenn sie **mit einem echten Test-Login** geprüft
wurden. `EXECUTE AS USER` taugt dafür nicht: die Prüffunktion matcht auf
`ORIGINAL_LOGIN()`, und das liefert unter Impersonation weiterhin den eigenen Login samt
Bypass — der Test bestünde fälschlich.

## Test-Login ohne Verzeichnis-Rechte

In Umgebungen, in denen keine Verzeichnis-Principals angelegt werden können, reicht ein
Contained User:

```sql
CREATE USER [<testuser>] WITH PASSWORD = '<passwort>';
```

`ORIGINAL_LOGIN()` liefert dafür den Usernamen — die Kette ist damit vollständig testbar,
ohne Verzeichnis. Was so getestet wird, gilt eins zu eins für Verzeichnis-Logins.

Dem Testuser **nichts** außer den Grants geben, die er laut Konzept haben soll. Der
Principal in `var('ols_view_grants')` eintragen, dann einmal `dbt run`.

### Passwörter

Nie im Repo, nie im Chat. Für automatisierte Prüfungen ein eigenes dbt-Target mit
Umgebungsvariable:

```yaml
    <target>-<testuser>:
      type: sqlserver
      # … wie das reguläre Target …
      authentication: sql
      user: <testuser>
      password: "{{ env_var('<TESTUSER>_PASSWORD') }}"
```

## Reihenfolge

### 1. Baseline vor der ersten Berechtigungszeile

```sql
SELECT COUNT(*) FROM <schema>.<gesicherte_view>;   -- 0 erwartet
```

Null Zeilen **ohne Fehler** beweist beides auf einmal: OLS greift (die View ist lesbar)
und RLS ist scharf (Deny-by-default). Ein Fehler stattdessen heißt: Grant fehlt.

### 2. OLS — physische Objekte müssen verweigert werden

```sql
SELECT COUNT(*) FROM <schema>.<physische_tabelle>;  -- Fehler erwartet
SELECT COUNT(*) FROM <staging_schema>.<objekt>;     -- Fehler erwartet
SELECT COUNT(*) FROM sec.sec_user_privilege;        -- Fehler erwartet
```

Erwartet: `The SELECT permission was denied on the object`.

### 3. RLS je Achse

Recht setzen, dann zählen. Erwartungswert vorher als Service-User bestimmen:

```sql
-- als Service-User, Sollwert ermitteln
SELECT COUNT(*) FROM <fakt> WHERE <achsen_spalte> = <wert>;
-- als Testuser, Istwert
SELECT COUNT(*) FROM <schema>.<fakt_view>;
```

Zusätzlich prüfen, dass die **Dimension** selbst gefiltert ist — das ist der schnellste
Check, ob ein Recht richtig sitzt:

```sql
SELECT COUNT(*) FROM <schema>.<dimension_view>;   -- genau die erlaubten Elemente
```

### 4. Hierarchie-Prefix

Recht auf eine Gruppe statt auf ein Detail setzen und prüfen, dass alle Elemente der
Gruppe erscheinen — ohne dass je Element eine eigene Zeile nötig war.

### 5. Mehrere Achsen

Auf einer Achse einschränken, auf der anderen den Wurzelwert lassen. Erwartung: Schnitt-
menge. Dann die zweite Achse einschränken und prüfen, dass sich das Ergebnis weiter
verkleinert.

Gegenprobe: das Recht auf der zweiten Achse **entfernen** → 0 Zeilen. Das beweist, dass
beide Joins wirklich filtern und nicht einer davon wirkungslos ist.

### 6. Ghost-/Plug-Zeilen

```sql
SELECT COUNT(*) FROM <schema>.<dimension_view> WHERE <plug_bedingung>;
```

Muss die volle Anzahl liefern, auch bei stark eingeschränktem User — sonst brechen
Zwischensummen im Report.

### 7. Vollzugriff unverändert

Als Service-User die Zeilenzahlen aller betroffenen Views gegen die Quelle vergleichen.
Weicht etwas ab, unterschlägt ein `INNER JOIN` Zeilen — Dimension unvollständig.

## Dauerhafte Tests

Drei Singular-Tests, die die Annahmen festhalten:

**Service-User-Ausnahme vorhanden** — fehlt sie, liefern Builds still leere Ergebnisse:

```sql
SELECT N'Service-User-Ausnahme fehlt fuer: ' + ORIGINAL_LOGIN() AS problem
WHERE NOT EXISTS (SELECT 1 FROM sec.sec_special_user_privilege
                  WHERE user_name = ORIGINAL_LOGIN() AND no_sec = 1)
```

**Nur Views berechtigt** — schlägt an bei Schema-Grants und bei Grants auf Tabellen:

```sql
SELECT pr.name AS principal, N'Schema-Grant' AS problem
FROM sys.database_permissions pe
JOIN sys.schemas s ON s.schema_id = pe.major_id
JOIN sys.database_principals pr ON pr.principal_id = pe.grantee_principal_id
WHERE pe.class = 3 AND pe.permission_name = 'SELECT' AND pe.state_desc = 'GRANT'
  AND s.name LIKE '<mart_prefix>%' AND pr.name NOT IN ('dbo', 'public')
UNION ALL
SELECT pr.name, N'Grant auf physischer Tabelle'
FROM sys.database_permissions pe
JOIN sys.objects o ON o.object_id = pe.major_id
JOIN sys.schemas s ON s.schema_id = o.schema_id
JOIN sys.database_principals pr ON pr.principal_id = pe.grantee_principal_id
WHERE pe.class = 1 AND o.type = 'U' AND pe.permission_name = 'SELECT'
  AND pe.state_desc = 'GRANT' AND s.name LIKE '<mart_prefix>%'
  AND pr.name NOT IN ('dbo', 'public')
```

**Dimension vollständig** — der `relationships`-Test auf dem Fremdschlüssel, mit
`severity: error`. Als `warn` wird genau dieser Fall übersehen; er äußert sich sonst nur
als fehlende Zeilen, die niemandem auffallen.

## Audit im Betrieb

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

Erwartung: ausschließlich `class_desc = OBJECT_OR_COLUMN` auf `type_desc = VIEW`.
