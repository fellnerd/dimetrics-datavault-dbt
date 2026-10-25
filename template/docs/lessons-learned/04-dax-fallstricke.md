---
title: "DAX-Fallstricke"
tags:
  - lessons-learned
---
[Dokumentation](../README.md) › [Lessons Learned](00-lessons-learned.md)

# 3. DAX-Fallstricke

### `BLANK() <= N` ist in DAX `TRUE`

Ein Calculation-Group-Item mit `'tabelle'[spalte] <= 1` schließt Zeilen mit `BLANK()` in `spalte` fälschlich ein (DAX behandelt `BLANK()` in numerischen Vergleichen wie `0`). Bei uns: `konto_pl_zuordnung_v[ab_stufe]` ist für "x Hilfskonten" `NULL` — wurde durch `ab_stufe <= N` für **jede** Stufe fälschlich mitgezählt. **Fix: immer explizit `&& NOT ISBLANK(spalte)` ergänzen, wenn die Spalte NULL enthalten kann.**

### Bare Column-Prädikat in CALCULATE() != explizites FILTER(Tabelle, ...)

`CALCULATE(M, KEEPFILTERS('t'[spalte] <= 1))` lieferte empirisch ein **anderes** Ergebnis als `CALCULATE(M, KEEPFILTERS(FILTER('t', 't'[spalte] <= 1)))` — obwohl beide auf den ersten Blick äquivalent aussehen. Nur mit expliziter `FILTER()`-Formulierung stimmte das Ergebnis mit der manuell nachgerechneten Referenz überein. **Bei Zweifeln an einer DAX-Filterlogik: gegen eine unabhängig berechnete Referenz messen, nicht der Doku/Intuition vertrauen.**

### Sobald EINE Calculation Group im Modell existiert, werden implizite Measures überall deaktiviert

Nicht nur für die Spalten, die die Calculation Group direkt betrifft — **modellweit**. Rohe Spalten können dann in KEINEM Bucket mehr direkt verwendet werden (Card-Werte, Tabellen-Values, Zebra-BI-"Category Class" etc.) — es wird überall ein explizites Measure verlangt (z.B. `SELECTEDVALUE('tabelle'[spalte])`). Fehlermeldung dabei ist wenig sprechend ("Dieses Feld kann hier nicht verwendet werden... implizite Measureseigenschaft ist aktiviert"). **Beim Debuggen von "Feld nicht verwendbar"-Fehlern zuerst prüfen, ob eine Calculation Group im Modell existiert.**

---

◀ [Row-Level Security](03-row-level-security-native-security-policy.md) · [Übersicht](00-lessons-learned.md) · [Zebra BI Tables](05-zebra-bi-tables.md) ▶
