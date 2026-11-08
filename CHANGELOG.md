# Changelog

Alle nennenswerten Änderungen an diesem Paket. Die Versionsnummer beschreibt
**dieses Paket**, nicht Hermes selbst. Der Bezugsstand wandert mit den
Hermes-Updates; welcher es ist, steht beim jeweiligen Eintrag.

Die Desktop-Version und die Agenten-Version sind zwei Zahlen. Übersetzt ist
die Desktop-App.

## 1.2.2 - 2026-11-08

Die Weitergabe ist nur der Quellpatch. `README.md` beginnt mit
`SOURCE-PATCH-NOT-BINARY-LANGUAGE-PACK`. Windows spielt denselben Patch
über Git Bash ein, wahlweise über
`installer/Deutsch_quellpatch_einspielen.bat`, das nur Bash startet.
Die alten Ganz-App-Batches liegen unter `installer/legacy-ganze-app/` und
sind nicht der Einbau. Es wird keine App gebaut und keine Prüfsumme umgangen.

## 1.2.1 - 2026-11-08

Weitergabe als Sprachpaket, ohne Programmpaket. `docs/SPRACHPAKET.md` sagt,
wie der Patch auf Linux und Windows in einen Desktop-0.17.6-Quellbaum kommt
und wie er zurückgenommen wird. `installer/Deutsch_installieren.sh` und
`installer/Deutsch_zuruecknehmen.sh` tun nur das. Die vorhandenen
`.bat`-Dateien bleiben der Weg für eine schon gebaute Windows-Fassung und
brauchen weiter einen eigenen Ordner `paket`, der hier nicht liegt.

`werkzeug/locale_pruefen.mjs` vergleicht die Schlüssel des Kernkatalogs und
der Plugin-Bündel. Die README nannte noch Desktop 0.17.2. Der Patch ist der
von 1.2.0 und gilt für 0.17.6.

## 1.2.0 - 2026-09-20

Bezugsstand: **Hermes Desktop 0.17.6** (vorher 0.17.2).

Das Update am 20.09. um 15:15 hat `de.ts` wieder entfernt. Das Nachziehen lief
diesmal **nicht** durch das Werkzeug, weil zwei Dinge im Weg standen:

**Der Patch zeigte auf einen Ordner, den es nicht mehr gibt.** In 0.17.6 heißt
`apps/desktop/src/app/skills/` jetzt `apps/desktop/src/app/capabilities/plugins/`.
`git apply --3way` bricht dann mit „does not exist in index" ab und verwirft
alles, auch die Teile, die sauber gepasst hätten. Der Patch in diesem Repo ist
auf den neuen Pfad umgeschrieben und aus dem Stand 0.17.6 frisch erzeugt.

**Ein Konflikt blieb übrig:** `app/contrib/controller.tsx`. 0.17.6 bringt dort
das Icon `Users` neu, unser Patch macht aus `NEW_SESSION_TITLE` die Funktion
`newSessionTitle()`. Beides wird gebraucht, die Auflösung nimmt beide Seiten.

**Und die Meldestelle war unvollständig.** Der Merksatz „der Compiler nennt
jeden fehlenden Schlüssel" stimmt nur bis zum vierten: ab dem fünften schreibt
`tsc` „and N more" und nennt die Namen nicht mehr. `--noErrorTruncation` ändert
daran nichts, das Flag verlängert nur Typnamen. Wer sich darauf verlässt, zieht
zu wenige Schlüssel nach und merkt es nicht, weil der Build trotzdem läuft.
Gemessen wurde deshalb **Baum gegen Baum**: beide Kataloge mit esbuild gebündelt
und die Schlüsselpfade von `en` gegen `de`, `ru` und `ar` verglichen. Unterschied
zur tsc-Liste: 232 statt 104 Einträge.

Nachgezogen wurden:

- **232 neue Texte** — 139 in `i18n/de.ts`, 29 je Sprachblock in
  `plugins/hermes-bots/i18n.ts` (de, ru, ar), 2 je Block in `plugins/kanban/i18n.ts`
- **6 entfallene Schlüssel entfernt**: `nav.skills` an zwei Stellen (heißt jetzt
  `capabilities`), dazu `mcpSetup.decline`, `declined`, `unanswered`, `catalogSource`
