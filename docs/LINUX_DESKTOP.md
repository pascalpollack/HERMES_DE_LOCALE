# Hermes Desktop 0.17.6 für Debian 13 (x86_64)

Dieses Dokument gehört zum Lokalisierungs-Repo. Es beschreibt das Linux-Paket
der **bestehenden** Desktop-App plus den **bestehenden** deutschen Patch.
Es ist kein neues Programm und kein Ersatz für die CLI.

Gebaut und headless geprüft am 08.11.2026 in einer Ubuntu-24.04-Umgebung.
Das ist **kein** Test auf dem Debian-13-Rechner und **kein** Start gegen
`/home/pascal/.hermes`.

## Was das Paket ist

| | |
|---|---|
| Desktop | **0.17.6** (`apps/desktop/package.json`) |
| Quellcommit | `6159bf4d87a32de72869e0b479606ddd2b9977a1` |
| Commit-Datum | 2026-09-20 09:00:16 -0700 |
| Betreff | `runner: drop the RLIMIT_DATA worker cap` |
| Electron | 40.10.2 |
| electron-builder | 26.15.3 |
| Node beim Build | 22.23.4 (Manifest: `^22.22.0 \|\| ^24.11.0 \|\| >=26.0.0`) |
| npm | 10.9.9 |
| Agent im selben Baum | **0.21.3**, Datum `2026.9.14` |
| Statusschema dieses Agenten | 30 (`hermes_state_common.SCHEMA_VERSION`) |
| Config-Schema dieses Agenten | 45 (`DEFAULT_CONFIG["_config_version"]`) |
| Locale-Patch | `0001-hermes-desktop-german-locale.patch` (Fassung 1.2.0 dieses Repos) |
| Install-Stempel | Commit wie oben, `dirty: true`, weil der Patch im Build-Baum uncommittet liegt |

Die Statuszeile des gebauten Fensters zeigt **v0.17.6**. Das ist die
Desktop-App. Die CLI **0.22.7** ist ein anderes, neueres Programm. Dieses
Paket ist auch nicht als identisch mit einer vorhandenen `Hermes.exe`
behauptet: die historische Windows-Notiz zeigt auf
`hermes-agent/apps/desktop/release/win-unpacked/Hermes.exe`, ohne eine
prüfbare Prüfsumme dieser Datei.

### Warum nicht 0.17.2 und nicht das aktuelle main

Die README-Fassung 1.1.0 nennt Desktop 0.17.2 und `d595e636c8`. Das stimmt
für jenen Tag. `apps/desktop/package.json` auf `d595e636c8` ist Version
**0.17.2**, Electron 40.10.2, electron-builder 26.15.3, Ziel
`dist:linux` = AppImage, deb, rpm. Die Datei, die der heutige Patch ändert
(`apps/desktop/src/app/capabilities/plugins/plugins-tab.tsx`), existiert auf
diesem Commit nicht.

`git apply --check` des heutigen Patches scheitert auf Upstream-`main`
`110afdd60e3098b86950963b06a792e261bd36a4` (08.11.2026, Desktop-Versionsfeld
dort `0.0.0`).

Dieselbe Patch-Vorlage passt auf 177 Commits am 20.09.2026, in denen alle
betroffenen Dateien bytegleich sind: von
`5a0fb0f38d2c3d088b286563931ebd95632fc5f6` bis
`6159bf4d87a32de72869e0b479606ddd2b9977a1`. Gebaut wurde der letzte. Deutsch
ist damit der Patch aus diesem Repo, nicht eine neue Übersetzung.

## Pakete

Der Artefaktspeicher nimmt einzelne Dateien bis knapp über 100 MB an und
lehnt etwa 120 MB ab. Die drei Pakete liegen deshalb in 80-MiB-Teilen.
Zusammensetzen steht in `ZUSAMMENSETZEN.txt` neben den Teilen.

Ganze Dateien:

