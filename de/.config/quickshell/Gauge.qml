pragma ComponentBehavior: Bound
import QtQuick

// Flat gauge: a surface0 track with a `fillColor` bar over
// `fraction` (0..1) of it. Battery, Brightness, the Mpd progress bar, the OSD
// and the audio mixer's volume track each drew this pair of rectangles by hand.
// A `radius` set on the track is carried onto the fill, so the two keep the
// same shape. Children land above the fill (the mixer's drag MouseArea).
Rectangle {
    id: root

    property real fraction: 0
    property color fillColor: Theme.text
    // Ease the fill between readings (Brightness: a held key steps it 5% at a time).
    property bool animated: false

    width: parent.width
    height: Config.s(8)
    color: Theme.surface0

    Rectangle {
        height: parent.height
        width: parent.width * root.fraction
        radius: root.radius
        color: root.fillColor
        Behavior on width { enabled: root.animated; NumberAnimation { duration: 90 } }
    }
}
