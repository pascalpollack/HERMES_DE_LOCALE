# A241 - Hermes Desktop: Plugins und Startbildschirm nachziehen

> **Bearbeitet:** 12.09.2026 · **Auftrag:** `AUFTRAEGE/erledigt/A241_Hermes_Desktop_die_zwei_Plugins_auf_Deutsch_nach.md`
> **Vorgänger:** A240 (Kernkatalog, 3773 Schlüssel)

## Der Auftrag wurde unterwegs größer, auf Ansage

Angelegt war er als „die zwei Plugins auf Deutsch nachziehen". Pascal hat zweimal
erweitert, beide Male mit Begründung:

1. **Nicht nur Deutsch, sondern alle Sprachen.** *„das ist noch bessere werbung
   wenn du russisch machst etc."* Die Plugins führten `en, ja, zh, zh-hant`. Es
   fehlte also nicht nur Deutsch, sondern auch Russisch und Arabisch, obwohl die
   App beide im Sprachwähler anbietet. Wer dort umstellte, sah in diesen
   Bereichen Englisch.
2. **Auch die Startbildschirm-Texte.** Pascal hat auf seinem eigenen Screenshot
   gesehen, dass unter „HERMES AGENT" ein englischer Satz stand, und gefragt, ob
   da nicht die eingestellte Sprache stehen müsste.

## Was gebaut wurde

### Die zwei Plugins

| Plugin | Schlüssel je Sprache | vorher | nachher |
|---|---|---|---|
| `hermes-bots` | 195 | en, ja, zh, zh-hant | **+ de, ru, ar** |
| `kanban` | 178 | en, ja, zh, zh-hant | **+ de, ru, ar** |

Beide Bündel sind typisiert (`BotsMessages`, `KanbanMessages`). Die
Vollständigkeit ist damit erzwungen, nicht gezählt: `tsc --noEmit` läuft
fehlerfrei durch.

### Der Startbildschirm

Hier war nichts zu ergänzen, weil es keinen Platz für eine zweite Sprache gab.
`intro-copy.jsonl` enthält 75 Texte (15 Persönlichkeiten à 5 Varianten) und
wurde von `intro.tsx` roh geladen, ohne jeden Sprachbezug.

Umgebaut, bewusst klein gehalten:

- je Sprache eine eigene Datei `intro-copy.<locale>.jsonl`, gleiche Form
- `INTRO_COPY_BY_LOCALE` hält alle sieben Sammlungen
- `resolveCopy` bekommt die aktive Locale, Rückfall auf Englisch, wenn eine
  Sprache eine Persönlichkeit nicht kennt
- `Intro` liest die Sprache über `useI18n()`, wechselt also mit der Einstellung

**6 Sprachen × 75 Texte = 450 Übersetzungen**, je Sprache ein Agent.

Englisch bleibt an einer Stelle: `fallbackCopyForPersonality` erzeugt Texte für
Persönlichkeiten, die der Nutzer selbst angelegt hat und für die es in keiner
Sprache Einträge gibt. Steht als Kommentar im Code.

## Befunde

### Befund 1: Eine Formprüfung bestätigt auch eine unübersetzte Kopie

Die sechs Sprachdateien wurden als Kopien der englischen angelegt und dann
gefüllt. Die Prüfung auf 75 Zeilen, 15 Persönlichkeiten und gültiges JSON meldete
für **alle sieben** Dateien „ok", auch für die japanische, die zu diesem
Zeitpunkt noch Wort für Wort englisch war.

Sie misst die Form, und die Form stimmt bei einer Kopie natürlich. Erst eine
zweite Probe, welche **Schriftsysteme** in den Texten vorkommen, zeigte den
Unterschied:

| Datei | Schrift |
|---|---|
| `ar` | arabisch, lateinisch |
| `ru` | kyrillisch, lateinisch |
| `ja` | CJK, Kana, lateinisch |
| `zh`, `zh-hant` | CJK, lateinisch |

Für Deutsch trägt diese Probe nicht, weil es dieselbe Schrift wie Englisch hat.
Dort musste die Stichprobe im Text erfolgen.

### Befund 2: Agenten committen in fremde Repos, wenn man es nicht verbietet

Ein Agent hat im Hermes-Repo `git add` ausgeführt und wollte committen. Das ist
genau das, was hier nicht passieren soll: der Baum gehört NousResearch, eigene
Commits kollidieren mit dem nächsten Update. Zurückgenommen mit `git reset`, die
Übersetzungen blieben erhalten.

Die Auftragstexte sagten, was zu übersetzen ist, aber nicht, dass nicht
committet werden darf. Bei Arbeit in fremden Bäumen gehört das hinein.

### Befund 3: Der rote Rand auf Screenshots

Die Bilder aus A240 tragen einen roten Rahmen. Den zeichnet Windows, solange ein
Programm den Bildschirm steuert, und er lässt sich nicht abschalten. Für
Veröffentlichungen müssen die Bilder deshalb von Hand aufgenommen werden.
Pascal hat sie geliefert.

## Stand

| | |
|---|---|
| Kernkatalog | 3773 Schlüssel, Deutsch (A240) |
| `hermes-bots` | 195 × 7 Sprachen |
| `kanban` | 178 × 7 Sprachen |
| Startbildschirm | 75 Texte × 7 Sprachen |
| Typprüfung | fehlerfrei |
| Tests `src/i18n` | 31 von 31 |