| Datei | Bytes | SHA-256 |
|---|---:|---|
| `Hermes-0.17.6-linux-x86_64.AppImage` | 143849286 | `a81e5496d45d09f779fab9f85e89626a8f5ffcf6b2c37ef94e765e3cb3d004f4` |
| `Hermes-0.17.6-linux-amd64.deb` | 115661968 | `8356f5099ef35aeb919d0c72ea9386a700f265dce1c64e2ebd8bc7c544491736` |
| `Hermes-0.17.6-linux-x64-unpacked.tar.gz` | 156218897 | `3241d61417905a0e2b3b430ae3f8a8c6ece268f1f1abe018d05e7964c6479c11` |
| `linux-unpacked/Hermes` (auch in der AppImage) | 202984664 | `86be74e1f15b848f32112a994a381363a1f295ea50f0b2a761da86017f8b5109` |

Teile, jeweils `split -b 83886080 -d -a 2`:

| Teil | SHA-256 |
|---|---|
| `Hermes-0.17.6-linux-x86_64.AppImage.part-00` | `a7772f79f5624e6815169e7605364294b9a70e7cce2d522bb77842decf2a0af2` |
| `Hermes-0.17.6-linux-x86_64.AppImage.part-01` | `d2fe98f35180ca65b013c175b5b90808d1ed513980cd8b58f81ed313ffd80c1e` |
| `Hermes-0.17.6-linux-amd64.deb.part-00` | `6db397fea09593e74b5284518efadfa186650502f060e22e8dd2521d8e47bcbc` |
| `Hermes-0.17.6-linux-amd64.deb.part-01` | `a0596c60c4ae84c94334dd82b07b5777b87ddf59cc0db5f19e6761cc0046e2e5` |
| `Hermes-0.17.6-linux-x64-unpacked.tar.gz.part-00` | `f8fed96d6e09895d1783f7f3e701c3c164cf3193114110f7740caa9377071dbe` |
| `Hermes-0.17.6-linux-x64-unpacked.tar.gz.part-01` | `54d9150d361206269c918be0c451f65e4f40c92e5f3f1a03ca857ec26aef20b4` |

Die AppImage wurde mit `--appimage-extract` ausgepackt. Die SHA-256 von
`squashfs-root/Hermes` ist gleich der von `linux-unpacked/Hermes`.

Bevorzugt für einen Start ohne root: die AppImage oder das entpackte Archiv.
Das deb installiert nach `/opt/Hermes` und legt `/usr/bin/Hermes` an. Das
braucht root. `postinst` setzt `chrome-sandbox` nur dann setuid, wenn
User-Namespaces fehlen, und installiert ein AppArmor-Profil, wenn AppArmor
das mitgelieferte Profil akzeptiert.

## Laufzeitabhängigkeiten

`ldd` auf dem Hermes-Binary dieser Ubuntu-24.04-Umgebung meldete keine
fehlende Bibliothek. `readelf -d` verlangt unter anderem:

`libgtk-3.so.0`, `libnss3.so`, `libnspr4.so`, `libglib-2.0.so.0`,
`libgio-2.0.so.0`, `libgobject-2.0.so.0`, `libatk-1.0.so.0`,
`libatk-bridge-2.0.so.0`, `libatspi.so.0`, `libcups.so.2`, `libcairo.so.2`,
`libpango-1.0.so.0`, `libX11.so.6`, `libXcomposite.so.1`, `libXdamage.so.1`,
`libXext.so.6`, `libXfixes.so.3`, `libXrandr.so.2`, `libxcb.so.1`,
`libxkbcommon.so.0`, `libgbm.so.1`, `libexpat.so.1`, `libudev.so.1`,
`libasound.so.2`, `libdbus-1.so.3`, `libdrm` indirekt über GBM.

Das deb deklariert:

