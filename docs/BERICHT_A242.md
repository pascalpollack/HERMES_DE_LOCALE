# A242 - Hermes Desktop: Tab-Titel sind Konstanten, nicht Übersetzungsschlüssel

> **Abgeschlossen:** 2026-09-12. Ausführer: PC. Auftragstyp: Bau.
> Vorgänger: A240 (Kernkatalog), A241 (Plugins und Startbildschirm).

## Was gebaut wurde

Die Tab-Beschriftungen über dem Fenster - `SESSIONS`, `BOTS`, `NEW SESSION`,
`TERMINAL`, `FILES` - lesen ihren Text jetzt aus dem Übersetzungskatalog statt
aus Konstanten im Code. Dazu kommen die beiden Tabs, die nur zeitweise da sind:
`REVIEW` und `LOGS`.

Der Weg ist der, den der Auftrag als wahrscheinlich richtig vermutet hatte, und
die Vermutung hat gehalten: **`title` bleibt unverändert die englische Kennung,
der sichtbare Text kommt neu aus `data.tabTitle`.** Das ist eine Funktion, die
bei jedem Rendern aufgerufen wird, kein fester Text.

## Der Unterschied zwischen Kennung und Beschriftung

Vor dem Umbau gemessen, nicht angenommen:

| Frage | gemessen |
|---|---|
| Wird `title` als Schlüssel benutzt? | **Nein.** Der persistierte Baum (`GroupNode` in `components/pane-shell/tree/model.ts`) trägt `panes: string[]` und `active: string` - Pane-**ids**, keine Titel. |
| Was liest `title` sonst? | Zonenmenü (Tab zeigen/verbergen), die ⌘K-Umschalter, der Text am gezogenen Tab. Alles Anzeige oder Suchwort. |
| Gab es schon einen Haken für einen eigenen Tab-Titel? | **Ja**, `PaneChrome.tabTitle`, bis dahin nur von Sitzungs-Tabs und Browser-Tabs benutzt. |

Damit war der Umbau gefahrlos: an `title` wurde keine Zeile geändert. Das ist
zugleich die Antwort auf Abnahmekriterium 3 - eine gespeicherte Aufteilung kann
gar nicht beschädigt werden, weil in ihr nie ein Titel stand.

## Die Fundstellen und was aus ihnen wurde

| Sichtbar | Datei | vorher | nachher |
|---|---|---|---|
| SESSIONS | `app/contrib/controller.tsx` | `title: 'sessions'` | `title` bleibt, `tabTitle: () => translateNow('zones.paneTitles.sessions')` |
| TERMINAL | `app/contrib/controller.tsx` | `title: 'terminal'` | dito, `…paneTitles.terminal` |
| FILES | `app/contrib/controller.tsx` | `title: 'files'` | dito, `…paneTitles.files` |
| REVIEW | `app/contrib/controller.tsx` | `title: 'review'` | dito, `…paneTitles.review` |
| LOGS | `app/contrib/controller.tsx` | `title: 'logs'` | dito, `…paneTitles.logs` |
| BOTS | `plugins/hermes-bots/plugin.tsx` | `title: 'Bots'` | `tabTitle: () => ctx.i18n.t('pane.title')` aus dem Plugin-Bündel |
| NEW SESSION | `lib/chat-runtime.ts` | `const NEW_SESSION_TITLE = 'New session'` | `function newSessionTitle()` |

Neu im Katalog: `zones.paneTitles` mit sechs Schlüsseln, in **allen sieben
Sprachen** (`en, de, ru, ja, zh, zh-hant, ar`). Der Typ `Translations` erzwingt
das, eine fehlende Sprache wäre bei der Typprüfung rot geworden. Im Plugin
`hermes-bots` entsprechend `pane.title`, ebenfalls siebenmal.

## Warum aus der Konstante eine Funktion wurde

`NEW_SESSION_TITLE` war ein Modul-Konstante. Ein übersetzter Text darf das nicht
sein: der Wert würde beim ersten Import eingefroren, also in der Sprache, die
beim Start galt. Aus der Konstante wurde deshalb `newSessionTitle()`, und die
sechs Aufrufstellen wurden vor dem Umbau frisch gegriffen, nicht aus dem
Auftragstext übernommen - es waren sechs, der Auftrag nannte drei.

Eine davon ist ein React-Baustein, `SessionDraftTitle`. Der liest den
Platzhalter jetzt nicht über `newSessionTitle()`, sondern über `useI18n()`:

```tsx
const { t } = useI18n()
const draft = useStoreSelector($draftTitles, titles => draftTitleIn(titles, scope))

return draft || t.zones.paneTitles.newSession
```

Grund: `translateNow` ist nicht reaktiv, es liest nur die gerade gesetzte
Sprache. Ein Baustein, der nichts abonniert, würde beim Sprachwechsel nicht neu
zeichnen. `useI18n` schon.

## Zu Abnahmekriterium 2: der Sprachwechsel greift ohne Neustart

Belegt, nicht vermutet. Die Kette:

1. Die Tab-Beschriftung entsteht in `tree-group.tsx` Zeile 406:
   `paneChrome(paneFor(paneId)).tabTitle?.() ?? paneFor(paneId)?.title ?? paneId`.
