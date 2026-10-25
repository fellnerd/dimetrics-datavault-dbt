---
title: "Zebra BI Tables"
tags:
  - lessons-learned
---
[Dokumentation](../README.md) › [Lessons Learned](00-lessons-learned.md)

# 4. Zebra BI Tables

### Calculation Groups lassen sich NICHT mit einer Category-Hierarchie kombinieren

Wird ein Calculation-Group-Feld ("Summary Lines") zusätzlich zur echten Dimensions-Hierarchie (z.B. Konto_L2→L1→Konto) in denselben **Category**-Bucket gezogen, entsteht ein Kreuzprodukt: jeder echte Blattknoten zeigt zusätzlich alle Calc-Group-Items als Pseudo-Kinder, jeweils mit dem Wert des Blattknotens selbst (nicht der eigentlich gewünschten Zwischensumme).

### Der korrekte Mechanismus für interleaved P&L-Summenzeilen: "Category Class"

Zebra BI Tables hat einen eigenen Bucket **"Category class"** mit den Symbolen `=` (Result/Zwischensumme), `-` (Invert), `/` (Skip, aus Summen ausschließen, bleibt aber sichtbar). Umsetzung bei uns: Spalte `dim_konto.zeilentyp` (`NULL`=Detail, `=`=Summary-Plug, `/`=x Hilfskonten), gebunden über ein Measure `SELECTEDVALUE('dim_konto'[zeilentyp])` (Grund: implizite Measures sind deaktiviert, siehe oben). **Voraussetzung, die leicht übersehen wird: Category darf dabei NUR die flache Ebene sein, auf der die Plug-/Summary-Zeilen liegen** (bei uns `konto_l2`) — eine mehrstufige Hierarchie funktioniert laut Zebra-BI-Doku zwar grundsätzlich auch, aber das muss man bewusst konfigurieren, nicht einfach die volle Hierarchie plus Calc-Group-Feld kombinieren (siehe Punkt oben).

Result-Zeilen-Berechnung ist **abhängig von der visuellen Zeilenreihenfolge** — die Sortierung (`Sortieren nach Spalte` → `konto_sort`) muss stimmen, sonst bleiben Result-Zeilen leer, weil Zebra BI nicht bestimmen kann, welche Detailzeilen dazugehören.

### Modell-Objektnamen kollidieren case-insensitiv

Eine physische SQL-Spalte `zeilentyp` (klein) kollidierte beim Power-BI-Refresh mit einer bereits im Modell **manuell angelegten DAX-berechneten Spalte** `Zeilentyp` (groß) — Power-BI-Objektnamen sind für Eindeutigkeit case-insensitiv. Fehlermeldung nennt dabei verwirrenderweise **jede** Tabelle im Modell als Kollisionsquelle (Batch-Refresh-Artefakt), obwohl nur eine einzige Tabelle betroffen ist. **Vor dem Anlegen einer Spalte/eines Measures mit naheliegendem Namen: prüfen, ob im Modell bereits ein gleichnamiges (auch anders großgeschriebenes) Objekt existiert — insbesondere wenn der Name schon in älterer Projektdokumentation als "geplant" auftaucht.**

---

◀ [DAX-Fallstricke](04-dax-fallstricke.md) · [Übersicht](00-lessons-learned.md) · [Diagnose-Werkzeuge / Vorgehen](06-diagnose-werkzeuge-vorgehen.md) ▶
