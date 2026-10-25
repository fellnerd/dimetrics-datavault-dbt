# Bestehende Doku in die Konzeptstruktur überführen

Ziel: Struktur ändern, Inhalt behalten. Nichts wird gelöscht, bevor sein Inhalt an der neuen Stelle steht.

## 1 Inventar

Alle Notizen unter `04-<mandant>-architektur/` und verstreute Fundstellen (`load/`, `quellsysteme/`, Meetings, Projektdoku, `design/*.md`) auflisten und je Datei festhalten: Konzept, Schicht, Art (generiert / Inhalt / Asset), eingehende Links (`grep -rn "<dateiname>" docs design TASKS.md README.md`).

## 2 Zuordnung

| Typischer alter Inhalt | Neuer Ort |
|------------------------|-----------|
| Kapitel zu einer Quelle (Quelle und Lieferung, `quellsysteme/<quelle>.md`, `load/<quelle>/`) | `raw-vault/mart_<konzept>/0N-beladung-<quelle>.md` |
| Staging, PSA, Delta-Logik | Beladungsseite, Kapitel Staging bzw. PSA und Delta |
| Raw-Vault-Kapitel (Objekte, Entwurfsentscheidungen, Qualität) | `raw-vault/mart_<konzept>/00-…` Kapitel Objekte, Modellierung, Datenqualität |
| Datenfluss, Stand der Schichten | Raw-Vault-Übersicht, Kapitel Allgemein und Beladung Datenquelle |
| Mart-Kapitel (Dimensionen, Fakten, Berechnungslogik) | `information-mart/mart_<konzept>/00-…` und `objekte/<objekt>.md` |
| Betrieb, CI-Jobs, Retention | `raw-vault/mart_<konzept>/NN-betrieb.md` |
| Entscheidungen, Beschlüsse, Testsuiten, Befunde | `raw-vault/mart_<konzept>/NN-entscheidungen-und-befunde.md` |
| Offene Punkte | `raw-vault/mart_<konzept>/NN-offene-punkte.md` |
| Prüf- und Demo-Abfragen (`.sql`, Explorationspläne) | als Datei in den Raw-Vault-Konzeptordner, auf der Beladungsseite verlinkt |
| Generierte ER-Diagramme | bleiben im Konzeptordner; `target` und `groups` in `design/vault-sync.json` anpassen |
| Projektweites (Projektziel, Phasen, Business Case) | bleibt in `projektdokumentation/` bzw. im Mandantenordner |

Die Zuordnung als Tabelle *alte Datei / Abschnitt → neue Datei / Kapitel* notieren; sie dient in Schritt 6 als Prüfliste.

## 3 Sichern

Ist die alte Datei nicht in Git (`git status` zeigt `??`), vorher nach `<scratchpad>/backup-<ordner>/` kopieren. Ganze Dateien, die unverändert an einen neuen Ort passen, mit `git mv` verschieben, damit die Historie bleibt; danach Frontmatter, Breadcrumb und Navigation ergänzen.

## 4 Schreiben

Neue Seiten nach den Vorlagen. Text aus den alten Seiten übernehmen, wo er stimmt, und dabei gegen den Code prüfen. Korrekturen sammeln (für Changelog und Antwort). Personenbezogene Beispiele (echte Kundennamen) durch Platzhalter ersetzen und das in der Antwort erwähnen.

## 5 Links

- Eingehende Links aus anderen Notizen, `TASKS.md`, `design/*.md`, `README.md` auf die neuen Pfade setzen.
- Links aus verschobenen Notizen auf `models/`, `design/` oder andere Dateien ausserhalb des Vaults neu berechnen. Obsidian aktualisiert beim Verschieben nur Links innerhalb des Vaults und setzt Links zwischen gleichzeitig verschobenen Geschwistern manchmal falsch (`objekte/x.md` statt `x.md`).
- `.obsidian/workspace*.json` ignorieren (nicht versioniert).
- Bases mit `file.inFolder(...)`-Filtern prüfen.

## 6 Abgleich

Jede Zeile der Zuordnungstabelle abhaken: Abschnitt gefunden, Zahlen gleich (oder bewusst korrigiert), Beschlüsse mit Datum vorhanden, Diagramme übernommen. Erst danach die alten Dateien entfernen. Dann `check_concept_docs.py` und den Sync laufen lassen.