```
Depends: libgtk-3-0, libnotify4, libnss3, libxss1, libxtst6, xdg-utils,
         libatspi2.0-0, libuuid1, libsecret-1-0
Recommends: libappindicator3-1
```

`libasound.so.2` steht in der NEEDED-Liste des Binaries und fehlt in
`Depends`. Auf Ubuntu 24.04 liefert es `libasound2t64`. Auf Debian 13 heißt
das Paket ebenfalls `libasound2t64`. Wenn der dynamische Linker auf dem
Rechner `libasound.so.2` oder `libgbm.so.1` vermisst, diese Pakete nachziehen.
Die t64-Namen von Debian 13 stellen die alten Sonames bereit; ob
`apt install ./Hermes-….deb` die transitional-Namen `libgtk-3-0` und
`libatspi2.0-0` auflöst, ist hier nicht auf Debian 13 ausgeführt worden.
`libappindicator3-1` ist nur Recommends.

Versionierte glibc-Symbole des Hauptbinaries reichen bis `GLIBC_2.25`.
Gebaut bzw. gelinkt wurde gegen glibc 2.39 (Ubuntu 24.04). Debian 13 hat eine
neuere glibc. Das Binary verlangt kein neueres glibc als die Build-Maschine.

Ohne FUSE startet die AppImage so:

```bash
./Hermes-0.17.6-linux-x86_64.AppImage --appimage-extract-and-run
```

In dieser Umgebung waren User-Namespaces benutzbar (`unshare --user true`).
Das entpackte Binary startete **ohne** `--no-sandbox`. Ein fehlender
Session-Bus (DBus-Fehler im Log) hat das Fenster nicht verhindert. Debian 13
kann unprivilegierte User-Namespaces per AppArmor sperren. Dann endet ein
Start ohne root oft sofort mit einem Sandbox-Fehler. Das deb-`postinst`
fällt in dem Fall auf ein setuid-`chrome-sandbox` zurück. Das ist eine
Eigenschaft des Zielrechners, kein Ersatzbeleg aus dieser Umgebung.

Die App bringt Python nicht mit. Sie sucht ein vorhandenes `hermes` auf
`PATH` oder `HERMES_DESKTOP_HERMES`. Fehlt beides, zeigt sie die
Ersteinrichtung und installiert erst nach einer ausdrücklichen Wahl nach
`$HERMES_HOME/hermes-agent`.

## Deutsch

Der Patch ist vollständig im Paket: im gebauten Renderer liegt
`resources/app.asar.unpacked/dist/assets/i18n-DI9CTScC.js` mit
`Wie soll ich dich nennen` und den übrigen deutschen Katalogtexten.
`npx vitest run src/i18n`: 34 bestanden, darunter `normalizeLocale('de')`,
`de-DE`, `de_AT`, `Deutsch`.

Zwei gemessene Läufe, beide mit `LANG=de_DE.UTF-8`:

1. **Ohne Backend.** `app.getLocale()` liefert `de` (`getMachineProfile`).
   Die Oberfläche bleibt Englisch. `src/i18n/context.tsx` setzt bei
   fehlgeschlagenem `getConfig()` ausdrücklich `DEFAULT_LOCALE` (`en`) und
   wiederholt den Versuch. Solange kein Backend `/api/config` beantwortet,
   erscheint Deutsch nicht. Das erste Bild ist dieser Zustand, danach der
   Timeout-Dialog, weil kein Agent geantwortet hat.

   ![Ohne Backend, englischer Fehlerdialog](screenshots/linux-01-ohne-backend.png)

