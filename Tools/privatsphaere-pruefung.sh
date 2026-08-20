#!/bin/bash
# Sucht persönliche Daten und Zugangsdaten im Repo — vor jedem Commit.
#
# Die Fassung mit `grep … | head` sieht richtig aus und ist es nicht: In einer
# Pipe zählt der Rückgabewert des LETZTEN Glieds, und `head` gelingt immer.
# Eine so gebaute Prüfung meldet jedes Mal einen Treffer, auch wenn keiner da
# ist — und wer das ein paarmal erlebt, glaubt ihr beim echten Treffer nicht
# mehr. Deshalb hier: Ergebnis erst in eine Variable, dann prüfen.
set -uo pipefail
cd "$(dirname "$0")/.."

persoenlich='/Users/(ipstyle|albert)|frick\.a|ip-style\.com|com~apple~CloudDocs|Mobile Documents/|GEDAECHTNIS_|CLAUDE\.md'
zugang='sk-ant-[A-Za-z0-9]{2,}-[A-Za-z0-9_-]{24,}|sk-[A-Za-z0-9]{32,}|ghp_[a-zA-Z0-9]{30,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY'
urheber='co-authored-by:.*(claude|anthropic)|generated with .*claude'

fehler=0
pruefe() {
  local titel="$1" muster="$2" treffer
  # Die .gitignore ist ausgenommen: Sie nennt die auszuschliessenden Dateien
  # beim Namen, und genau das wäre sonst der Treffer. Dieses Skript ebenfalls,
  # sonst findet es seine eigenen Suchmuster.
  treffer=$(git grep -inE "$muster" -- . \
            ':(exclude)Tools/privatsphaere-pruefung.sh' \
            ':(exclude).gitignore' 2>/dev/null || true)
  if [ -n "$treffer" ]; then
    echo "FEHLER — $titel:"; echo "$treffer" | head -20 | sed 's/^/  /'; fehler=1
  else
    echo "ok — $titel: keine Treffer."
  fi
}

pruefe "persönliche Daten" "$persoenlich"
pruefe "Zugangsdaten"      "$zugang"

verlauf=$(git log --all --format='%B' 2>/dev/null | grep -inE "$urheber" || true)
if [ -n "$verlauf" ]; then
  echo "FEHLER — Claude steht als Mitwirkender in der Historie:"; echo "$verlauf" | sed 's/^/  /'; fehler=1
else
  echo "ok — Urheberschaft: sauber."
fi

adressen=$(git log --all --format='%ae' 2>/dev/null | sort -u | grep -v '@users.noreply.github.com' || true)
if [ -n "$adressen" ]; then
  echo "FEHLER — Commits mit echter Mailadresse: $adressen"; fehler=1
else
  echo "ok — Commit-Adressen: nur noreply."
fi

exit $fehler
