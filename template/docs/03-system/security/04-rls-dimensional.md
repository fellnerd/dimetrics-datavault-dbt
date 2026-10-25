---
title: "RLS – Zeilenfilter über Dimensionen"
tags:
  - system/security
---
[Dokumentation](../../README.md) › [Data Vault 2.1 – Systemdokumentation](../00-systemdokumentation.md) › [Security](00-security.md)

# RLS – Zeilenfilter über Dimensionen

**Regel: Der Filter liegt auf der Dimension. Die Fakten erben ihn über den `INNER JOIN`.**

## Das Prinzip

```sql
-- dim_kostenstelle_v: TRÄGT den Filter
SELECT … FROM {{ ref('dim_kostenstelle') }}
WHERE {{ rls_filter('finance_kst') }}

-- fakt_buchungen_v: ERBT ihn, kein eigener Filter
SELECT f.*
FROM {{ ref('fakt_buchungen') }} f
INNER JOIN {{ ref('dim_kostenstelle_v') }} d ON d.kostenstelle_key = f.kostenstelle_key
INNER JOIN {{ ref('dim_konto_v') }}        k ON k.konto_key        = f.konto_key
```

Ein Join ist eine Schnittmenge — sieht die Dimension nur eine Kostenstelle, liefert der Fakt nur deren Zeilen.

## Warum nicht auf dem Fakt?

Die Prüffunktion wird **pro Zeile** ausgewertet. Gemessen in einem Referenzprojekt (915.841 Faktzeilen, `COUNT + SUM`):

| Variante | ms | logische Reads |
|---|---|---|
| Security Policy auf dem Fakt + Filter in der View | 2.201 | 3.697.737 |
| Nur dimensionaler Join | **273** | **31.069** |
| Referenz: gleicher Scan ohne Security | 221 | 30.744 |

Die Funktion ist pro Zeile **gleich teuer geblieben** — auf der Dimension kostet sie sogar mehr (2,1 statt 0,03 Reads je Zeile). Was sich ändert, ist die Anzahl: 157 Auswertungen statt 915.841, und einmal statt zweimal.

> **Faustregel:** Den Filter auf das kleinste Objekt legen, das den Zugriffsbereich fachlich definiert. Bei RLS optimiert man nicht das Prädikat, sondern die Kardinalität der Menge, auf der es läuft.

Zwei weitere Vorteile: ein Filter statt einem pro Fakt, und Power-BI-Slicer zeigen nur noch erlaubte Werte statt Auswahlmöglichkeiten, die zu leeren Ergebnissen führen.

## Voraussetzung: die Dimension muss vollständig sein

Ein `INNER JOIN` auf eine unvollständige Dimension unterschlägt Faktzeilen — **still, ohne Fehler, auch für Vollzugriffs-Nutzer.** Vor jeder Umstellung zählen:

```sql
SELECT COUNT(*) FROM <fakt> f
WHERE NOT EXISTS (SELECT 1 FROM <dimension> d WHERE d.<key> = f.<key>);
-- Erwartung: 0
```

> Bei der Umstellung fehlten in `dim_kostenstelle` **6 Kostenstellen** und damit **936 Budget-Zeilen** der Dimensionsbezug: Der Hub wird nur aus Buchungen gespeist, geplante Kostenstellen ohne Buchung fehlten. Sichtbar war das nur als Warnung eines `relationships`-Tests mit `severity: warn`. Gelöst durch `UNION` mit dem Sharepoint-Kostenstellenplan.

Deshalb laufen die `relationships`-Tests auf den Dimensionsschlüsseln jetzt mit **`severity: error`** — als Warnung wird genau dieser Fall übersehen.

## Der Schlüssel: ein hierarchischer Pfad

`dss_sec_value_key` ist ein Pfad von grob nach fein. Die Prüffunktion matcht per Prefix, dadurch deckt ein Recht auf einer oberen Ebene automatisch alles darunter ab.

| Dimension | Format | Beispiel |
|---|---|---|
| `dim_kostenstelle` | `<mandant>\|\|<bereich>\|\|<kst>` | `<mandant>\|\|2 Verwaltung\|\|2030` |
| `dim_konto` | `<mandant>\|\|<gruppe>\|\|<subgruppe>\|\|<konto>` | `<mandant>\|\|6a Uebriger Betriebsaufwand\|\|61 Verwaltungs & Betriebsaufwand\|\|61400` |

Damit lassen sich alle Ebenen mit **einer** Zeile ausdrücken:

| Recht | wirkt auf |
|---|---|
| `<mandant>` | alles |
| `<mandant>\|\|3 Vertrieb` | alle 19 Kostenstellen dieses Bereichs — auch künftig neue |
| `<mandant>\|\|2 Verwaltung\|\|2030` | genau diese Kostenstelle |

Erzeugt im Model über `sec_value_key()`:

```sql
{{ sec_value_key("CONCAT_WS('||', ISNULL(CAST(rk.Bereich_L1 AS NVARCHAR(255)), '?'),
                                  CAST(b.kostenstelle_nr AS NVARCHAR(50)))") }} AS dss_sec_value_key
```

Das `ISNULL(…, '?')` hält die Pfadtiefe konstant, wenn eine Hierarchiestufe fehlt. Solche Elemente sind dann nur über `<mandant>` erreichbar — die bewusst restriktive Seite.

## Mehrere Achsen

Pro Achse: eine gefilterte Dimension, ein eigener Kontext, ein eigener Wertebereich.

| Verknüpfung | Ergibt sich aus |
|---|---|
| **ODER** innerhalb einer Achse | mehrere Zeilen in `sec_user_privilege` |
| **UND** über Achsen hinweg | den beiden `INNER JOIN`s in der Fakt-View |

Die UND-Verknüpfung muss also nirgends programmiert werden — sie ist eine Eigenschaft des Joins. Beispiel: ein Nutzer mit Kostenstelle 2030 und Kontogruppe „5 Personalaufwand" sieht 6.356 von 915.841 Zeilen, exakt die Schnittmenge.

> Dass innerhalb einer Achse **ODER** gilt, ist belegt: Ein Nutzer hat Kostenstelle 2030 *und* die Bereiche „4.1 Vertrieb" / „4.2 Shop". KST 2030 liegt in Bereich „2 Verwaltung" — als Schnittmenge gelesen bekäme er null Kostenstellen.

## Ghost- und Plug-Zeilen müssen durch

`dim_konto` enthält 14 synthetische Zeilen mit `konto_key < 0`: Gruppen-Plugs und Zwischensummen für Zebra-BI-Visuals. Würde der Filter sie treffen, verschwänden die Zwischensummen, sobald ein Nutzer eingeschränkt ist.

```sql
WHERE konto_key < 0                        -- Plug-Zeilen immer sichtbar
   OR {{ rls_filter('finance_konto') }}
```

Sie tragen keine Kennzahlen — durchlassen leakt nichts.

---

◀ [OLS – Objektzugriff](03-ols-view-grants.md) · [Übersicht](00-security.md) · [CLS & Verschlüsselung](08-cls-und-verschluesselung.md) ▶