2. **Mit dem Agenten 0.21.3 aus demselben Commit** und einer Probe-Config
   `display.language: de`, `_config_version: 45`. `document.documentElement.lang`
   ist `de`. Sichtbarer Text aus dem DOM, nicht aus der Bildbeschreibung:
   `SITZUNGEN`, `Neue Sitzung`, `Fähigkeiten`, `Nachrichten`, `Artefakte`,
   `Geplante Jobs`, `Noch keine Sitzungen`, `Neues Projekt`,
   `Stell eine Frage, füge einen Fehler ein oder nenn mir ein Repo.`,
   `Richte Hermes Agent ein`, `Einrichtung nötig`, `v0.17.6`.
   Der Tab `BOTS` ist die Großschreibung von `Bots`. Die deutsche
   Plugin-Zeile `pane.title` ist ebenfalls `Bots`, daran ist die Sprache
   nicht zu erkennen. Ein Satz des **Agenten** im Einrichtungsdialog blieb
   Englisch (`Hermes is not connected to any AI provider yet. …`). Das ist
   Backend-Text, kein fehlender Desktop-Schlüssel.

   ![Einrichtung auf Deutsch](screenshots/linux-02-anbieter.png)

   ![Hauptfenster auf Deutsch](screenshots/linux-03-oberflaeche.png)

Es wurde kein Modell verbunden, kein Login ausgeführt und kein Prompt
gesendet. Der Klick im Test war `Anbieter später wählen`, nur im Probe-Home.

## HERMES_HOME — kein gemeinsamer Start mit dem bestehenden Bestand

Linux-Voreinstellung in `resolveHermesHome()` (`apps/desktop/electron/main.ts`):
`~/.hermes`, sofern `HERMES_HOME` nicht gesetzt ist. Liegt
`HERMES_DESKTOP_USER_DATA_DIR`, und **kein** `HERMES_HOME`, hängt das Home
unter `<userData>/hermes-home`. Electron-Zustand (Fenster, Verbindungen)
liegt sonst in `~/.config/Hermes`.

Ein Start schreibt sofort `$HERMES_HOME/logs/desktop.log`, auch wenn noch
kein Backend läuft.

Findet die App ein `hermes` auf `PATH`, dessen `--version` gelingt, startet
sie es **ohne Rückfrage** als `hermes serve --host 127.0.0.1 --port 0` und
übergibt `HERMES_HOME`. Auf dem Rechner mit CLI 0.22.7 wäre das diese CLI.
Diese Kombination ist **nicht** geprüft. `HERMES_DESKTOP_IGNORE_EXISTING=1`
überspringt vorhandene CLIs und zeigt die Ersteinrichtung. `Install Hermes
locally` würde dann den im Paket verstempelten Commit nach
`$HERMES_HOME/hermes-agent` holen.

Gemessen an Agent 0.21.3, nur in Wegwerfverzeichnissen:

- Frisches Home plus Backend: `state.db` mit Schema **30**, dazu
  `shared-state.db`, `projects.db`, `cron/`, `SOUL.md`, ein Skill-Baum,
  Caches, `install_id`, `.update_check`. Die Probe-`config.yaml` mit
  `_config_version: 45` und `display.language: de` blieb bytegleich
  (`4d923d4b0bc57e9ac49c10692a5cbf1a32f56608fa238f542713f9fadba68d86`).
- Eine Datenbank, deren `schema_version` auf 99 gesetzt war, blieb nach
  erneutem Öffnen bei **99**. `state_meta.fts_storage_version` wurde dabei
  auf `3` geschrieben. Die Versionszahl wird nicht heruntergesetzt
  (`UPDATE` nur bei `current_version < SCHEMA_VERSION`). Die Datei ändert
  sich trotzdem.
- `migrate_config()` bei `_config_version: 99` (dieser Code kennt nur bis 45)
  lässt `config.yaml` unverändert und legt in dem Home trotzdem `SOUL.md`,
  `cache/schema_columns.json` und
  `backups/config/config.yaml.good-…` an.

Es gibt keinen Lesemodus. Ein Start gegen `/home/pascal/.hermes` würde
mindestens das Log schreiben und, sobald die CLI 0.22.7 oder dieser Agent
0.21.3 daran hängt, die Zustandsdateien anfassen. Schema 30 gegen einen
neueren Bestand der CLI 0.22.7 ist kein sicheres Nebeneinander. **Nicht
starten**, bis der Probe-Lauf unten auf dem echten Bildschirm geprüft ist
und ausdrücklich entschieden wird, das echte Home weiter nicht zu verwenden.

