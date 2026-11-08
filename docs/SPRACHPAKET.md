# SOURCE-PATCH-NOT-BINARY-LANGUAGE-PACK

Quellpatch der deutschen Oberfläche. Kein installierbares Sprachpaket,
kein Programm, kein Tausch von `Hermes.exe` oder `app.asar`.

## Worauf es passt

| | |
|---|---|
| Anwendung | Hermes Desktop, `apps/desktop/package.json` Version **0.17.6** |
| Geprüft an Commit | `6159bf4d87a32de72869e0b479606ddd2b9977a1` |
| Quelle | Nous Research, `hermes-agent`, MIT |
| Patch | `0001-hermes-desktop-german-locale.patch` |
| Patch SHA-256 | `433f68621565b24271ab29934214cbfa67dc79365b074965492db6c8322a84c2` |

Nicht dieser Stand: Desktop 0.17.2 (`d595e636c8`), der aktuelle Upstream-`main`,
und die CLI 0.22.7. Die CLI ist ein anderes Programm. Der Agent im
Desktop-Commit 0.17.6 ist 0.21.3. Zwei Versionsnummern.

Deutsch ist im Upstream nicht enthalten (Issue 51217).

## Linux und Git Bash

Am Git-Checkout von Desktop 0.17.6:

```bash
bash installer/Deutsch_installieren.sh /pfad/zum/hermes-agent
bash installer/Deutsch_zuruecknehmen.sh /pfad/zum/hermes-agent
```

Das erste spielt den Patch ein, das zweite nimmt nur diese Änderung zurück.
Beides bricht ab, wenn die Desktop-Version nicht 0.17.6 ist oder der Patch
nicht sauber passt. Es wird nicht gebaut und kein Home-Verzeichnis angefasst.
Python ist dafür nicht nötig.

## Windows

Dieselben zwei Befehle in Git Bash. Ohne geöffnete Bash starten die
Quellpatch-Batches nur `bash.exe` von Git for Windows und übergeben den
Checkout-Pfad:

```bat
installer\Deutsch_quellpatch_einspielen.bat PFAD\zum\hermes-agent
installer\Deutsch_quellpatch_zuruecknehmen.bat PFAD\zum\hermes-agent
```

Sie kopieren keine Programmdatei. Fehlt Git Bash, enden sie mit Exit 2
und nennen den Befehl für eine offene Git Bash.

## Voraussetzungen für einen späteren eigenen Build

Zum Einspielen reicht Git. Dieses Paket ruft Node nicht auf und entscheidet
nicht, ob eine App gebaut wird. Wer den gepatchten Checkout später selbst
übersetzt, braucht die in `package.json` genannte Spanne von Commit
`6159bf4d87a32de72869e0b479606ddd2b9977a1`: Node
`^22.22.0 || ^24.11.0 || >=26`, npm `<11.10.0 || >=11.17.0`.

## Was das nicht ist

Die Texte hängen am Build. `src/i18n/catalog.ts` importiert `de.ts`.
Eine fertige Windows- oder Linux-Installation liest diesen Patch nicht.
`app.asar` allein zu tauschen scheitert an der Prüfsumme im Programm.
Dieses Paket umgeht diese Prüfung nicht und legt keine Programmdatei bei.

`installer/legacy-ganze-app/` bleibt im Git-Repo liegen. Die Batches dort
ersetzen eine ganze gebaute App und verlangen einen Ordner `paket`, den
es hier nicht gibt. Sie sind nicht im Quell-ZIP.

## Lizenz

MIT. Copyright Nous Research und, für die deutsche Übersetzung, Pascal
Pollack. Der Hinweis steht in `LICENSE` und muss bei Weitergabe dabeibleiben.
Upstream: https://github.com/NousResearch/hermes-agent
(Commit `6159bf4d87a32de72869e0b479606ddd2b9977a1`, Datei `LICENSE`).

## Grenze der Übersetzung

Der Kernkatalog hat dieselben Blätter wie `en.ts`: 3961 von 3961.
`hermes-bots` hat 227 von 227, `kanban` 210 von 210. Die sechs
`intro-copy.<sprache>.jsonl` haben je 75 JSON-Zeilen. Die ältere Zahl
3773 gehört zum Katalog von Desktop 0.17.2. Ein abgeschaltetes Plugin
ohne eigenes Bündel, etwa Radio, zeigt weiter den englischen Klartext.
Das ist das Verhalten der App, kein fehlender Kernschlüssel.

Neue Profile, Verläufe und Anmeldungen legt dieses Paket nicht an und
übernimmt keine.

## Prüfung

Statisch, auf Linux, ohne die App zu starten: `node werkzeug/locale_pruefen.mjs`
mit dem TypeScript aus einem Hermes-Checkout. Ergebnis: Kern 3961/3961,
Bots 227/227, Kanban 210/210, Intro je 75 Zeilen, Aliasliste vollständig.

Am Quellbaum von Commit `6159bf4d87a32de72869e0b479606ddd2b9977a1`:
`Deutsch_installieren.sh` spielt den Patch ein, ein zweiter Lauf ändert
nichts, `Deutsch_zuruecknehmen.sh` entfernt ihn, ein zweiter Rücklauf
bricht ab. Ein Baum mit Desktop 0.17.2 wird abgelehnt und bleibt ohne
`de.ts`. Das ist ein echter `git apply` gegen diesen Commit, kein Mock.

Die Windows-Batches `Deutsch_quellpatch_*.bat` wurden nicht unter Windows
gestartet. Sie rufen nur die hier geprüften Shell-Skripte auf.

Nicht geprüft: ein Klick in einer laufenden App und eine schon installierte
Fassung. Dazu fehlt das Programm, das dieses Paket nicht enthält.
