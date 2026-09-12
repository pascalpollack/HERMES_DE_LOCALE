# A240 - Hermes Desktop: vollständige deutsche Locale plus Installer-Batch

> **Bearbeitet:** 12.09.2026 · **Auftrag:** `AUFTRAEGE/offen/A240_Hermes_Desktop_vollstaendige_deutsche_Locale_plu.md`
> **Stand:** siehe Abnahme unten

## Was gebaut wurde

Deutsch ist stromaufwärts nirgends gemergt (Issue #51217 offen, PR #38846 und
#69819 beide geschlossen). Die Locale musste also entstehen, nicht beschafft
werden. Sie ist vollständig, nicht als Teilfassung über `defineLocale()`.

| Datei | Änderung |
|---|---|
| `src/i18n/types.ts` | `Locale`-Typ um `'de'` erweitert |
| `src/i18n/languages.ts` | `LOCALE_OPTIONS` um Deutsch; 14 Aliasse (`de`, `de-de`, `de-at`, `de-ch`, `de-li`, `de-lu`, `german`, `deutsch` und Unterstrichvarianten) |
| `src/i18n/catalog.ts` | Import und Eintrag in `TRANSLATIONS` |
| `src/i18n/de.ts` | **neu**, 4183 Zeilen |
| `src/i18n/languages.test.ts` | Zusicherungen für die deutschen Varianten |
| `src/i18n/context.test.tsx` | ein Beispiel umgestellt (siehe Befund 1) |

## Messwerte

**Deckungsquote: 3773 von 3773 Schlüsselpfaden (100 %).**

Der Wert ist nicht gezählt, sondern erzwungen: `de.ts` ist als
`Translations` typisiert, und `Translations` verlangt jeden Schlüssel. Eine
fehlende Zeile wäre ein Übersetzungsfehler, kein stiller Rückfall. `tsc
--noEmit` läuft fehlerfrei durch. Zusätzlich strukturell gegengeprüft:
Schlüsselpfade aus `en.ts` und `de.ts` extrahiert, Differenz in beide
Richtungen null.

(gemessen) Tests `src/i18n`: 31 von 31 grün.

## Wie die Übersetzung entstand

Elf Agenten, je ein Zeilenbereich an Bereichsgrenzen von `en.ts`, Ausgabe als
Fragment, danach zusammengesetzt und zentral nachbearbeitet. Ein Probe-Agent
lief zuerst allein, bevor die übrigen zehn starteten.

Nachbearbeitung, alles gemessen und nicht vermutet:

| Mangel | Anzahl |
|---|---|
| Gedankenstriche entfernt | 54 |
| ASCII-Ersatzschreibungen zu echten Umlauten/ß | 813 |
| kaputte Anführungszeichenpaare repariert | 18 |
| falsch umgeformte englische Bezeichner zurückgedreht | 11 |
| Pluralfehler behoben | 1 |

## Befunde

### 1. Zwei bestehende Tests schrieben fest, dass Deutsch NICHT unterstützt wird

`languages.test.ts` sicherte zu, `normalizeLocale('de')` falle auf Englisch
zurück und `isSupportedLocaleValue('de')` sei `false`. `context.test.tsx`
benutzte `'de'` als Beispiel für „nicht unterstützte konfigurierte Sprache".
Beide wurden angepasst, das zweite auf ein tatsächlich unbekanntes Kürzel
(`xx`), damit der Test weiterhin misst, was er messen soll.

Wer eine Sprache ergänzt, ergänzt nicht nur eine Liste: er widerlegt
Zusicherungen, die das Fehlen der Sprache festhalten.

### 2. Der leere String ist Teilstring jedes Strings

Das Umlautskript schützte `ue` nach Vokalen (damit „neue" und „Quelle" heil
bleiben) über `davor in VOKALE`. Am Wortanfang ist `davor` der Leerstring, und
`"" in "aeiou"` ist in Python **wahr**. Also blieb jedes Wort mit „Ue"
unbehandelt: Ueber, Uebergabe, Ueberspringen. Sichtbar wurde es erst, weil die
Restliste ausgedruckt und angesehen wurde, nicht nur die Trefferzahl.

### 3. Eine Ersetzungsregel für Deutsch trifft englische Bezeichner mit

`ue → ü` verwandelte `continueLabel` in `continüLabel`, `hideValue` in
`hideValü`, `heartbeatDueWaitingForIdle` in `heartbeatDüWaitingForIdle`. Die
Typprüfung fand alle acht Stellen, eine Textprüfung hätte sie nicht gefunden.

### 4. Übersetzte Pluralformen können grammatisch kippen

`${runs} Durchlauf${runs === 1 ? "" : "läufe"}` ergab bei mehreren Läufen
„Durchlaufläufe". Der Agent hat den Fehler selbst gemeldet. Richtig ist das
ganze Wort im Ternär, nicht nur die Endung.

## Ort der Dateien

Der Quellbaum liegt in `C:\Users\polla\AppData\Local\hermes\hermes-agent` und
ist ein fremdes Repo (NousResearch). Dort wurde **nicht** committet: ein
Hermes-Update würde mit eigenen Commits kollidieren. Die geänderten Dateien
liegen als Kopie unter `WERKZEUGE/hermes-de/` im Leitstand und sind dort
versioniert.

**Ein Hermes-Update überschreibt den Umbau.** Danach muss der Batch erneut
laufen.

## Abnahme

| # | Kriterium | Stand |
|---|---|---|
| 1 | Deutsch steht im Sprachauswahlmenü | **erfüllt**, von Pascal am Bildschirm bestätigt |
| 2 | Oberfläche an fünf Stellen deutsch | **erfüllt**, von Pascal am Bildschirm bestätigt |
| 3 | kein englischer Rückfall | **erfüllt**, 3773 von 3773 Schlüsseln, typgeprüft |
| 4 | App startet und ist bedienbar | **erfüllt**, dreimal gemessen |
| 5 | Batch läuft ohne Quellbaum und Node | **erfüllt**, echt gefahren |
| 6 | Zurücknehmen funktioniert | **erfüllt**, echt gefahren |

**Nachtrag 12.09.2026:** Pascal hat die Oberfläche angesehen und bestätigt.
Damit sind alle sechs Abnahmekriterien erfüllt. Der folgende Absatz hält
fest, wie der Stand bis dahin belegt war.

**Zu 1 und 2: Der Bildschirmzugriff wurde abgelehnt**, als ich ihn für die
Sichtprüfung angefragt habe. Belegt ist stattdessen: „Deutsch" steht im
gebauten Sprachwähler-Bündel, und deutsche Bedientexte („Apps verbinden",
„Abbrechen", „Einstellungen", „Nicht jetzt", „Sprache wechseln") stecken im
ausgelieferten Bundle. Dass sie **auf dem Schirm** erscheinen, hat niemand
gesehen. Das ist der eine offene Punkt und dauert eine Minute: Hermes öffnen,
Einstellungen, Sprache.

## Der Installer

Weitergebbares Paket: `C:\Users\polla\Documents\HERMES_DEUTSCH`, 258 MB,
412 Dateien. Nicht im Git-Repo, dafür ist es zu groß. Im Leitstand liegen
unter `WERKZEUGE/hermes-de/` die beiden Batchdateien, die geänderten
Quelldateien und eine README.

### Befund 5: „app.asar tauschen reicht" ist falsch

Der Auftrag nannte das ausdrücklich eine Vermutung. Sie ist widerlegt. Gemessen
über Hashlisten vor und nach dem Neubau: **218 von 484 Dateien geändert.**
Darunter `Hermes.exe` selbst, weil der Build die asar-Integritätsprüfung in die
Programmdatei stempelt. Ein reiner `app.asar`-Tausch ließe die App an ihrer
eigenen Prüfung scheitern. Der Batch spielt deshalb `Hermes.exe` plus den
ganzen `resources`-Ordner ein.

### Befund 6: Drei Fallen im Batch, alle im Test aufgeflogen

- **`choice` liest von der Konsole, nicht von umgeleitetem stdin.** Ein
  automatisierter Test meldet „Die Datei ist entweder leer" und wählt still die
  zweite Option. Testartefakt, kein Fehler im Batch, aber ohne diese Einsicht
  liest man den Batch als kaputt.
- **`find` ohne vollen Pfad ist nicht Windows' `find`.** Liegt Git Bash im
  PATH, bricht die Prüfung „läuft Hermes gerade" mit `find: '/I': No such file
  or directory` ab. Jetzt stehen alle Systemwerkzeuge mit vollem Pfad drin.
- **`robocopy` meldet 0 bis 7 als Erfolg.** Die Fehlerprüfung liegt in einem
  eigenen Unterprogramm, weil `%ERRORLEVEL%` in einem Klammerblock schon zur
  Parsezeit ersetzt würde.

### Befund 7: Ein Patchskript über Backslash-Pfade zerlegt sie

`"%SystemRoot%\System32\tasklist.exe"` als gewöhnliche Python-Zeichenkette
macht aus `\t` einen Tabulator und aus `\f` einen Seitenvorschub. Der Batch
lief danach stumm ins Leere. Der zweite Reparaturversuch scheiterte erneut, weil
`read_text()` ein einzelnes `\r` still zu `\n` macht und der Suchstring dann
nicht mehr passte. Die Batchdateien wurden am Ende **neu geschrieben statt
gepatcht**. Bei Pfaden mit Backslashes ist das der schnellere Weg.

### Der Rückweg wurde gefahren, nicht geplant

Der Auftrag verlangt das ausdrücklich. Ablauf, alles gemessen:

1. englischen Stand aus der Sicherung zurückgespielt, App gestartet: läuft
2. Installer-Batch echt gefahren: Sicherung angelegt, Deutsch eingespielt, App
   gestartet: läuft
3. Rückweg gefahren (robocopy-Code 3 = Erfolg): englischer Stand wieder da, App
   gestartet: läuft
4. Installer-Batch erneut gefahren: Deutsch wieder da, App läuft

**Endzustand: deutsch eingespielt, Hermes läuft.**
