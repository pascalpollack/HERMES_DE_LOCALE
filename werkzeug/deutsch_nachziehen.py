# -*- coding: utf-8 -*-
"""
Zieht die deutsche Oberflaeche von Hermes Desktop nach einem Update wieder ein.

Ein Hermes-Update setzt den Quellbaum zurueck: de.ts ist weg, der Build ist
englisch. Dieses Werkzeug stellt den Zustand wieder her, und zwar so, dass
neue Texte des Updates NICHT still auf Englisch zurueckfallen.

Der Compiler ist die Meldestelle. de.ts ist als `Translations` typisiert,
also nennt `tsc --noEmit` jeden Schluessel namentlich, den das Update neu
gebracht hat. Genau diese Liste geht an Hermes zum Uebersetzen.

Ablauf:
  1. messen      Liegt de.ts? Fehlen Schluessel? Sonst ist nichts zu tun.
  2. patchen     git apply --3way mit dem Patch aus diesem Repo.
  3. messen      tsc --noEmit. Fehlende Schluessel ausgelesen, nicht geraten.
  4. uebersetzen Hermes headless (-z) liefert JSON. EINGEFUEGT WIRD HIER:
                 Hermes schreibt nicht selbst in die Datei.
  5. pruefen     tsc erneut, dann die i18n-Tests.
  6. bauen       Hermes beenden, npm run pack, Hermes starten.

Aufruf:
  python deutsch_nachziehen.py                 normal
  python deutsch_nachziehen.py --nur-pruefen   nur messen, nichts aendern
  python deutsch_nachziehen.py --ohne-neustart Hermes nicht wieder starten
"""

import argparse
import io
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime

HIER = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HIER)
PATCH = os.path.join(REPO, "0001-hermes-desktop-german-locale.patch")

BAUM = r"E:\HIRON_WERKSTATT\adapters\hermes\home\hermes-agent"
DESKTOP = os.path.join(BAUM, "apps", "desktop")
I18N = os.path.join(DESKTOP, "src", "i18n")
DE_TS = os.path.join(I18N, "de.ts")
EN_TS = os.path.join(I18N, "en.ts")
HERMES_CLI = r"E:\HIRON_WERKSTATT\adapters\hermes\home\bin\hermes.exe"
HERMES_EXE = os.path.join(DESKTOP, "release", "win-unpacked", "Hermes.exe")
LOG = os.path.join(HIER, "nachziehen_log.md")

# Windows-Konsole kann cp1252 sein. Die Ausgabe darf daran nicht sterben.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")


def sag(text):
    zeile = "[%s] %s" % (datetime.now().strftime("%H:%M:%S"), text)
    print(zeile, flush=True)
    with io.open(LOG, "a", encoding="utf-8") as f:
        f.write(zeile + "\n")


def lauf(befehl, cwd=None, timeout=1800):
    """Ohne text=True: Windows nimmt sonst cp1252 und zerstoert Umlaute."""
    e = subprocess.run(befehl, cwd=cwd, capture_output=True, timeout=timeout)
    aus = (e.stdout or b"").decode("utf-8", "replace")
    fehl = (e.stderr or b"").decode("utf-8", "replace")
    return e.returncode, aus, fehl


def npx(args):
    return lauf(["npx.cmd"] + args, cwd=DESKTOP)


# ---------------------------------------------------------------- Schritt 3

# tsc meldet fehlende Schluessel in ZWEI Formen, je nach Anzahl. Beide muessen
# hier stehen: die Singularform ist der haeufigere Fall, ein Update bringt oft
# genau einen neuen Text.
#   mehrere: TS2739 "is missing the following properties from type '...': a, b"
#   einer:   TS2741 "Property 'a' is missing in type '...' but required in ..."
MUSTER_MEHRERE = re.compile(
    r"^(?P<datei>[^(]+)\((?P<zeile>\d+),\d+\): error TS\d+: .*?"
    r"is missing the following propert(?:y|ies) from type '.*?': (?P<namen>.+)$"
)
MUSTER_EINER = re.compile(
    r"^(?P<datei>[^(]+)\((?P<zeile>\d+),\d+\): error TS\d+: "
    r"Property '(?P<name>[^']+)' is missing in type "
)


def fehlende_schluessel():
    """Liefert ([(zeile_in_de_ts, [schluessel, ...])], rohausgabe, tsc_code).

    Der tsc-Code gehoert mit ins Ergebnis. Ein Fehler, den kein Muster
    erkennt, darf NICHT als "nichts zu tun" durchgehen: das waere eine
    Entwarnung aus Unkenntnis. Der Aufrufer bricht in dem Fall ab.
    """
    code, aus, fehl = npx(["tsc", "--noEmit"])
    if code == 0:
        return [], "", 0
    text = aus + fehl
    treffer = []
    for zeile in text.splitlines():
        zeile = zeile.strip()
        m = MUSTER_MEHRERE.match(zeile)
        if m and "de.ts" in m.group("datei"):
            namen = [n.strip() for n in m.group("namen").split(",") if n.strip()]
            treffer.append((int(m.group("zeile")), namen))
            continue
        m = MUSTER_EINER.match(zeile)
        if m and "de.ts" in m.group("datei"):
            treffer.append((int(m.group("zeile")), [m.group("name")]))
    return treffer, text, code


