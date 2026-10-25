---
name: dv-security
description: Berechtigungen vergeben und absichern auf SQL Server/Azure SQL — Object Level Security (nur Views berechtigen), Row Level Security über Dimensionen, sec-Schema mit Prüffunktion, mehrere Berechtigungsachsen (z. B. Kostenstelle UND Konto), Column Level Security. Immer verwenden bei "Berechtigung vergeben", "RLS", "OLS", "wer darf welche Zeilen sehen", "User anlegen und berechtigen", "Zugriff einschränken", oder wenn eine Berechtigungsmatrix aus einer Excel/Liste technisch umgesetzt werden soll.
---

# Berechtigungen vergeben (OLS / RLS / CLS)

Drei Grundentscheidungen, die vor jeder Zeile SQL feststehen müssen. Sie sind hier nicht
Geschmacksfragen — jede ist durch einen konkreten Fehlermodus begründet.

## 1. Nur Views berechtigen, niemals Schemas

`GRANT SELECT ON SCHEMA::mart_<domain>` gibt **alles** im Schema frei, auch physische
Performance-Caches (`fakt_<name>`, `dim_<name>`). Endnutzer sollen nur den publizierten
Vertrag sehen (`_v`-Views), nicht die Interna.

Der Einwand „Objekt-Grants überleben keinen `dbt run`" stimmt — dbt erstellt Views jedes
Mal neu, objektbezogene Rechte sterben mit dem Objekt. Die Lösung ist nicht, das Problem
zu umgehen, sondern die Grants **nach jedem Run neu zu setzen**: `on-run-end`-Hook, der
über `sys.views` iteriert (Macro in `references/macros.md`).

Entscheidend ist, **woraus die Schleife liest**: aus `sys.views`. Eine physische Tabelle
kann dadurch gar keinen Grant bekommen — nicht weil jemand daran denkt, sondern weil sie
in der Quelle nicht vorkommt. Der Schutz ist strukturell, nicht prozedural.

> Jeder physische Cache braucht dann eine `_v`-Wrapper-View, sonst ist er für Konsumenten
> unerreichbar. Typischer Altlast-Fund: eine **Tabelle mit `_v`-Suffix** — unter
> Schema-Grants fällt das nie auf, unter View-Grants wird das Objekt schlagartig unsichtbar.

Absichern mit einem Test, der anschlägt, sobald ein Schema-Grant oder ein Grant auf einer
Tabelle existiert (`references/verification.md`). Ohne den driftet die Konvention zurück.

## 2. Den Zeilenfilter auf die Dimension legen, nicht auf den Fakt

Die Prüffunktion wird **pro Zeile** ausgewertet. Auf einem Fakt mit Millionen Zeilen ist
das der dominierende Kostenfaktor; auf der zugehörigen Dimension mit ein paar hundert
Zeilen ist es praktisch gratis. Die Fakten erben den Filter über den `INNER JOIN` auf den
Dimensionsschlüssel.

Gemessen an einem realen Projekt (915.841 Faktzeilen, Aggregation `COUNT + SUM`):

| Variante | ms | logische Reads |
|---|---|---|
| Security Policy auf der Fakttabelle + Filter in der View | 2.201 | 3.697.737 |
| Filter nur auf der Dimension, Fakt erbt per Join | 273 | 31.069 |
| Referenz: derselbe Scan ganz ohne Security | 221 | 30.744 |

Die Kosten der Funktion pro Zeile ändern sich dabei **nicht** — es ändert sich nur, auf wie
vielen Zeilen sie läuft. Faustregel: **den Filter auf das kleinste Objekt legen, das den
Zugriffsbereich fachlich definiert.**

Nebeneffekt, der oft mehr wert ist als die Performance: Slicer in Power BI zeigen dann nur
noch erlaubte Werte statt Auswahlmöglichkeiten, die zu leeren Ergebnissen führen.

> **Voraussetzung, die vorher zu prüfen ist:** Die Dimension muss **jede** im Fakt
> vorkommende Ausprägung enthalten. Sonst unterschlägt der `INNER JOIN` Zeilen — still,
> ohne Fehler, auch für Vollzugriffs-User. Vor der Umstellung zählen:
> ```sql
> SELECT COUNT(*) FROM <fakt> f
> WHERE NOT EXISTS (SELECT 1 FROM <dim> d WHERE d.<key> = f.<key>);
> ```
> Ist das Ergebnis > 0, zuerst die Dimension vervollständigen (meist fehlen Stammdaten,
> auf die nie gebucht wurde, oder Werte aus einer zweiten Quelle wie Budget/Plan).
> Danach den `relationships`-Test auf `severity: error` setzen — als `warn` wird genau
> dieser Fall übersehen.

## 3. Deny-by-default, und zwar pro Achse

Ohne passende Berechtigungszeile sieht ein User **nichts**. Das ist die sichere Richtung,
hat aber eine Konsequenz, die beim Rollout überrascht:

Joint eine Fakt-View **zwei** Dimensionen, braucht der User auf **beiden** Achsen ein
Recht. Wer nur auf einer Achse eingeschränkt ist, braucht auf der anderen ein explizites
Recht auf den Mandanten-Wurzelwert — sonst schneidet ihn der zweite Join auf null Zeilen.

