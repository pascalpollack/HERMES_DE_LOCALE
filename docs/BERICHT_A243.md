# A243 - Hermes Desktop: Plugin-Stammdaten haben einen Übersetzungsweg

> **Abgeschlossen:** 2026-09-12. Ausführer: PC. Auftragstyp: Bau.
> Vorgänger: A240 (Kernkatalog), A241 (Plugin-Bündel, Startbildschirm),
> A242 (Tab-Beschriftungen).

## Was gebaut wurde

Name und Beschreibung eines Plugins - das, was in der Plugin-Verwaltung auf dem
Schirm steht - können jetzt aus den **eigenen Sprachpaketen des Plugins**
kommen. Beide mitgelieferten Plugins nutzen es: `Bots` und `Kanban`, je in
allen sieben Sprachen.

Der Kernkatalog bleibt außen vor, und das mit Absicht: ein Plugin von der
Platte kennt er nicht, also darf er nicht die Stelle sein, an der Plugins
benannt werden. **Ein Plugin benennt sich selbst.**

## Die Reihenfolgenfalle, die der Auftrag als Abbruchkriterium benannt hatte

Sie ist echt, und sie ist umgangen statt gelöst:

| | |
|---|---|
| Wann entsteht der Inventarsatz? | In `contrib/plugins.ts` Zeile 49, **bevor** `register()` läuft |
| Wann meldet ein Plugin seine Sprachpakete an? | In `register()`, per `ctx.i18n.register(BOTS_LOCALES)` |
| Folge | Ein beim Laden aufgelöster Text wäre entweder leer oder in der Sprache dieses Augenblicks eingefroren |

**Der Ausweg ist derselbe wie in A242: nicht der Datensatz übersetzt, sondern
die Anzeige.** Der Satz trägt zwei neue optionale Felder, `nameKey` und
`descriptionKey` - **Schlüssel, kein Text**. Aufgelöst werden sie beim
Zeichnen, also lange nach `register()`. Am Lebenszyklus der Plugins wurde keine
Zeile geändert, die Bündel bleiben, wo sie waren.

## Warum der englische Klartext bleibt

`name` und `description` im Manifest sind **nicht** verschwunden. Sie sind der
Rückfall, und der ist der Normalfall, nicht der Fehlerfall:

- **Ein abgeschaltetes Plugin hat seine Sprachpakete abgeräumt.** Der Lader
  fährt beim Deaktivieren die Disposer, `registerPluginLocales` löscht den
  Eintrag. Die Zeile bleibt aber in der Liste stehen - mit Schalter, damit man
  sie wieder einschalten kann. Ohne Rückfall stünde dort ab diesem Moment
  `plugin.name`.
- **Ein fremdes Plugin bringt gar keine Übersetzung mit.** Es muss seinen
  englischen Namen zeigen, nicht seine Id.

Erkannt wird der Rückfall am einzigen verfügbaren Signal: `translateFrom` gibt
den **Schlüssel** zurück, wenn nichts auflöst. Genau darauf prüft
`resolvePluginLabel`.

## Vor dem Umbau gemessen: ist `name` eine Kennung?

Dieselbe Prüfung wie bei `title` in A242, und sie fällt genauso aus: **nein.**

| Stelle | was sie benutzt |
|---|---|
| `plugin-packages.ts`, Zusammenführung | den **Ordnernamen** (`packageName`) bzw. `desktop:<id>` - nie `name` |
| `plugins-tab.tsx` Zeile 245, Sprungziel | `agent.key ?? agent.name ?? desktop.id` - nie den Desktop-`name` |
| `use-settings-search.ts`, Suche | `name` nur als Beschriftung; `id` ist eigenes Suchwort |
| `plugins-store.ts`, An/Aus | `id` |

Eine Stelle ist aufgefallen und bleibt bewusst so: `plugin-packages.ts` sortiert
die Liste mit `a.name.localeCompare(b.name)`, also nach dem **englischen**
Namen, während die Anzeige den übersetzten zeigt. Für `Bots` und `Kanban` fällt
das nicht auf, weil beide in jeder lateinisch schreibenden Sprache gleich
heißen. Es weiterzuziehen hieße, die Übersetzung in die Zusammenführung zu
tragen, die keinen Zugriff auf React-Zustand hat - das wäre die Reihenfolgenfalle
durch die Hintertür. Notiert, nicht gebaut.

## Die Teile

| Datei | Änderung |
|---|---|
| `contrib/plugin.ts` | `HermesPlugin` um `nameKey?`, `descriptionKey?` |
| `contrib/plugins-store.ts` | `PluginRecord` um dieselben zwei Felder |
| `contrib/plugins.ts`, `contrib/runtime-loader.ts` | reichen sie durch - mitgelieferte **und** Platten-Plugins |
| `i18n/plugin-i18n.ts` | neu: `usePluginTranslator()` und `resolvePluginLabel()` |
| `app/skills/plugin-packages.ts` | `PluginPackage` trägt `pluginId` und die Schlüssel mit |
| `app/skills/plugins-tab.tsx` | löst beim Zeichnen auf: Name, Beschreibung, drei Vorlesetexte |
| `app/settings/use-settings-search.ts` | dito für die Einstellungssuche |
| `plugins/hermes-bots/i18n.ts`, `plugins/kanban/i18n.ts` | neuer Block `plugin: { name, description }`, je sieben Sprachen |
| beide `plugin.tsx` | verweisen auf `plugin.name` / `plugin.description` |