def en_quelltext(schluessel):
    """Englische Originalzeile eines Schluessels, samt Vorgaengerzeile als Anker."""
    zeilen = io.open(EN_TS, encoding="utf-8").read().splitlines()
    for i, z in enumerate(zeilen):
        if re.match(r"^\s*%s:" % re.escape(schluessel), z):
            vor = zeilen[i - 1] if i > 0 else ""
            return z.strip(), vor.strip()
    return None, None


# ---------------------------------------------------------------- Schritt 4

AUFTRAG = """Du uebersetzt Oberflaechentexte der Hermes-Desktop-App ins Deutsche.

Hier sind neue englische Eintraege aus en.ts. Uebersetze JEDEN ins Deutsche.

Regeln:
- Antworte NUR mit einem JSON-Objekt, keine Erklaerung davor oder danach.
- Schluessel = der Bezeichner, Wert = die vollstaendige TypeScript-Zeile auf
  Deutsch, genau im Format der englischen Zeile, mit abschliessendem Komma.
- Ist der Wert eine Pfeilfunktion, bleibt die Signatur unveraendert; nur der
  Text im Template-String wird uebersetzt.
- Doppelte Anfuehrungszeichen fuer Zeichenketten, Backticks bei Templates.
- Echte Umlaute schreiben, keine Ersatzschreibung wie ae oder ue.
- Du-Form, wie in der uebrigen Oberflaeche.
- Fachbegriffe der App bleiben stehen: Gateway, Bot, Token, Plugin, Skill.

Eintraege:
%s
"""


def hermes_uebersetzt(eintraege):
    """eintraege: {schluessel: englische_zeile} -> {schluessel: deutsche_zeile}"""
    block = "\n".join(eintraege[k] for k in eintraege)
    code, aus, fehl = lauf(
        [HERMES_CLI, "-z", AUFTRAG % block],
        cwd=os.path.dirname(HERMES_CLI),
        timeout=900,
    )
    if code != 0:
        sag("FEHLER Hermes antwortete nicht (Code %d): %s" % (code, fehl[:400]))
        return None
    m = re.search(r"\{.*\}", aus, re.S)
    if not m:
        sag("FEHLER Hermes lieferte kein JSON. Antwort: %s" % aus[:400])
        return None
    try:
        return json.loads(m.group(0))
    except ValueError as e:
        sag("FEHLER Hermes lieferte kaputtes JSON: %s" % e)
        return None


def block_ende(zeilen, start):
    """Ende des Objektblocks, der bei `start` (0-basiert) beginnt."""
    tiefe = 0
    for i in range(start, len(zeilen)):
        tiefe += zeilen[i].count("{") - zeilen[i].count("}")
        if i > start and tiefe <= 0:
            return i
    return len(zeilen) - 1


def einfuegen(de_zeile_nr, neue):
    """Fuegt {schluessel: deutsche_zeile} an der richtigen Stelle in de.ts ein.

    Der Anker ist der Vorgaengerschluessel aus en.ts, gesucht NUR innerhalb des
    Blocks, den tsc gemeldet hat. Sonst trifft ein Allerweltsname wie `search`
    die falsche Stelle: solche Namen kommen in de.ts mehrfach vor.
    """
    zeilen = io.open(DE_TS, encoding="utf-8").read().splitlines()
    start = de_zeile_nr - 1
    ende = block_ende(zeilen, start)
    einzug = "    "
    if start + 1 < len(zeilen):
        einzug = re.match(r"^(\s*)", zeilen[start + 1]).group(1)

    for schluessel in neue:
        deutsche = neue[schluessel]
        _, anker = en_quelltext(schluessel)
        anker_name = None
        if anker:
            m = re.match(r"^\s*([A-Za-z_$][\w$]*):", anker)
            if m:
                anker_name = m.group(1)
        ziel = None
        if anker_name:
            for i in range(start, ende + 1):
                if re.match(r"^\s*%s:" % re.escape(anker_name), zeilen[i]):
                    ziel = i + 1
                    break
        if ziel is None:
            ziel = start + 1  # erster Eintrag im Block
            sag("  Hinweis: kein Anker fuer %s, an den Blockanfang gesetzt" % schluessel)
        zeilen.insert(ziel, einzug + deutsche.strip())
        ende += 1

    io.open(DE_TS, "w", encoding="utf-8", newline="\n").write("\n".join(zeilen) + "\n")


# ---------------------------------------------------------------- Schritt 6

def hermes_laeuft():
    code, aus, _ = lauf(["tasklist.exe", "/FI", "IMAGENAME eq Hermes.exe"])
    return "Hermes.exe" in aus


