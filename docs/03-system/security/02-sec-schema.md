---
title: "Das sec-Schema"
tags:
  - system/security
---
[Dokumentation](../../README.md) › [Data Vault 2.1 – Systemdokumentation](../00-systemdokumentation.md) › [Security](00-security.md)

# Das `sec`-Schema

Hier liegen die Berechtigungen. Drei Tabellen und zwei Prüffunktionen, mehr nicht.

> Das Schema wird **manuell in SSMS** deployed, nicht über dbt ([security/DEPLOYMENT.md](../../../security/DEPLOYMENT.md)). Grund: ein dbt-Seed oder -Model würde produktive Berechtigungszeilen bei jedem Run überschreiben.

## Die drei Tabellen

| Tabelle | Beantwortet | Gepflegt wird … | Beispielzeile |
|---|---|---|---|
| `sec_user_privilege` | Wer darf was — **eine Person** | in der Datenbank | `max.muster@…` / `finance_konto` / `<mandant>\|\|5 Personalaufwand` |
| `sec_group_privilege` | Nur *was* — eine **Gruppe** | in Entra ID | `<gruppen-prefix>-finance-full-ro` / `finance_kst` / `<mandant>` |
| `sec_special_user_privilege` | **Ausnahme**: Filter gilt gar nicht | in der Datenbank | `sqladmin` / `NULL` / `no_sec=1` |

Der Unterschied zwischen den ersten beiden ist **nur, wo die Mitgliedschaft gepflegt wird**. Bei `sec_user_privilege` steht „wer" und „was" in derselben Zeile; bei `sec_group_privilege` steht nur „was" in der Datenbank, „wer" kommt aus Entra ID.

Die dritte Tabelle vergibt kein Recht auf Daten, sondern schaltet den Filter ab. Nur für den dbt-Service-User und Security-Admins.

## Die drei Spalten einer Berechtigung

```sql
INSERT INTO sec.sec_user_privilege (user_name, security_context, sec_value_key, description)
VALUES (N'max.muster@<domain>', N'finance_konto', N'<mandant>||5 Personalaufwand', N'Matrix');
```

| Spalte | Bedeutung |
|---|---|
| `user_name` | Der Login-Name, den `ORIGINAL_LOGIN()` liefert — bei Entra die E-Mail, bei SQL-Auth der Username |
| `security_context` | **Welche Achse** das Recht meint (siehe unten) |
| `sec_value_key` | **Welcher Wert** auf dieser Achse — hierarchischer Pfad, siehe [04](04-rls-dimensional.md) |

Optional: `valid_from` / `valid_to` für befristete Rechte, `description` für die Freigabe-Referenz.

## Security-Kontexte

Der Kontext trennt die Wertebereiche der Achsen. Aktuell vergeben:

| Kontext | Achse | Träger-Objekt |
|---|---|---|
| `finance_kst` | Kostenstelle / Bereich | `mart_finance.dim_kostenstelle_v` |
| `finance_konto` | Konto / Kontogruppe | `mart_finance.dim_konto_v` |
| `person_pii` | CLS-Kontext (Spaltenmaskierung) | `dim_person_v` |

**Warum getrennte Kontexte?** Ohne sie würde jedes Recht gegen beide Dimensionen geprüft. Ein Kostenstellenrecht (`<mandant>||2 Verwaltung||2030`) trifft dann kein Konto — die Konto-Achse läuft leer, der Join liefert nichts, der Nutzer sieht null Zeilen. Der Kontext sorgt dafür, dass jedes Recht nur dort geprüft wird, wo es hingehört.

## Die Prüffunktion

`sec.fn_check_rls(@sec_value_key, @security_context)` — eine Inline-Tabellenfunktion mit vier Zweigen, verknüpft mit **ODER**:

| # | Zweig | Wirkung |
|---|---|---|
| 1 | `no_sec = 1` in `sec_special_user_privilege` | Bypass überall |
| 2 | `no_sec = 2` + Kontext | Bypass in dieser Achse |
| 3 | Zeile in `sec_user_privilege` (Prefix-Match, Gültigkeitszeitraum) | Einzelrecht |
| 4 | Zeile in `sec_group_privilege` + `IS_MEMBER()` | Gruppenrecht |

Zwei Eigenschaften, die man kennen muss:

**Sie matcht auf `ORIGINAL_LOGIN()`, nicht auf `USER_NAME()`.** Meldet sich jemand über eine Entra-Gruppe an, ist die Gruppe der Datenbank-Principal — `USER_NAME()` liefert dann den *Gruppennamen*, und Einzelrechte wären unbrauchbar. Nebeneffekt: `ORIGINAL_LOGIN()` bleibt unter `EXECUTE AS` unverändert, weshalb sich Impersonation **nicht zum Testen eignet** (siehe [07](07-verifizieren.md)).

**Sie matcht hierarchisch per Prefix.** Ein Recht auf `<mandant>` trifft auch `<mandant>||…`, ein Recht auf `<mandant>||3 Vertrieb` trifft alle Kostenstellen dieses Bereichs. Das ist die Grundlage des Pfad-Schlüssels in [04](04-rls-dimensional.md).

**Die ODER-Verknüpfung hat eine wichtige Folge:** Ein Gruppenrecht auf `<mandant>` hebt jede Einzeleinschränkung seiner Mitglieder auf. Wer eingeschränkt werden soll, darf nicht in einer Gruppe mit Wurzelrecht sein. Gruppen können nur erweitern, nie einschränken.

## Pflicht-Baseline: die Service-User-Ausnahme

```sql
INSERT INTO sec.sec_special_user_privilege (user_name, security_context, no_sec, description)
VALUES (N'sqladmin', NULL, 1, N'dbt-Service-User — Bypass');
```

Fehlt diese Zeile, liefern dbt-Läufe und Tests **leere Ergebnisse ohne Fehlermeldung**. Überwacht vom Test `assert_dbt_service_user_exemption`.

---

◀ [Betrieb & Rollout](09-betrieb-rollout.md) · [Übersicht](00-security.md) · [OLS – Objektzugriff](03-ols-view-grants.md) ▶
