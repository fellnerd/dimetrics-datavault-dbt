#!/bin/sh
# Startet ein Python-Skript des Plugins mit dem ersten Interpreter, der die Datei
# tatsaechlich lesen kann.
#
# Hintergrund: Unter Windows ist `python3` haeufig der Microsoft-Store-Alias. Der
# laeuft in einer App-Sandbox und sieht Plugin-Dateien unter AppData nicht
# ("can't open file ... [Errno 2]") — der Hook waere dann still wirkungslos.
# Deshalb wird jeder Kandidat vorab geprueft, statt blind `python3` aufzurufen.
#
# Verwendung (hooks.json):  sh "${CLAUDE_PLUGIN_ROOT}/hooks/pyrun.sh" "${CLAUDE_PLUGIN_ROOT}/hooks/<skript>.py"

script="$1"
shift

for py in python3 python py; do
    command -v "$py" >/dev/null 2>&1 || continue
    if "$py" -c 'import os, sys; sys.exit(0 if os.path.isfile(sys.argv[1]) else 1)' "$script" \
            </dev/null >/dev/null 2>&1; then
        exec "$py" "$script" "$@"
    fi
done

echo "dv-toolkit: kein Python-Interpreter gefunden, der $script lesen kann (geprueft: python3, python, py) — DV-Hook uebersprungen. Python 3 installieren bzw. unter Windows den Store-Alias python3.exe in 'App-Ausfuehrungsaliase' deaktivieren." >&2
exit 1
