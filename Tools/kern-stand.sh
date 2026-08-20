#!/bin/bash
# Hält fest, gegen welchen Stand des Mac-Projekts hier gebaut wurde.
#
# Der Kern wird nicht kopiert, sondern über einen relativen Pfad eingebunden —
# das spart eine zweite Arbeitskopie, kostet aber die Nachvollziehbarkeit, die
# ein Git-Submodul mitbrächte. Dieses Skript holt sie zurück: Es schreibt den
# Commit-Hash des Mac-Projekts nach KERN-STAND.md.
#
# Ohne Argument: prüfen und melden, ob der Kern sich seit dem letzten Mal
# geändert hat. Mit `--schreiben`: den aktuellen Stand festhalten.
set -euo pipefail

hier="$(cd "$(dirname "$0")/.." && pwd)"
mac="$hier/../../APP_AICockpit/02_Git-Repo"
datei="$hier/KERN-STAND.md"

if [ ! -d "$mac/.git" ]; then
  echo "Das Mac-Projekt liegt nicht unter $mac — Pfad in project.yml und hier anpassen." >&2
  exit 2
fi

jetzt=$(git -C "$mac" rev-parse HEAD)
kurz=$(git -C "$mac" rev-parse --short HEAD)
betreff=$(git -C "$mac" log -1 --format=%s)
schmutzig=$(git -C "$mac" status --porcelain -- AgentDeckCore Package.swift | head -5)

if [ "${1:-}" = "--schreiben" ]; then
  {
    echo "# Stand des Kerns"
    echo
    echo "Gegen diesen Stand des Mac-Projekts ist die iOS-Fassung gebaut."
    echo "Fortschreiben mit \`Tools/kern-stand.sh --schreiben\`."
    echo
    echo "| | |"
    echo "|---|---|"
    echo "| Commit | \`$jetzt\` |"
    echo "| kurz | \`$kurz\` |"
    echo "| Betreff | $betreff |"
    echo "| festgehalten | $(date +%d.%m.%Y) |"
  } > "$datei"
  echo "Festgehalten: $kurz — $betreff"
  exit 0
fi

if [ ! -f "$datei" ]; then
  echo "Noch kein Stand festgehalten. Einmal mit --schreiben aufrufen."
  exit 1
fi

alt=$(grep -oE '`[0-9a-f]{40}`' "$datei" | head -1 | tr -d '`')
if [ "$alt" = "$jetzt" ]; then
  echo "Kern unverändert seit dem letzten Mal ($kurz)."
else
  echo "Der Kern hat sich geändert: $(git -C "$mac" rev-parse --short "$alt") → $kurz"
  echo "Geänderte Kern-Dateien:"
  git -C "$mac" diff --name-only "$alt" HEAD -- AgentDeckCore Package.swift | sed 's/^/  /'
  echo
  echo "Prüfen, ob die iOS-Fassung mitziehen muss, dann: Tools/kern-stand.sh --schreiben"
fi

[ -n "$schmutzig" ] && { echo; echo "Achtung, ungesicherte Änderungen im Kern:"; echo "$schmutzig" | sed 's/^/  /'; }
exit 0