**`usePluginTranslator` gibt es, weil eine Liste keinen Hook je Zeile haben
kann.** `usePluginI18n(id)` braucht die Plugin-Id beim Aufruf, die Plugin-Seite
zeichnet aber beliebig viele Plugins. Der neue Hook nimmt die Id als Argument
und bleibt genauso reaktiv: er hängt an der Sprache **und** am Änderungszähler
der Registratur, damit ein spät angemeldetes Sprachpaket die Liste neu zeichnet.

## Messwerte

| | |
|---|---|
| Typprüfung `tsc -p . --noEmit` | fehlerfrei |
| Lint der geänderten Dateien | 0 Fehler |
| Tests `src/i18n/plugin-i18n.test.tsx` | 9 von 9, davon **3 neu** |
| Tests `i18n`, `contrib`, `app/skills`, `app/settings`, `plugins` | 1070 von 1072 - die zwei Fehlschläge siehe unten |
| Bau und Pack | grün |
| Probe im gebauten Bündel | `Bot-Modus` 2×, `Aufgabentafel` 1×, russische und japanische Fassung vorhanden |
| App startet | ja, Fenstertitel `Hermes` gemessen |

### Die drei neuen Tests

Sie prüfen die drei Fälle, an denen der Umbau scheitern könnte, und nicht den
einen, der ohnehin geht:

1. übersetzter Name wird bevorzugt,
2. **abgeräumte Sprachpakete** fallen auf den englischen Namen zurück (der
   Deaktivierungsfall, wörtlich nachgestellt: registrieren, Disposer fahren,
   dann auflösen),
3. ein Plugin ganz **ohne** Schlüssel behält seinen Manifestnamen.

## Befund: zwei rote Tests, die nicht zu diesem Auftrag gehören

`app/settings/billing/index.test.tsx` meldet zwei Fehlschläge:
`Threshold: minimum is 10 $.` wird nicht gefunden.

**Gegengeprüft, nicht vermutet.** Ich habe meine Änderung an
`use-settings-search.ts` zurückgenommen (`git checkout --`), den Test erneut
gefahren: **dieselben zwei Fehlschläge**, dann die Datei zurückgespielt. Sie
bestehen also ohne A243.

Die wahrscheinliche Ursache steht in `billing-amounts.ts` Zeile 117:
`new Intl.NumberFormat(undefined, …)` nimmt die **Locale des Rechners**. Auf
einem deutschen Windows wird daraus `10 $` mit einem schmalen geschützten
Leerzeichen, und der Vergleich im Test greift daneben. Das ist ein Messfehler
der Umgebung, kein Fehler der Abrechnung - aber ein Test, der auf einem
deutschen Rechner immer rot ist, ist ein Test, den irgendwann niemand mehr
liest. Gehört in einen eigenen Auftrag.

## Nachtrag 12.09.2026: Sichtprüfung bestätigt

Pascal hat die Oberfläche angesehen und die Stichprobe als in Ordnung gemeldet.
Damit ist **Abnahmekriterium 1 erfüllt**. Der Absatz oben hält fest, wie der
Stand bis dahin belegt war.

### Wie der Stand bis dahin belegt war

Wie bei A240 und A242 war es zunächst nicht mit eigenen Augen belegt. Der Bildschirmzugriff
wurde für A242 abgelehnt; ich habe für A243 nicht erneut gefragt. Belegt ist,
dass die Texte im ausgelieferten Bündel stecken und die App läuft.

Nachzusehen war es in **Capabilities ▸ Plugins**.

## Nachgezogen

- **GitHub-Paket** `Desktop\HERMES_DE_LOCALE`: Patch neu erzeugt (38 Dateien,
  rückwärts geprüft), die neuen Quellen kopiert, Bericht als
  `docs/BERICHT_A243.md`.
- **Weitergebbares Paket** `Documents\HERMES_DEUTSCH\paket`: neu gespiegelt,
  412 Dateien.
- **Leitstand** `WERKZEUGE/hermes-de/quellen/code/`: liegt jetzt im Zuschnitt
  des Quellbaums statt flach - zwei Plugins haben beide eine `plugin.tsx`, und
  flach hätte die eine die andere überschrieben.

Im Hermes-Baum wurde **nicht committet** - er gehört NousResearch.

## Die fünf Ebenen, jetzt vollständig

| Ebene | Auftrag |
|---|---|
| Kernkatalog | A240 |
| Plugin-Sprachpakete | A241 |
| Startbildschirm-Texte | A241 |
| Code-Konstanten in Flächen | A242 |
| Plugin-Stammdaten | A243 |

Zweimal hintereinander hieß der Grund, warum eine Ebene übersehen wurde,
dasselbe: **der Text sah nicht wie ein Text aus.** `title: 'sessions'` sah aus
wie eine Kennung, `name: 'Bots'` wie ein Stammdatum. Beide waren Beschriftungen.
Wer prüfen will, ob eine Anwendung übersetzt ist, findet das nicht in ihrem
Katalog - nur im Fenster.
