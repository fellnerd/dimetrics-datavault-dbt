# Obsidian: Properties und Bases

## Properties

Konzeptseiten (`00-mart-<konzept>.md`, beide Schichten):

| Property | Wert |
|----------|------|
| `title` | „Information Mart <Konzept>“ bzw. „Raw Vault <Konzept>“ |
| `aliases` | `mart_<konzept>`, Fachbegriffe, frühere Kapitelnamen |
| `tags` | `architektur/information-mart` bzw. `architektur/raw-vault`, dazu `typ/inhaltsverzeichnis` |
| `konzept` | `mart_<konzept>` |
| `schicht` | `Information Mart` bzw. `Raw Vault` |
| `schema` | Schema bzw. Liste der Schemas |
| `quellsysteme` | Liste |
| `dokumentation` | `offen`, `teilweise` oder `vollständig` |
| `stand` | Datum der letzten inhaltlichen Prüfung (JJJJ-MM-TT) |

Objektseiten (`objekte/<objekt>.md`):

| Property | Wert |
|----------|------|
| `title` | Objektname |
| `aliases` | fachlicher Name, Name der Tabelle bei persistierten Objekten |
| `tags` | `architektur/information-mart`, `typ/objekt` |
| `objekt` | Objektname, gleich dem Dateinamen |
| `schema` | `mart_<konzept>` |
| `art` | `Dimension`, `Fakt`, `Bridge`, `View` |
| `materialisierung` | `view`, `table`, `incremental table mit View` |
| `grain` | „ein Vertrag“, „Vertrag und Tag“ |
| `quellen` | Liste der gelesenen Vault- oder Mart-Objekte |
| `zeilen` | Zahl (ohne Tausendertrennzeichen) |
| `stand` | JJJJ-MM-TT |

Beladungs- und Betriebsseiten: `title`, `aliases` (alte Kapitelnamen), `tags` (`architektur/raw-vault`, bei Beladung zusätzlich `architektur/quellsysteme`), `quellsystem`, `stand`.

## Base-Ansichten

In `04-<mandant>-architektur/00-<mandant>-architektur.base` unter `properties:` die Anzeigenamen und unter `views:` zwei Ansichten ergänzen, falls sie fehlen:

```yaml
properties:
  note.konzept:
    displayName: Konzept
  note.schicht:
    displayName: Schicht
  note.schema:
    displayName: Schema
  note.quellsysteme:
    displayName: Quellsysteme
  note.dokumentation:
    displayName: Doku
  note.art:
    displayName: Art
  note.grain:
    displayName: Grain
  note.materialisierung:
    displayName: Materialisierung
  note.quellen:
    displayName: liest aus
  note.zeilen:
    displayName: Zeilen
  note.stand:
    displayName: Stand
views:
  - type: table
    name: Konzepte
    filters:
      and:
        - file.hasProperty("konzept")
    groupBy:
      property: schicht
      direction: ASC
    order:
      - file.name
      - title
      - schema
      - quellsysteme
      - dokumentation
      - stand
  - type: table
    name: Mart-Objekte
    filters:
      and:
        - file.hasTag("typ/objekt")
    groupBy:
      property: schema
      direction: ASC
    order:
      - file.name
      - art
      - grain
      - materialisierung
      - quellen
      - zeilen
      - stand
```

`uebersichten/design-diagramme.base` filtert auf `file.hasTag("typ/er-diagramm")` oder `file.ext == "canvas"`, damit Konzept- und Objektseiten dort nicht erscheinen.

## Platzhalter finden

Obsidian-Suche `"[!todo]"` oder `grep -rn "\[!todo\]" docs/` listet alle offenen Kapitel. Die Base-Ansicht „Konzepte“ zeigt den Doku-Stand je Konzept.
