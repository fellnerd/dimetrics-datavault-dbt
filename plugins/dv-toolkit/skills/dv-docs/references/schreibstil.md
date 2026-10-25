# Schreibstil

Die Doku soll sich lesen wie von jemandem, der das System kennt und wenig Zeit hat. Grundlage für die Verbotsliste sind die typischen Merkmale maschinell erzeugter Texte, wie sie die deutschsprachige Wikipedia sammelt (Wikipedia:Anzeichen für KI-generierte Inhalte).

## So schreiben

- Kurze Hauptsätze, Subjekt vorn. Ein Gedanke je Satz.
- Konkrete Angaben statt Einordnung: Zahl mit Einheit, Datum, Umgebung, Objektname.
- Objekt-, Spalten-, Datei- und Jobnamen in `Code`-Format, exakt wie im Code.
- Gleichartiges (Objekte, Spalten, Beschlüsse, Jobs) als Tabelle, nicht als Fliesstext.
- Ursache, Folge, Abhilfe in dieser Reihenfolge: „Die Events enden am 10. Juni 2025, ein normaler Lauf findet daher nichts. Abhilfe: Full Refresh.“
- Quellen benennen: wer hat was wann gesagt oder beschlossen, welche Datei, welcher Test. Personen mit Vornamen, wenn das Projekt es so hält.
- Unsicheres als unsicher kennzeichnen: „nicht geklärt“, „nicht gegen Azure geprüft“.
- Beispiele mit Platzhaltern (`'<kunde_id>'`), nie mit echten Kundennamen oder -nummern.

## Nicht schreiben

| Merkmal | Beispiel | Stattdessen |
|---------|----------|-------------|
| Werbe- und Wertungswörter | zentral, nahtlos, robust, leistungsstark, umfassend, entscheidend, spielt eine wichtige Rolle | weglassen oder messbar machen |
| Meta-Kommentare | „Es ist wichtig zu beachten, dass …“, „Hierbei ist zu erwähnen …“ | die Aussage direkt |
| Füll-Konjunktionen am Satzanfang | Darüber hinaus, Ausserdem, Zudem, Ferner, Des Weiteren | neuer Satz ohne Anschluss, oder „und“ |
| Zusammenfassung am Absatzende | „Insgesamt zeigt sich …“, „Zusammenfassend …“, Abschnitt „Fazit“ | streichen |
| Negativer Parallelismus | „nicht nur …, sondern auch …“ | zwei einfache Aussagen |
| Dreierlisten aus Gewohnheit | „schnell, sicher und skalierbar“ | nur, was belegt ist |
| Partizip-Anhänge | „…, wodurch die Performance deutlich gesteigert wird“ | eigener Satz mit Messwert |
| Vage Quellen | „laut Best Practice“, „Experten empfehlen“ | konkrete Quelle oder weglassen |
| Fettdruck zur Betonung | „**wichtig**“, Listen mit fetter Einleitung | nur in Tabellenköpfen und Properties üblich, im Text keiner |
| Gedankenstriche als Satzzeichen | „Der Lauf – und das ist neu – …“ | Punkt, Komma, Doppelpunkt, Klammer |
| Emojis, Symbole vor Überschriften | „✅ Ergebnis“ | Text |
| Stehengebliebene Platzhalter | „[TBD]“, „…“ | `> [!todo] Noch nicht dokumentiert` |
| Anrede und Dialog | „Ich hoffe, das hilft“, „Gerne erkläre ich …“ | nichts davon |

## Länge

- Übersichtsseiten: so lang wie nötig, um ohne Klick auf eine Unterseite zu verstehen, was das Konzept leistet und wo es hakt. Details auf die Unterseiten.
- Objektseiten: eine Bildschirmseite plus Attributtabelle. Logik nur so weit, dass man eine Zahl nachrechnen kann.
- Kein Absatz wiederholt, was eine Tabelle schon zeigt.

## Prüfen

`../scripts/check_concept_docs.py` zählt Gedankenstriche, Fettdruck und die Wörter aus der Tabelle als Warnung. Breadcrumbs und bestehende Titel mit „—“ sind ausgenommen.
