# Deutsches Sprachpaket für Hermes Desktop

Das ist die deutsche Oberfläche als Quelle. Es ist kein Hermes-Programm,
kein Installer für ein Backend und kein Ersatz für eine vorhandene
Installation.

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

## Linux, am Quellbaum

Im entpackten Sprachpaket, mit einem Git-Checkout von Desktop 0.17.6:

```bash
bash installer/Deutsch_installieren.sh /pfad/zum/hermes-agent
bash installer/Deutsch_zuruecknehmen.sh /pfad/zum/hermes-agent
```

Das erste spielt den Patch ein, das zweite nimmt nur diese Änderung zurück.
Beides bricht ab, wenn die Desktop-Version nicht 0.17.6 ist oder der Patch
nicht sauber passt. Es wird nicht gebaut, nichts installiert und kein
Home-Verzeichnis angefasst.

Danach baut man die Desktop-App selbst, im Quellbaum unter `apps/desktop`.
Dieses Paket tut das nicht.

## Windows, am Quellbaum

Dieselben zwei Befehle in Git Bash, gegen denselben Checkout. Die
`.bat`-Dateien sind ein anderer Weg: sie ersetzen eine schon gebaute
`win-unpacked`-Installation, und nur dann, wenn neben der Batch ein Ordner
`paket` mit `Hermes.exe` und `resources` liegt. Diesen Ordner enthält das
Sprachpaket nicht.

```bat
installer\Deutsch_installieren.bat
installer\Deutsch_zuruecknehmen.bat
```

`Deutsch_zuruecknehmen.bat` stellt die Sicherung
`win-unpacked.vor-deutsch` wieder her. Ohne diese Sicherung löscht sie
nichts. Sie löscht auch keine Profile.

## Was nicht geht

Die Texte hängen am Build. `src/i18n/catalog.ts` importiert `de.ts`, und
`de.ts` ist als `Translations` typisiert, nicht als nachladbare Datei.
Eine fertige Windows- oder Linux-Installation liest dieses Paket nicht
ein. Nur `app.asar` zu tauschen scheitert an der Prüfsumme, die im
Programm selbst steht. Deshalb gibt es hier kein eigenständiges Sprachpaket
für eine schon installierte App.

Wer die `.bat` benutzt, braucht ein `paket`, das zur installierten
Desktop-Version passt. Das ist eine komplette Programmfassung, kein
Sprachpaket, und sie liegt nicht bei.

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

Nicht geprüft: Start unter Windows, ein Klick in einer laufenden App,
eine schon installierte Linux-Fassung. Dazu fehlt genau das Programm,
das dieses Paket nicht enthält.
