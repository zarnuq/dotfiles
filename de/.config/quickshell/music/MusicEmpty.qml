pragma ComponentBehavior: Bound
import QtQuick
import ".."

// The recessive line centred over an empty pane — "queue is empty", "no
// lyrics for this track", a browse list's "loading…". Callers set `visible`
// and `text`; it centres itself on whatever it is declared in.
Txt {
    id: root
    anchors.centerIn: parent
    color: Theme.surface1
    font.pixelSize: Ui.fs(13)
}
