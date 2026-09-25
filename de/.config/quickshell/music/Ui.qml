pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import ".."

// Sizing and the pointer guard, shared by every file in this folder.
//
// The scale was a `fontScale: 1.2` property plumbed through ten files and
// never set to anything else; the hover guard was the same ten lines of state
// in both list implementations. Both are process-wide facts, so they live in
// one place.
Singleton {
    id: root

    readonly property real fontScale: 1.2
    readonly property int rowH: root.s(31)

    // The header's own scale — and the tab strip's geometry, which sits with
    // it: at list size they read as chrome rather than as the now-playing
    // display. One number to turn if it wants to be bigger still.
    readonly property real headerScale: 1.3

    function s(n) { return Config.s(n); }
    function fs(n) { return Math.round(root.s(n) * root.fontScale); }
    function hs(n) { return Math.round(root.s(n) * root.headerScale); }
    // Rounded once: off fs(n) it would quantise twice.
    function hfs(n) { return Math.round(root.s(n) * root.fontScale * root.headerScale); }

    // Qt delivers a hover move whenever the row UNDER the cursor changes, so
    // arrowing through a list scrolls it past a motionless pointer and the row
    // sliding underneath hands the selection straight back. Compare window
    // coordinates instead and take hover only on real movement. One baseline
    // for the whole player is right: there is one pointer, and only one list
    // is ever on screen.
    property point lastPointer: Qt.point(-1, -1)
    property bool pointerSeen: false

    function resetHover(): void { root.pointerSeen = false; }

    function allowHover(item, event) {
        var point = item.mapToItem(null, event.x, event.y);
        var moved = root.pointerSeen && (Math.abs(point.x - root.lastPointer.x) >= 1
                                         || Math.abs(point.y - root.lastPointer.y) >= 1);
        root.pointerSeen = true;
        root.lastPointer = point;
        return moved;
    }
}
