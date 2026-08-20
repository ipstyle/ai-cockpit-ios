import AppKit

// Programmsymbol für AI Cockpit Mobile — dasselbe Gehirn auf demselben
// Blau-Violett wie die macOS-Fassung, damit man auf beiden Geräten dieselbe
// App wiedererkennt.
//
// Zwei Dinge sind gegenüber der Mac-Vorlage bewusst anders, und beide gehen
// sonst still daneben:
//
// 1. **Kein Rand, kein Eckradius, kein Schlagschatten.** macOS erwartet das
//    Symbol als fertiges Bild mit eigener Kontur — es liegt auf 824 von 1024
//    Punkten und bringt seine runden Ecken mit. iOS maskiert selbst. Wer die
//    Mac-Fassung übernimmt, bekommt ein geschrumpftes Symbol mit hellem Rahmen
//    in der abgerundeten Maske.
// 2. **Keine Transparenz.** Ein iOS-Programmsymbol mit Alphakanal wird beim
//    Hochladen abgewiesen. Die Fläche ist deshalb durchgehend deckend.
//
// Erzeugen:
//   swift Tools/AppIcon-erzeugen.swift
// Das Ergebnis landet in App/Resources/Assets.xcassets/AppIcon.appiconset/.
func icon(side: CGFloat) -> NSBitmapImageRep? {
    let px = Int(side)
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
    rep.size = NSSize(width: side, height: side)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high

    let u = side / 1024
    let body = NSRect(x: 0, y: 0, width: side, height: side)

    // Hell oben, tief unten — so herum liest sich eine Fläche als Körper und
    // nicht als Aufkleber. Der obere Ton ist das Blau der OpenAI-Karte, der
    // untere ein sattes Indigo, damit das weisse Gehirn überall trägt.
    NSGradient(colors: [NSColor(calibratedRed: 0.60, green: 0.65, blue: 0.99, alpha: 1),
                        NSColor(calibratedRed: 0.20, green: 0.21, blue: 0.55, alpha: 1)],
               atLocations: [0, 1], colorSpace: .deviceRGB)?
        .draw(in: body, angle: -90)

    // Leichter Glanz oben — sonst wirkt die Fläche flach.
    if let glanz = NSGradient(colors: [NSColor(calibratedWhite: 1, alpha: 0.16),
                                       NSColor(calibratedWhite: 1, alpha: 0)],
                              atLocations: [0, 1], colorSpace: .deviceRGB) {
        glanz.draw(in: NSRect(x: 0, y: side * 0.65, width: side, height: side * 0.35), angle: -90)
    }

    // Das Gehirn, weiss. Etwas kleiner als auf dem Mac (52 statt 58 Prozent):
    // Dort sitzt es in einem Körper, der selbst schon eingerückt ist — hier
    // reicht die Fläche bis an den Rand, und die Maske schneidet die Ecken weg.
    let config = NSImage.SymbolConfiguration(pointSize: 512, weight: side <= 64 ? .heavy : .bold)
    if let brain = NSImage(systemSymbolName: "brain", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let ziel = side * 0.52
        let f = min(ziel / brain.size.width, ziel / brain.size.height)
        let size = NSSize(width: brain.size.width * f, height: brain.size.height * f)
        let rect = NSRect(x: body.midX - size.width / 2, y: body.midY - size.height / 2,
                          width: size.width, height: size.height)
        // Eigenes Bild einfärben, damit `sourceAtop` nicht den Verlauf mitnimmt.
        let weiss = NSImage(size: size, flipped: false) { r in
            brain.draw(in: r); NSColor.white.set(); r.fill(using: .sourceAtop); return true
        }
        NSGraphicsContext.saveGraphicsState()
        let tiefe = NSShadow()
        tiefe.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.28)
        tiefe.shadowBlurRadius = 18 * u
        tiefe.shadowOffset = NSSize(width: 0, height: -8 * u)
        tiefe.set()
        weiss.draw(in: rect)
        NSGraphicsContext.restoreGraphicsState()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

/// Entfernt den Alphakanal.
///
/// Ein iOS-Programmsymbol mit Alphakanal weist der Store beim Hochladen ab.
/// Zwei naheliegende Wege gehen schief, beide ohne brauchbare Meldung: Ein
/// `NSBitmapImageRep` gleich mit drei Kanälen anzulegen liefert ein durchgehend
/// schwarzes Bild, und in ein solches hineinzuzeichnen bringt das Programm zum
/// Absturz. Der verlässliche Weg führt über einen CoreGraphics-Kontext, dem man
/// das Fehlen des Alphakanals ausdrücklich sagt.
func ohneAlpha(_ quelle: NSBitmapImageRep) -> Data? {
    guard let cg = quelle.cgImage else { return nil }
    let px = cg.width
    guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8,
                              bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
    let flaeche = CGRect(x: 0, y: 0, width: px, height: px)
    ctx.setFillColor(gray: 0, alpha: 1)
    ctx.fill(flaeche)
    ctx.draw(cg, in: flaeche)
    guard let flach = ctx.makeImage() else { return nil }
    return NSBitmapImageRep(cgImage: flach).representation(using: .png, properties: [:])
}

// Seit Xcode 14 genügt iOS ein einziges Bild mit 1024 Punkten; die kleineren
// Grössen leitet das System ab. Ein Satz aus zwölf Dateien wäre zwölf Stellen,
// an denen etwas auseinanderlaufen kann.
let fm = FileManager.default
let ziel = "App/Resources/Assets.xcassets/AppIcon.appiconset"
try? fm.createDirectory(atPath: ziel, withIntermediateDirectories: true)

guard let gezeichnet = icon(side: 1024),
      let png = ohneAlpha(gezeichnet) else {
    fputs("Symbol liess sich nicht zeichnen\n", stderr); exit(1)
}
try? png.write(to: URL(fileURLWithPath: "\(ziel)/AppIcon-1024.png"))

let contents = """
{
  "images" : [
    {
      "filename" : "AppIcon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""
try? contents.write(toFile: "\(ziel)/Contents.json", atomically: true, encoding: .utf8)
print("Programmsymbol geschrieben: \(ziel)")