- **drei Typänderungen**: die `mcpSetup`-Titel sind jetzt Zeichenketten statt
  Funktionen mit Servernamen; `connectors.keepWaiting/connectTitle/describe` und
  `localModels.updateToast` gibt es nicht mehr

Belegt: `npx vitest run src/i18n` 34 von 34 grün, `npm run pack` sauber durch,
der deutsche Text liegt im gebauten Bundle.

**Nicht von hier, aber im selben Baum:** `app/chat/sidebar/pinned-loop-control.tsx`
importiert `./header-action-style`, eine Datei, die 0.17.6 nicht mitliefert. Sie
stammt aus einem Commit, der sie selbst als unfertig bezeichnet. Das ist der
einzige verbleibende `tsc`-Fehler und keine Sache der Lokalisierung.

## 1.1.0 - 2026-09-13

Ein Hermes-Update hat die deutsche Fassung wieder entfernt. Diese Fassung
zieht sie nach und sorgt dafür, dass das künftig ohne Handarbeit passiert.

Gebaut gegen **Commit `d595e636c8`**, Desktop weiterhin `0.17.2`.

Noch am selben Tag lief ein weiteres Update durch (`b6b53c69a6`). Das
Werkzeug hat es von allein bemerkt und nachgezogen - der erste Ernstfall,
ungeplant. Der Patch blieb unveraendert gueltig, neue Texte brachte dieses
Update keine. Gegengeprueft mit `git apply --check -R`: er beschreibt den
Unterschied auf **beiden** Staenden exakt.

### Neun neue Texte des Updates

Der Compiler hat sie namentlich genannt, keiner fiel still auf Englisch
zurück - genau dafür ist `de.ts` als `Translations` typisiert:

`sharedGatewayRestartTitle`, `sharedGatewayRestartDescription`,
`sharedGatewayRestartConfirm`, `sharedGatewayRestarted`, `sharedListenerUrl`,
`appliedLive`, `connectingLive`, `pastedContent`, `pasteAttachFailed`.

Die i18n-Tests sind mit dem Update von 31 auf **34** gewachsen, alle grün.

### Neu: `werkzeug/` - Nachziehen ohne Handarbeit

`deutsch_nachziehen.py` macht, was sonst von Hand nötig war: Patch einspielen,
`tsc --noEmit` als Messstelle lesen, neue Schlüssel an den Hermes-Agenten
(`hermes -z`) zum Übersetzen geben, gegenprüfen, Tests fahren, bauen,
Hermes neu starten. Eingefügt wird **im Werkzeug**, nicht von Hermes: der
Agent liefert JSON, die Datei schreibt das Skript.

Läuft über den Autostart bei der Anmeldung, nicht im Stundentakt. Ein Build
muss Hermes beenden; bei der Anmeldung kostet das nichts, mitten in der Arbeit
wäre es ein Übergriff.

**Zwei Befunde aus dem Negativtest**, beide gefunden, weil die kaputte Fassung
tatsächlich hergestellt wurde statt nur beschrieben:

- `tsc` meldet fehlende Schlüssel in **zwei** Formen: `TS2739` im Plural,
  `TS2741` im Singular mit völlig anderem Wortlaut. Das Werkzeug kannte nur
  die Pluralform - und der Normalfall eines Updates ist *ein* neuer Text.
  Die Wache hätte genau dann geschwiegen, wenn sie gebraucht wird.
- Dahinter der eigentliche Fehler: ein Compilerfehler, den kein Muster
  erkennt, wurde als "nichts zu tun" gelesen. Entwarnung aus Unkenntnis.
  Jetzt bricht das Werkzeug in dem Fall ab und zeigt die Rohausgabe.

Geprüft wurde gegen den echten Bestand: ein Schlüssel aus `de.ts` entfernt,
Werkzeug laufen lassen, Ergebnis mit der von Hand gebauten Datei verglichen -
**byteidentisch**.

## 1.0.0 - 2026-09-12

Erste vollständige Fassung. Vollständig heißt hier: die Oberfläche ist auf
Deutsch, auf **allen fünf Ebenen**, auf denen Text in dieser Anwendung liegt.
Jede einzelne war für sich vollständig, und jedes Mal war das Fenster trotzdem
noch nicht ganz deutsch.

### Der Kernkatalog