Die Alternative wäre „kein Eintrag = alles sehen". Davon ist abzuraten: die Prüffunktion
verknüpft ihre Zweige mit `OR`, ein pauschales Gruppenrecht würde damit **jede**
Einzeleinschränkung wieder aufheben.

## Mehrere Achsen kombinieren

Eine Berechtigungsmatrix hat typischerweise mehrere unabhängige Dimensionen
(z. B. Kostenstelle *und* Konto). Pro Achse:

- eine gefilterte Dimension
- ein eigener `security_context`
- ein eigener Schlüssel-Wertebereich

Der `security_context` trennt die Wertebereiche. Mit nur einem Kontext würde jedes Recht
gegen beide Dimensionen geprüft — ein Kostenstellenrecht trifft dann kein Konto, die
andere Achse läuft leer, und der User sieht null Zeilen.

**Die UND-Verknüpfung ergibt sich von selbst**, sobald die Fakt-View beide Dimensionen
inner-joint — ein Join ist eine Schnittmenge. Mehrere Rechte auf *derselben* Achse wirken
als ODER (mehrere Zeilen). Für den Fakt-Filter-Ansatz hätte dasselbe eine kombinierte
Wrapper-Funktion gebraucht.

## Schlüsselformat: materialisierter Pfad

Die Prüffunktion matcht hierarchisch per Prefix. Den Schlüssel deshalb als Pfad von grob
nach fein bauen:

```
<tenant>||<ebene_2>||<ebene_1>||<detail>
```

| Recht | wirkt auf |
|---|---|
| `<tenant>` | alles |
| `<tenant>\|\|<gruppe>` | die ganze Gruppe — **eine Zeile**, auch für künftig hinzukommende Elemente |
| `<tenant>\|\|<gruppe>\|\|…\|\|<detail>` | genau ein Element |

Platzhalter (`'?'`) einsetzen, wenn eine Ebene fehlt — das hält die Tiefe konstant und
macht das Prefix-Verhalten vorhersagbar. Elemente ohne Hierarchie-Eintrag sind dann nur
über den Wurzelwert erreichbar; das ist die bewusst restriktive Seite.

Wer ein einzelnes Element berechtigt, muss dessen Pfad kennen — dafür eine kleine
Hilfs-View mitliefern, die je Element den fertigen Schlüssel anzeigt.

## Ghost-/Plug-Zeilen müssen immer passieren

Dimensionen enthalten oft synthetische Zeilen: Unbekannt-Member, Plug-Zeilen für
Kategorie-Sichtbarkeit, Zwischensummen-Zeilen für BI-Visuals. Würde der Filter sie
treffen, verschwinden Zwischensummen aus dem Report, sobald ein User eingeschränkt ist.

Sie tragen keine Kennzahlen — durchlassen leakt nichts:

```sql
WHERE <plug_bedingung>            -- z. B. <key> < 0
   OR {{ rls_filter('<kontext>') }}
```

## Ablauf beim Berechtigen

1. **Matrix in Achsen zerlegen.** Spalten, die dieselbe Dimension adressieren
   (Detailwert + Hierarchiestufen), gehören zu **einer** Achse.
2. **Semantik klären, nicht annehmen.** Innerhalb einer Achse ODER, über Achsen hinweg
   UND — das ist die übliche Lesart, aber sie ist zu bestätigen. Gegenprobe: Wenn zwei
   Angaben derselben Achse disjunkt sind (Detailwert liegt nicht in der genannten
   Gruppe), ergäbe UND null Zeilen — dann ist ODER zwingend.
3. **Pro Nutzer und Achse mindestens eine Zeile**, auch für nicht eingeschränkte Achsen.
4. **Gruppenrechte statt Einzelrechte**, wo möglich — dann läuft On-/Offboarding über die
   Verzeichnisgruppe statt über SQL.
5. **Verifizieren** (`references/verification.md`) — mit einem echten Test-Login.

## Was regelmäßig schiefgeht

| Symptom | Ursache |
|---|---|
| User sieht 0 Zeilen trotz korrektem Recht | Recht fehlt auf der *zweiten* Achse |
| User sieht 0 Zeilen, Objekt aber lesbar | Deny-by-default: gar kein Eintrag vorhanden |
| „permission denied" statt 0 Zeilen | OLS-Problem, nicht RLS — Grant fehlt |
| Zwischensummen verschwinden im Report | Plug-/Ghost-Zeilen werden mitgefiltert |
| Zeilen fehlen auch für Admins | Dimension unvollständig, `INNER JOIN` schluckt sie |
| Test mit `EXECUTE AS` besteht fälschlich | Prüffunktion nutzt `ORIGINAL_LOGIN()` — unter Impersonation weiterhin der eigene Login samt Bypass. Nur echte Anmeldung testet |
| Rechte ändern sich nach `dbt run` | Grants nicht im `on-run-end`-Hook |
| Marts plötzlich leer, ohne Fehler | Service-User-Ausnahme fehlt |

## Referenzen

- `references/sec-ddl.md` — Schema, Berechtigungstabellen, Prüffunktion
- `references/macros.md` — `rls_filter`, `sec_value_key`, `grant_select_on_views`
- `references/verification.md` — Prüfprotokoll mit Test-Login