2. Dieser Baustein liest `const { t } = useI18n()` (Zeile 128 und 235). Bei
   einem Sprachwechsel wechselt der Kontextwert, der Baustein zeichnet neu.
3. Beim Neuzeichnen wird `tabTitle()` erneut aufgerufen - und damit
   `translateNow` erneut, mit der inzwischen gesetzten Sprache.

Ein `title` wäre an dieser Stelle stehengeblieben, weil er nur beim Registrieren
der Fläche entsteht. Genau darum steht der neue Text in `tabTitle`.

## Messwerte

| | |
|---|---|
| Typprüfung `tsc -p . --noEmit` | fehlerfrei |
| Lint der geänderten Dateien | 0 Fehler |
| Tests `src/i18n` + `hermes-bots` | 40 von 40 |
| Tests `app/chat`, `app/contrib`, `components/pane-shell` | **1295 von 1295** in 169 Dateien |
| Bau `npm run build` | grün, 51,6 s |
| Paket `npm run pack` | grün, `release/win-unpacked` neu |
| Probe im gebauten Bündel | `Sitzungen` 54×, `Neue Sitzung` 12×, `Dateien` 44×, `paneTitles` 14× |
| Eingespielt | ja - die installierte App **ist** `release/win-unpacked` |
| App startet | ja, Fenstertitel `Hermes` gemessen |
| Aktive Sprache | `config.yaml`: `language: de` |

## Nachtrag 12.09.2026: Sichtprüfung bestätigt

Pascal hat die Oberfläche angesehen und die Stichprobe als in Ordnung gemeldet.
Damit ist **Abnahmekriterium 1 erfüllt**: die Tabs stehen auf Deutsch. Der
Absatz oben hält fest, wie der Stand bis dahin belegt war.

### Wie der Stand bis dahin belegt war

Bis zu Pascals Blick war Abnahmekriterium 1 nicht mit eigenen Augen belegt. Der Bildschirmzugriff
wurde abgelehnt, als ich ihn für den Screenshot angefragt habe - dasselbe wie
bei A240. Belegt ist: die deutschen Tab-Texte stecken im ausgelieferten Bündel
unter `resources/app.asar.unpacked/dist/assets/`, die App läuft, und ihre
eingestellte Sprache ist Deutsch. Dass die Tabs **auf dem Schirm** `Sitzungen`
zeigen, hat niemand gesehen.

## Befund: eine Übersetzung hat vier Ebenen, und die vierte sieht aus wie Code

A241 endete mit der Zählung Katalog, Plugin-Bündel, Startbildschirm-Texte,
Code-Konstanten. A242 hat die vierte abgeräumt und dabei gezeigt, woran sie so
schwer zu finden war: **diese Texte sahen nicht wie Texte aus.** `title:
'sessions'` liest sich wie eine Kennung, nicht wie eine Beschriftung - und war
beides zugleich. Kein Suchlauf nach Übersetzungsschlüsseln findet so etwas,
weil es keiner ist.

Der Ausweg ist der Umbau selbst: die Doppelrolle wurde getrennt. `title` ist
jetzt ausschließlich Kennung, `tabTitle` ausschließlich Beschriftung. Wer das
nächste Mal sucht, was auf dem Schirm steht, findet es an einer Stelle.

## Befund: A241 hat eine Leerzeile und einen Docstring mitgenommen

Beim Ergänzen der drei Sprachen in `plugins/hermes-bots/i18n.ts` ist die
Kommentarzeile über `BOTS_LOCALES` verlorengegangen, samt Leerzeile davor - 
eine Lint-Warnung, die vorher nicht da war. Hier wieder eingesetzt. Ein Einschub
mitten in eine Datei nimmt leicht das mit, was am Einschubpunkt stand; die
Lint-Warnung war der einzige Zeuge.

## Was nicht gemacht wurde

`plugins/hermes-bots/plugin.tsx` Zeile 95, `name: 'Bots'`, ist **nicht**
übersetzt. Das ist nicht die Tab-Beschriftung, sondern der Name des Plugins in
der Plugin-Verwaltung, und der wird dort neben `id` und `description` als
Stammdatum geführt - für Plugin-Stammdaten gibt es in Hermes keinen
Übersetzungsweg. Ihn zu bauen ist ein eigener Auftrag, kein Nebensatz in diesem.

## Nachgezogen

- **GitHub-Paket** `Desktop\HERMES_DE_LOCALE`: Patch neu erzeugt (27 Dateien,
  6614 Zeilen, rückwärts gegen den Baum geprüft), Quellen kopiert, README
  ergänzt, dieser Bericht als `docs/BERICHT_A242.md`.
- **Weitergebbares Paket** `Documents\HERMES_DEUTSCH\paket`: `Hermes.exe` und
  `resources` aus dem neuen Bau gespiegelt, 412 Dateien.
- **Leitstand** `WERKZEUGE/hermes-de/quellen`: die Sprachdateien aller sieben
  Sprachen und neu ein Ordner `code/` mit den sechs geänderten Code-Dateien.

Im Hermes-Baum wurde **nicht committet** - er gehört NousResearch.