- Neue Locale `de`: **3773 von 3773 Schlüsselpfaden**. `de.ts` ist als
  `Translations` typisiert, ein fehlender Schlüssel wäre ein Baufehler und kein
  stiller Rückfall auf Englisch. `defineLocale()` für Teilfassungen wird
  bewusst nicht benutzt.
- `Locale`-Typ, `LOCALE_OPTIONS` und 14 Aliasse (`de`, `de-de`, `de-at`,
  `de-ch`, `de-li`, `de-lu`, `german`, `deutsch` plus Unterstrichvarianten).
- Zwei bestehende Tests hielten fest, dass Deutsch **nicht** unterstützt wird;
  beide mussten mit. `context.test.tsx` nutzt jetzt `'xx'` als Beispiel für
  eine unbekannte Sprache, damit der Test weiter misst, was er messen soll.

### Die Plugin-Sprachpakete

- `hermes-bots` und `kanban` führen ihre Strings getrennt vom Kernkatalog und
  kannten nur `en, ja, zh, zh-hant`. Es fehlte also nicht nur Deutsch, sondern
  auch **Russisch und Arabisch**, obwohl die App beide anbietet.
- Ergänzt wurden alle drei: 195 Schlüssel (bots) und 178 (kanban), je Sprache.

### Der Startbildschirm

- `intro-copy.jsonl` hielt 75 Begrüßungstexte und wurde **ohne jeden
  Sprachbezug** geladen - es gab dort keinen Platz für eine zweite Sprache.
- Jetzt eine Datei je Sprache (`intro-copy.<locale>.jsonl`), `resolveCopy`
  bekommt die aktive Locale, fehlende Einträge fallen auf Englisch zurück.
  6 Sprachen × 75 Texte.

### Die Tab-Beschriftungen

- `SESSIONS`, `BOTS`, `NEW SESSION`, `TERMINAL`, `FILES` (dazu `REVIEW` und
  `LOGS`) waren **Konstanten im Code, die zugleich als Kennung dienten** - kein
  Suchlauf nach Übersetzungsschlüsseln findet so etwas, weil es keiner ist.
- Die Doppelrolle ist getrennt: `title` bleibt die englische Kennung (der
  persistierte Layoutbaum, das Zonenmenü und die Tastenkürzel hängen daran),
  der sichtbare Text kommt aus `PaneChrome.tabTitle` - einer **Funktion**,
  weshalb ein Sprachwechsel ohne Neustart greift.
- `NEW_SESSION_TITLE` wurde zu `newSessionTitle()`: eine Modul-Konstante würde
  die Sprache des ersten Imports einfrieren.

### Die Plugin-Stammdaten

- Name und Beschreibung eines Plugins kommen jetzt aus seinen **eigenen**
  Sprachpaketen. Der Kernkatalog bleibt außen vor - ein Plugin von der Platte
  kennt er nicht, also darf er nicht die Stelle sein, an der Plugins benannt
  werden.
- Der Inventarsatz trägt **Schlüssel**, keinen Text (`nameKey`,
  `descriptionKey`): er entsteht, bevor ein Plugin seine Sprachpakete anmeldet.
  Aufgelöst wird beim Zeichnen.
- Der englische Klartext bleibt der Rückfall, und das ist der Normalfall: ein
  abgeschaltetes Plugin hat seine Sprachpakete abgeräumt, muss aber weiter
  „Bots" heißen und nicht `plugin.name`.

### Dazu

- Installer für Windows ohne Toolchain (`installer/`), mit geprobtem Rückweg.
- Vier Berichte unter `docs/` mit Messwerten, Befunden und den Fallen, die beim
  Bauen Zeit gekostet haben.

### Bekannte Lücke

**Die Bilder unter `docs/screenshots/` zeigen einen älteren Stand.** Sie sind
beim Kernkatalog entstanden, also bevor die Tab-Beschriftungen und die
Plugin-Stammdaten übersetzt waren: auf `02-chat-sidebar.png` steht oben noch
`SESSIONS`. Die Oberfläche selbst ist deutsch - geprüft am laufenden
Programm - , die Bilder haben es nur noch nicht eingeholt.

Neue Aufnahmen müssen von Hand gemacht werden: sobald ein Programm den
Bildschirm steuert, zeichnet Windows einen roten Rahmen ins Bild, der sich nicht
abschalten lässt.
