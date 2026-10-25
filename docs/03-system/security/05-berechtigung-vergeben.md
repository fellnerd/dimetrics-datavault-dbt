---
title: "Berechtigung vergeben"
tags:
  - system/security
---
[Dokumentation](../../README.md) › [Data Vault 2.1 – Systemdokumentation](../00-systemdokumentation.md) › [Security](00-security.md)

# Berechtigung vergeben

Der Arbeitsablauf, wenn jemand Zugriff bekommen soll.

## Die wichtigste Regel vorweg

> **Jeder Nutzer braucht auf JEDER Achse ein Recht — auch dort, wo er nicht eingeschränkt ist.** Auf der freien Achse ist das Recht schlicht `<mandant>`.

Grund: Die Fakt-Views joinen beide Dimensionen. Fehlt das Recht auf einer Achse, liefert diese Dimension null Zeilen, und der Join schneidet den Nutzer auf null — trotz korrektem Recht auf der anderen Achse.

## Schritt 1: Objektzugriff (OLS)

Aufnahme in `<gruppen-prefix>-finance-employees-ro` (Entra ID, über die IT). Das gilt für **alle** Finance-Nutzer, eingeschränkt oder nicht.

Nach der Aufnahme wirkt der Zugriff mit dem nächsten `dbt run` bzw. nach erneuter Anmeldung.

## Schritt 2: Zeilenrechte (RLS)

### Fall A — der Nutzer darf alles sehen

Aufnahme in `<gruppen-prefix>-finance-full-ro`. Fertig, kein SQL.

Diese Gruppe trägt zwei Zeilen in `sec_group_privilege`:

```sql
INSERT INTO sec.sec_group_privilege (group_name, security_context, sec_value_key, description)
VALUES (N'<gruppen-prefix>-finance-full-ro', N'finance_kst',   N'<mandant>', N'Vollzugriff Kostenstellen'),
       (N'<gruppen-prefix>-finance-full-ro', N'finance_konto', N'<mandant>', N'Vollzugriff Konten');
```

### Fall B — der Nutzer ist eingeschränkt

**Nicht** in die `-all-ro`-Gruppe aufnehmen — das Gruppenrecht würde die Einschränkung per ODER wieder aufheben. Stattdessen Einzelzeilen:

```sql
-- Beispiel: nur Kontogruppe "5 Personalaufwand", alle Kostenstellen
INSERT INTO sec.sec_user_privilege (user_name, security_context, sec_value_key, description)
VALUES (N'max.muster@<domain>', N'finance_konto', N'<mandant>||5 Personalaufwand', N'Matrix'),
       (N'max.muster@<domain>', N'finance_kst',   N'<mandant>',                    N'Kostenstellen-Achse uneingeschraenkt');
```

Mehrere Werte auf einer Achse = mehrere Zeilen (wirken als ODER).

## Schritt 3: Den richtigen Schlüssel ermitteln

**Nie den Wert aus der Matrix abtippen.** Er muss gegen die Dimension aufgelöst werden.

```sql
-- Kostenstelle oder Bereich
SELECT DISTINCT bereich, dss_sec_value_key
FROM mart_finance.dim_kostenstelle
WHERE kostenstelle_id = '2030';      -- oder: WHERE bereich = '3 Vertrieb'

-- Konto oder Kontogruppe
SELECT konto_id, konto_l2, dss_sec_value_key
FROM mart_finance.dim_konto
WHERE konto_id = '61400';
```

Für eine **ganze Gruppe** reicht der Pfad bis zur Gruppenebene:

| Gemeint | Schlüssel |
|---|---|
| Bereich „3 Vertrieb" | `<mandant>\|\|3 Vertrieb` |
| Kontogruppe „5 Personalaufwand" | `<mandant>\|\|5 Personalaufwand` |
| Einzelne Kostenstelle 2030 | `<mandant>\|\|2 Verwaltung\|\|2030` (Bereich gehört dazu!) |
| Einzelnes Konto 61400 | voller Pfad aus `dss_sec_value_key` |

