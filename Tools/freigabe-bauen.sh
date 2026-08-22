#!/usr/bin/env bash
# Baut, signiert und prüft die Fassung für den App Store — iPhone, iPad und Uhr.
#
# Bis Build 8 gab es dieses Skript nicht; gebaut wurde von Hand. Mit der
# Uhr-Fassung sind es vier Pakete in einem Archiv, jedes mit eigener Kennung und
# eigenem Profil — das ist nichts, was man zweimal fehlerfrei tippt.
#
# **Kein Cloud-Signing.** Alberts App-Store-Connect-Schlüssel hat dafür nicht die
# Rechte; jeder Versuch endet in einer Fehlermeldung, die nach etwas anderem
# aussieht. Die Profile müssen vorher über die Schnittstelle angelegt sein und
# unter ~/Library/MobileDevice/Provisioning Profiles/ liegen.
#
#   ./Tools/freigabe-bauen.sh            baut und prüft
#   ./Tools/freigabe-bauen.sh --hochladen  baut, prüft und lädt hoch
set -euo pipefail
cd "$(dirname "$0")/.."

ARCHIV="$PWD/build/AICockpitMobile.xcarchive"
AUSGABE="$PWD/build/export"
rm -rf "$ARCHIV" "$AUSGABE"; mkdir -p build

echo "▸ Projekt erzeugen"
xcodegen generate >/dev/null

FASSUNG=$(grep -m1 'MARKETING_VERSION:' project.yml | sed -E 's/.*"(.*)".*/\1/')
BAU=$(grep -m1 'CURRENT_PROJECT_VERSION:' project.yml | sed -E 's/.*"(.*)".*/\1/')
echo "  Fassung $FASSUNG ($BAU)"

echo "▸ Tests"
xcodebuild test -scheme AICockpitMobile \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -quiet | tail -5

echo "▸ Archivieren"
xcodebuild archive -scheme AICockpitMobile \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIV" \
  DEVELOPMENT_TEAM=UGLPKQFM9U \
  CODE_SIGN_STYLE=Manual \
  -quiet

# Jede Kennung braucht ihr Profil beim Namen. Ein fehlender Eintrag ist der
# Fehler, der erst beim Export auffällt — und dann eine ganze Archivrunde
# kostet.
cat > build/ExportOptions.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key><string>app-store-connect</string>
	<key>teamID</key><string>UGLPKQFM9U</string>
	<key>signingStyle</key><string>manual</string>
	<key>uploadSymbols</key><true/>
	<key>provisioningProfiles</key>
	<dict>
		<key>com.ip-style.aicockpitmobile</key>
		<string>AI Cockpit Mobile App Store</string>
		<key>com.ip-style.aicockpitmobile.widget</key>
		<string>AI Cockpit Mobile Widget App Store</string>
		<key>com.ip-style.aicockpitmobile.watchkitapp</key>
		<string>AI Cockpit Mobile Watch App Store</string>
		<key>com.ip-style.aicockpitmobile.watchkitapp.widget</key>
		<string>AI Cockpit Mobile Watch Widget App Store</string>
	</dict>
</dict>
</plist>
PLIST

echo "▸ Exportieren"
xcodebuild -exportArchive -archivePath "$ARCHIV" \
  -exportOptionsPlist build/ExportOptions.plist \
  -exportPath "$AUSGABE" -quiet

IPA=$(find "$AUSGABE" -name '*.ipa' | head -1)
[ -n "$IPA" ] || { echo "✗ Kein .ipa entstanden"; exit 1; }
echo "  $IPA"

# Die Uhr-App muss wirklich drin sein. Ein Archiv ohne sie baut und exportiert
# klaglos — auffallen würde es erst, wenn im Store keine Uhr-Fassung erscheint.
if unzip -l "$IPA" | grep -q "Watch/AICockpitWatch.app/"; then
  echo "  ✓ Uhr-Fassung enthalten"
else
  echo "✗ Die Uhr-Fassung fehlt im Paket"; exit 1
fi

: "${ASC_KEY_ID:?ASC_KEY_ID fehlt}"; : "${ASC_ISSUER_ID:?ASC_ISSUER_ID fehlt}"

echo "▸ Prüfen"
xcrun altool --validate-app -f "$IPA" -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"

if [ "${1:-}" = "--hochladen" ]; then
  echo "▸ Hochladen"
  xcrun altool --upload-app -f "$IPA" -t ios \
    --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
  echo "✓ Build $BAU hochgeladen. Die Verarbeitung bei Apple dauert einige Minuten."
else
  echo "✓ Geprüft, nicht hochgeladen. Mit --hochladen erneut aufrufen."
fi