`.update_check` im Probe-Home nannte `head`
`6159bf4d87a32de72869e0b479606ddd2b9977a1` und ein anderes Ziel-Commit. Es
wurde kein `hermes update` ausgeführt. Der Prozess wurde danach beendet.

System-Python 3.12.3 in der Build-Umgebung hat SQLite 3.45.1. Dieser Agent
warnt dann und nimmt `journal_mode=DELETE` statt WAL. Das betrifft den
Python-Interpreter, den das Backend wirklich benutzt, nicht das
Electron-Binary.

## Erster Start auf dem Debian-Rechner

Nur Probe-Verzeichnisse. Nicht `/home/pascal/.hermes`, nicht
`~/.config/Hermes`, solange der Probe-Lauf nicht abgeschlossen ist.

Absolute Pfade, damit das Umsetzen von `HOME` die anderen Verzeichnisse nicht verschiebt. `HERMES_DESKTOP_IGNORE_EXISTING=1` lässt die vorhandene CLI 0.22.7 aus.

```bash
PROBE=/home/pascal/hermes-desktop-probe
mkdir -p "$PROBE/unixhome" "$PROBE/userdata" "$PROBE/xdg" "$PROBE/home"

HOME="$PROBE/unixhome" \
XDG_CONFIG_HOME="$PROBE/xdg" \
HERMES_HOME="$PROBE/home" \
HERMES_DESKTOP_USER_DATA_DIR="$PROBE/userdata" \
HERMES_DESKTOP_IGNORE_EXISTING=1 \
LANG=de_DE.UTF-8 \
LC_ALL=de_DE.UTF-8 \
./Hermes-0.17.6-linux-x86_64.AppImage --appimage-extract-and-run
```

Erwartung dieses Schalters: Fenster der echten App, Ersteinrichtung,
**kein** Klon nach `~/.hermes`. Deutsch erscheint erst, wenn ein Backend
`/api/config` liefert und `display.language` fehlt (dann gilt die
OS-Sprache `de`) oder `de` gespeichert ist. Ohne Backend bleibt die
Oberfläche englisch. Das ist das gemessene Verhalten dieser Version.

Nicht anklicken: `Install Hermes locally`, `Repair install`, `Nous Portal`,
Login. Nicht `HERMES_DESKTOP_HERMES` auf die CLI 0.22.7 setzen, um das
echte Home zu lesen. Nicht die echten Dateien `config.yaml` oder `state.db`
in das Probe-Home kopieren.

Wenn das Fenster sofort mit einem Sandbox-Fehler endet, ist das der
User-Namespace-/AppArmor-Fall von oben. Dann ist der nächste Kandidat das
deb, nach einer eigenen Sicherung, weil dessen `postinst` root braucht.
Auch das deb mit denselben vier Variablen starten, nicht über das
Starter-Icon, das `HERMES_HOME` nicht setzt.

## Build nachvollziehen

`werkzeug/linux_desktop_bauen.sh` klont Upstream **außerhalb** dieses Repos,
prüft den Commit, spielt den Patch ein und baut AppImage, deb und das
entpackte Verzeichnis. Der Upstream-Baum wird hier nicht eingecheckt.

Gegen den gebauten Baum, vor dem Paketieren: `npx tsc --noEmit` ohne Fehler,
`npx vitest run src/i18n` 34/34. `npm run build` und
`node scripts/run-electron-builder.mjs --linux AppImage deb` mit
`NODE_OPTIONS=--max-old-space-size=8192`. Das npm-Skript `builder` setzt
16384 und ist auf einer 16-GB-Maschine der falsche Hebel; das Ergebnis ist
dasselbe electron-builder-Skript.
