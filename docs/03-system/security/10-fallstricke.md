---
title: "Fallstricke"
tags:
  - system/security
---
[Dokumentation](../../README.md) › [Data Vault 2.1 – Systemdokumentation](../00-systemdokumentation.md) › [Security](00-security.md)

# Fallstricke

Das Gemeinsame an fast allen: **Security-Fehler zeigen sich nicht als Absturz, sondern als zu wenig oder zu viel Daten.** Deshalb muss jede Änderung gegen einen Sollwert geprüft werden, nicht nach Augenschein.

## Diagnose: Fehler oder null Zeilen?

| Symptom | Ebene |
|---|---|
| `The SELECT permission was denied` | **OLS** — Grant fehlt |
| 0 Zeilen, keine Fehlermeldung | **RLS** — Berechtigung fehlt oder ist zu eng |
| Spalte zeigt `***` | **CLS** — kein Eintrag für den Kontext |

## Die häufigsten Fälle

### Nutzer sieht 0 Zeilen trotz korrektem Recht

Ihm fehlt das Recht auf der **zweiten Achse**. Die Fakt-Views joinen zwei Dimensionen; wer nur auf `finance_konto` berechtigt ist, bekommt aus `dim_kostenstelle_v` null Zeilen und der Join schneidet alles weg.

```sql
-- Wer hat eine Achse vergessen?
SELECT user_name FROM sec.sec_user_privilege GROUP BY user_name
HAVING SUM(CASE WHEN security_context='finance_kst'   THEN 1 ELSE 0 END)=0
    OR SUM(CASE WHEN security_context='finance_konto' THEN 1 ELSE 0 END)=0;
```

### Recht eingetragen, wirkt aber nicht

Der Schlüssel trifft keine Dimension. Häufigste Ursache: das Label wurde aus der Matrix **abgetippt** statt aufgelöst.

> `6a Übriger Betriebsaufwand` (Matrix) ≠ `6a Uebriger Betriebsaufwand` (`dim_konto`) — bekannte Sharepoint-Encoding-Korrektur. Betraf 6 von 14 Nutzern.

Immer über die Dimension auflösen, bei Kontogruppen über `konto_l2_prefix`.

### Eingeschränkter Nutzer sieht plötzlich alles

Er ist in einer Gruppe mit `sec_group_privilege`-Zeile auf `<mandant>`. Die Prüffunktion verknüpft ihre Zweige mit **ODER** — ein Gruppenrecht hebt jede Einzeleinschränkung auf.

> **Gruppen können nur erweitern, nie einschränken.** Wer eingeschränkt werden soll, darf nicht in der `-all-ro`-Gruppe sein.

### Zeilen fehlen auch für Admins

Eine Dimension ist unvollständig, der `INNER JOIN` unterschlägt Faktzeilen. Trifft alle Nutzer, auch die mit Bypass.

```sql
SELECT COUNT(*) FROM <fakt> f
WHERE NOT EXISTS (SELECT 1 FROM <dimension> d WHERE d.<key> = f.<key>);
```

Deshalb `severity: error` auf den `relationships`-Tests — als `warn` blieben 936 Budget-Zeilen lange unbemerkt.

### Zwischensummen verschwinden im Report

Die Plug-Zeilen (`konto_key < 0`) werden mitgefiltert. Sie müssen immer durch:

```sql
WHERE konto_key < 0 OR {{ rls_filter('finance_konto') }}
```

### Test mit `EXECUTE AS` besteht, echter Login nicht

`ORIGINAL_LOGIN()` bleibt unter Impersonation der eigene Login — samt Bypass. Nur eine echte Anmeldung testet die Berechtigung.

### Rechte weg nach `dbt run`

Der Principal fehlt in `var('ols_view_grants')`. dbt erstellt Views neu, objektbezogene Rechte sterben mit dem Objekt; nur der Hook setzt sie wieder.

Im Log prüfen: `OLS: <n> View-Grants fuer <principal> gesetzt`.

### Neues Mart-Objekt ist für niemanden sichtbar

Es ist als `table` materialisiert und hat keine `_v`-Wrapper-View. Der Hook berechtigt nur Views.

### Marts plötzlich leer, ohne Fehler

Die Service-User-Ausnahme fehlt (`no_sec = 1`). Betrifft dbt-Läufe und alle Tests. Überwacht von `assert_dbt_service_user_exemption`.

### Alle Power-BI-Nutzer sehen dasselbe

SSO-Passthrough nicht aktiv, oder der Report läuft im Import-Modus. Siehe [09 – Betrieb](09-betrieb-rollout.md#power-bi--betriebsvoraussetzung).

## Performance-Fallstricke

### Der Filter liegt auf dem Fakt

Die Prüffunktion läuft pro Zeile — auf 900.000 Faktzeilen statt auf 157 Dimensionszeilen. Gemessener Unterschied: 3.697.737 gegenüber 31.069 logische Reads.

### Eine CTE soll doppelten View-Zugriff verhindern

Funktioniert nicht. **Benannte CTEs sind in SQL Server keine Materialisierungsgrenze** — sie werden beim Kompilieren entfaltet. Zweimal versucht, zweimal gescheitert:

- CTE-Isolation des Admin-Bypass in `fn_check_rls` → identisches Read-Verhältnis
- CTE um `ref_kostenstelle_v` in `dim_kostenstelle` → **schlechter** (1.938 → 2.654 Reads)

Wirksam ist nur echte Materialisierung.

### Träger-Dimension als View

Sie liegt auf dem kritischen Pfad jeder Fakt-Abfrage. Hängt sie an einer teuren Quelle (z.B. externe Parquet-Tabelle über Staging), zahlt das jede Abfrage. Als Tabelle materialisieren, Wrapper-View trägt den Filter.

## Beim Generieren vieler Berechtigungen

### Leere Spalten sind NULL, nicht `''`

Ein Seed lädt leere CSV-Felder als NULL. Prüfungen auf `spalte = ''` greifen dann nie — beim ersten Generierungslauf fehlten dadurch 10 von 59 Zeilen, und zehn Nutzer hätten null Zeilen gesehen.

Immer `ISNULL(spalte,'') = ''` schreiben.

### Ergebnis nicht gegen die Matrix zurückgerechnet

Beide obigen Fehler wurden nur gefunden, weil das Ergebnis Zeile für Zeile gegen die Ausgangsmatrix verglichen wurde. Anzahl Werte je Achse und Nutzer muss übereinstimmen.

---

◀ [Verifizieren](07-verifizieren.md) · [Übersicht](00-security.md) · [Betrieb & Rollout](09-betrieb-rollout.md) ▶
