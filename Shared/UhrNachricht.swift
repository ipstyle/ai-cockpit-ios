import Foundation

/// Die Schlüssel, unter denen iPhone und Uhr miteinander reden.
///
/// Sie stehen hier und nicht auf je einer Seite, aus demselben Grund wie
/// `SchluesselbundNamen`: Zweimal geschrieben wären es zwei Zeichenketten, die
/// im Gleichschritt bleiben müssten — und am Tag, an dem eine nachzieht, meldet
/// WatchConnectivity keinen Fehler. Es kommt einfach nie etwas an.
public enum UhrNachricht {
    /// Der kodierte `WidgetZustand` als `Data`.
    ///
    /// Ein Wörterbuch für WatchConnectivity darf nur Eigenschaftslisten-Typen
    /// enthalten; `Data` ist einer, ein `WidgetZustand` nicht. Deshalb wandert
    /// er als JSON hinüber — mit **iso8601**-Datumsschreibweise auf beiden
    /// Seiten, genau wie in `WidgetZustand` selbst.
    public static let nutzlast = "zustand"

    /// Die Uhr bittet, das iPhone antwortet.
    public static let bitteAktualisieren = "bitte-aktualisieren"
}