def hermes_beenden():
    if not hermes_laeuft():
        return True
    sag("Beende Hermes fuer den Build...")
    lauf(["taskkill.exe", "/IM", "Hermes.exe", "/F"])
    for _ in range(15):
        time.sleep(1)
        if not hermes_laeuft():
            sag("Hermes beendet.")
            return True
    sag("FEHLER Hermes laesst sich nicht beenden.")
    return False


# ---------------------------------------------------------------- Hauptlauf

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--nur-pruefen", action="store_true")
    p.add_argument("--ohne-neustart", action="store_true")
    a = p.parse_args()

    with io.open(LOG, "a", encoding="utf-8") as f:
        f.write("\n## Lauf %s\n" % datetime.now().strftime("%Y-%m-%d %H:%M"))

    if not os.path.isdir(DESKTOP):
        sag("FEHLER Quellbaum nicht gefunden: %s" % DESKTOP)
        return 1

    # --- 1. messen
    liegt = os.path.isfile(DE_TS)
    sag("de.ts liegt: %s" % ("ja" if liegt else "NEIN, ein Update hat sie entfernt"))

    if a.nur_pruefen:
        if not liegt:
            sag("Nachziehen noetig: die deutsche Locale fehlt.")
            return 2
        fehlt, ausgabe, tsc_code = fehlende_schluessel()
        if fehlt:
            alle = [k for _, namen in fehlt for k in namen]
            sag("Nachziehen noetig: %d neue Texte (%s)" % (len(alle), ", ".join(alle)))
            return 2
        if tsc_code != 0:
            sag("ACHTUNG Der Compiler meldet Fehler, die kein Muster erkennt:")
            sag(ausgabe[:1200])
            return 2
        sag("Alles deutsch, nichts zu tun.")
        return 0

    # --- 2. patchen
    if not liegt:
        sag("Spiele den Patch ein...")
        code, aus, fehl = lauf(["git", "apply", "--3way", PATCH], cwd=BAUM)
        if code != 0:
            sag("FEHLER Der Patch passt nicht mehr auf diesen Stand:")
            sag((fehl or aus)[:1500])
            sag("Das ist kein Fall fuer den Automaten. Hier muss jemand draufsehen.")
            return 1
        sag("Patch eingespielt.")

    # --- 3. messen, was das Update Neues brachte
    fehlt, ausgabe, tsc_code = fehlende_schluessel()
    if not fehlt and tsc_code != 0:
        sag("FEHLER Der Compiler meldet etwas, das dieses Werkzeug nicht kennt:")
        sag(ausgabe[:1500])
        sag("Kein Build. Hier muss jemand draufsehen.")
        return 1
    if fehlt:
        alle = [k for _, namen in fehlt for k in namen]
        sag("Das Update brachte %d neue Texte: %s" % (len(alle), ", ".join(alle)))

        for zeile_nr, namen in fehlt:
            eintraege = {}
            for k in namen:
                en, _ = en_quelltext(k)
                if en:
                    eintraege[k] = en
                else:
                    sag("  WARNUNG kein englisches Original fuer %s" % k)
            if not eintraege:
                continue
            sag("  Uebergebe %d Texte an Hermes..." % len(eintraege))
            neue = hermes_uebersetzt(eintraege)
            if not neue:
                sag("Uebersetzung fehlgeschlagen. de.ts bleibt unvollstaendig, kein Build.")
                return 1
            einfuegen(zeile_nr, neue)
            sag("  Eingefuegt: %s" % ", ".join(neue.keys()))

        # --- 5. gegenpruefen
        fehlt2, ausgabe2, code2 = fehlende_schluessel()
        if fehlt2 or code2 != 0:
            sag("FEHLER Nach der Uebersetzung ist der Compiler nicht zufrieden:")
            sag(ausgabe2[:1200])
            return 1
        sag("Compiler fehlerfrei.")
    else:
        sag("Keine neuen Texte. Compiler fehlerfrei.")

    code, aus, fehl = npx(["vitest", "run", "src/i18n"])
    if code != 0:
        sag("FEHLER Die i18n-Tests sind rot. Kein Build.")
        sag((aus + fehl)[-1200:])
        return 1
    sag("i18n-Tests gruen.")

    # --- 6. bauen
    if not hermes_beenden():
        return 1
    sag("Baue die deutsche Fassung. Das dauert einige Minuten...")
    code, aus, fehl = lauf(["npm.cmd", "run", "pack"], cwd=DESKTOP, timeout=3600)
    if code != 0:
        sag("FEHLER Der Build ist fehlgeschlagen:")
        sag((aus + fehl)[-1500:])
        return 1
    if not os.path.isfile(HERMES_EXE):
        sag("FEHLER Der Build lief durch, aber Hermes.exe fehlt.")
        return 1
    sag("Gebaut: %s" % HERMES_EXE)

    if not a.ohne_neustart:
        subprocess.Popen([HERMES_EXE], cwd=os.path.dirname(HERMES_EXE))
        sag("Hermes gestartet. Die Oberflaeche ist wieder deutsch.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
