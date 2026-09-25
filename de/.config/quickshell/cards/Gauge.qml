import QtQuick
// Parent import: Theme/Config/Txt/Poll and the data singletons (Sys, Volume,
// Reach, NotificationService) live one level up, and a QML file does not
// see its parent directory implicitly.
import ".."

// Flat read-only gauge: a surface0 track with a `fillColor` bar over
// `fraction` (0..1) of it. Battery, Brightness and the Mpd progress bar each
// drew this pair of rectangles by hand. A `radius` set on the track is carried
// onto the fill, so the two keep the same shape.
Rectangle {
    id: g

    property real fraction: 0
    property color fillColor: Theme.text
    // Ease the fill between readings (Brightness: a held key steps it 5% at a time).
    property bool animated: false

    width: parent.width
    height: Config.s(8)
    color: Theme.surface0

    Rectangle {
        height: parent.height
        width: parent.width * g.fraction
        radius: g.radius
        color: g.fillColor
        Behavior on width { enabled: g.animated; NumberAnimation { duration: 90 } }
    }
}