> [!WARNING]
> **Labels sind nicht verlässlich.** Die Matrix nennt `6a Übriger Betriebsaufwand`, in `dim_konto` heißt die Gruppe `6a Uebriger Betriebsaufwand` — eine bekannte Sharepoint-Encoding-Korrektur. Ein abgetippter Wert trifft nichts und bewirkt still nichts. Bei Kontogruppen deshalb über den stabilen Präfix auflösen:
>
> ```sql
> SELECT DISTINCT konto_l2, dss_sec_value_key FROM mart_finance.dim_konto
> WHERE konto_l2_prefix = '6a';
> ```

## Schritt 4: Prüfen, dass das Recht nicht ins Leere läuft

```sql
SELECT p.user_name, p.security_context, p.sec_value_key
FROM sec.sec_user_privilege p
WHERE p.sec_value_key <> N'<mandant>'
  AND NOT EXISTS (SELECT 1 FROM mart_finance.dim_konto d
                  WHERE p.security_context = 'finance_konto'
                    AND (d.dss_sec_value_key = p.sec_value_key
                      OR d.dss_sec_value_key LIKE p.sec_value_key + N'||%'))
  AND NOT EXISTS (SELECT 1 FROM mart_finance.dim_kostenstelle k
                  WHERE p.security_context = 'finance_kst'
                    AND (k.dss_sec_value_key = p.sec_value_key
                      OR k.dss_sec_value_key LIKE p.sec_value_key + N'||%'));
-- Erwartung: keine Zeilen
```

Und dass niemand eine Achse vergessen hat:

```sql
SELECT user_name
FROM sec.sec_user_privilege
GROUP BY user_name
HAVING SUM(CASE WHEN security_context = 'finance_kst'   THEN 1 ELSE 0 END) = 0
    OR SUM(CASE WHEN security_context = 'finance_konto' THEN 1 ELSE 0 END) = 0;
-- Erwartung: keine Zeilen
```

## Schritt 5: Verifizieren

Mit einem echten Login prüfen — siehe [07 – Verifizieren](07-verifizieren.md).

## Viele Nutzer auf einmal

Für eine ganze Berechtigungsmatrix lohnt sich Generieren statt Tippen: die Matrixwerte gegen `dim_konto` und `dim_kostenstelle` auflösen und daraus die `INSERT`-Anweisungen erzeugen. Beispiel: `security/privileges/insert_sec_user_privilege_finance.sql` — 57 Zeilen für 13 Nutzer, so entstanden.

> **Die Matrix selbst ist keine technische Quelle.** Gepflegt werden Berechtigungen ausschließlich in `sec_user_privilege` und in den AD-Gruppen. Eine Excel oder ein Seed daneben würde nur so aussehen, als wäre sie die Wahrheit, und unbemerkt veralten. Der Abgleich „stimmt die Datenbank noch mit dem, was der Fachbereich entschieden hat" ist bewusst ein manueller Schritt.

**Beim Generieren zwei Dinge beachten:**

1. Leere Matrix-Spalten sind in der Datenbank **NULL**, nicht `''`. Prüfungen `ISNULL(spalte,'') = ''` schreiben, sonst fehlen die `<mandant>`-Zeilen der freien Achsen.
2. Das Ergebnis **gegen die Matrix zurückrechnen**, bevor es ausgeführt wird: Anzahl Werte je Achse und Nutzer muss übereinstimmen.

## Rechte entziehen

```sql
DELETE FROM sec.sec_user_privilege
WHERE user_name = N'<upn>' AND security_context = N'finance_kst';
```

Bei Austritt: Entfernen aus der Entra-Gruppe nimmt den **Objektzugriff**. Die RLS-Zeilen bleiben stehen und würden bei Wiedereintritt erneut greifen — beim Offboarding also bewusst mitlöschen.

---

◀ [Überblick](01-ueberblick.md) · [Übersicht](00-security.md) · [Neues Mart-Objekt absichern](06-neues-objekt-absichern.md) ▶
