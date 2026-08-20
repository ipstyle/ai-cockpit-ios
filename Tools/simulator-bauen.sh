#!/bin/bash
# Baut die App für den Simulator und startet sie.
#
# Warum eigens ein Skript: Ein unsignierter Build trägt zwar die
# Berechtigungsdatei, aber keine Signatur, die sie beglaubigt. Der
# Schlüsselbund antwortet dann mit -34018 («fehlende Berechtigung») — was wie
# ein Fehler der App aussieht und keiner ist. Für den Simulator wird die Datei
# deshalb weggelassen; die App landet dann in ihrer eigenen Standardgruppe,
# und der Schlüsselbund funktioniert.
#
# Deshalb wird hier ad hoc signiert, mit Tools/simulator.entitlements: eine
# App-Kennung ohne Team-Präfix, die der Simulator akzeptiert. Der Pfad muss
# absolut sein: `CODE_SIGN_ENTITLEMENTS` gilt für jedes Ziel der Projektmappe,
# und für das Kern-Paket liegt der Projektwurzelpfad im Mac-Projekt.
#
# Was damit NICHT geprüft ist: ob die geteilte Gruppe mit dem echten Team-Präfix
# trägt und ob die Widget-Erweiterung mitliest. Das zeigt erst ein signierter
# Lauf auf einem echten Gerät.
set -euo pipefail
cd "$(dirname "$0")/.."

geraet="${1:-iPhone 17 Pro}"
ableitung="${DERIVED:-$HOME/Library/Caches/AICockpitMobile-Build}"

xcodegen generate >/dev/null
xcodebuild -project AICockpitMobile.xcodeproj -scheme AICockpitMobile \
  -destination "platform=iOS Simulator,name=$geraet" \
  -derivedDataPath "$ableitung" \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=YES CODE_SIGNING_ALLOWED=YES \
  CODE_SIGN_ENTITLEMENTS="$PWD/Tools/simulator.entitlements" \
  build 2>&1 | grep -E "error:|warning:|BUILD" | sort -u

app="$ableitung/Build/Products/Debug-iphonesimulator/AICockpitMobile.app"
[ -d "$app" ] || { echo "Kein Bauergebnis unter $app" >&2; exit 1; }

xcrun simctl boot "$geraet" 2>/dev/null || true
xcrun simctl install "$geraet" "$app"
xcrun simctl launch "$geraet" com.ip-style.aicockpitmobile
echo "Gestartet auf $geraet."
