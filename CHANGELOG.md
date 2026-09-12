# Changelog

Alle nennenswerten Änderungen an diesem Paket. Die Versionsnummer beschreibt
**dieses Paket**, nicht Hermes selbst - gebaut wurde durchgehend gegen
**Hermes Desktop 0.17.2**, Commit `a84a2223f8`.

Die Statuszeile der App zeigt `v0.21.2`: das ist die Version des
Hermes-**Agenten**, nicht die der Desktop-App. Zwei Zahlen, zwei Dinge.

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
