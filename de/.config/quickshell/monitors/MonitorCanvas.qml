import QtQuick
import ".."

// The arrangement: one rectangle per head, dragged to position.
//
// Layout coordinates are the compositor's pixels; this draws them through one
// `zoom` factor chosen to fit the bounding box of everything visible. Heads that
// are in the preset are drawn solid, ones merely plugged in are outlined — so
// "what this preset says" and "what is on this machine" are both on screen at
// once, which is the whole reason the desktop's layout can be edited from the
// laptop.
Item {
    id: canvas

    required property var view

    // Drawn heads: everything in the preset, plus any live head not in it.
    readonly property var entries: view.working

    // --- fit ----------------------------------------------------------------
    // Recomputed from the working copy, so dragging a head past the edge
    // rescales rather than pushing it out of sight.
    readonly property var bounds: {
        var e = canvas.entries;
        if (!e || e.length === 0) return { x: 0, y: 0, w: 1920, h: 1080 };
        var minX = e[0].x, minY = e[0].y;
        var maxX = e[0].x + view.effW(e[0]), maxY = e[0].y + view.effH(e[0]);
        for (var i = 1; i < e.length; i++) {
            minX = Math.min(minX, e[i].x);
            minY = Math.min(minY, e[i].y);
            maxX = Math.max(maxX, e[i].x + view.effW(e[i]));
            maxY = Math.max(maxY, e[i].y + view.effH(e[i]));
        }
        return { x: minX, y: minY, w: Math.max(1, maxX - minX), h: Math.max(1, maxY - minY) };
    }

    readonly property real pad: view.s(28)
    readonly property real zoom: Math.min((width - pad * 2) / bounds.w,
                                          (height - pad * 2) / bounds.h)
    // Centre the arrangement in whatever space is left over.
    readonly property real originX: (width - bounds.w * zoom) / 2 - bounds.x * zoom
    readonly property real originY: (height - bounds.h * zoom) / 2 - bounds.y * zoom

    /// Snap threshold in LAYOUT pixels, derived from a constant on-screen
    /// distance — so it feels the same whether the arrangement is three 4K heads
    /// or one laptop panel.
    readonly property real snapPx: view.s(10) / Math.max(zoom, 0.0001)

    Rectangle {
        anchors.fill: parent
        color: Theme.crust
        border.width: 1
        border.color: Theme.surface0
    }

    Repeater {
        model: canvas.entries.length

        Rectangle {
            id: head

            required property int index
            readonly property var mon: canvas.entries[index]
            readonly property bool isSelected: canvas.view.selected === index

            x: canvas.originX + mon.x * canvas.zoom
            y: canvas.originY + mon.y * canvas.zoom
            width: canvas.view.effW(mon) * canvas.zoom
            height: canvas.view.effH(mon) * canvas.zoom

            color: mon.included ? (isSelected ? Theme.surface1 : Theme.surface0) : "transparent"
            border.width: isSelected ? view.s(2) : 1
            border.color: isSelected ? Theme.mauve
                        : !mon.included ? Theme.overlay0
                        : mon.connected ? Theme.surface1 : Theme.peach

            Column {
                anchors.centerIn: parent
                spacing: view.s(2)
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: head.mon.name
                    color: head.mon.included ? Theme.text : Theme.overlay0
                    font.pixelSize: view.s(14)
                }
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: head.mon.w + "×" + head.mon.h
                    color: Theme.subtext0
                    font.pixelSize: view.s(11)
                }
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    // Two different absences, and confusing them is how you edit
                    // the wrong machine's layout: a head the preset lists but
                    // nothing is plugged into, versus one plugged in that the
                    // preset does not mention.
                    visible: !head.mon.connected || !head.mon.included
                    text: !head.mon.connected ? "not connected" : "not in layout"
                    color: !head.mon.connected ? Theme.peach : Theme.overlay0
                    font.pixelSize: view.s(10)
                }
            }

            MouseArea {
                anchors.fill: parent
                // Positions are committed on release, not per frame: a drag emits
                // a move per frame and each one would rebuild the working array
                // (and with it every delegate's binding).
                property real grabX: 0
                property real grabY: 0
                property bool dragging: false

                onPressed: mouse => {
                    canvas.view.selected = head.index;
                    grabX = mouse.x;
                    grabY = mouse.y;
                    dragging = head.mon.included;
                }
                onPositionChanged: mouse => {
                    if (!dragging) return;
                    head.x += mouse.x - grabX;
                    head.y += mouse.y - grabY;
                }
                onReleased: {
                    if (!dragging) return;
                    dragging = false;
                    canvas.commit(head.index, head.x, head.y);
                }
                onDoubleClicked: canvas.view.toggleIncluded(head.index)
            }
        }
    }

    /// Turn a dropped rectangle back into layout coordinates, snapping its edges
    /// to its neighbours'. Each axis is snapped independently, to the nearest of
    /// the four alignments that matter — edge-to-edge (so screens abut with no
    /// dead gap, which is what makes the pointer cross between them) and
    /// flush-sides.
    function commit(index, px, py) {
        var mon = entries[index];
        var x = (px - originX) / zoom;
        var y = (py - originY) / zoom;
        var w = view.effW(mon), h = view.effH(mon);

        var bestX = { delta: snapPx, value: x }, bestY = { delta: snapPx, value: y };
        for (var i = 0; i < entries.length; i++) {
            if (i === index) continue;
            var o = entries[i];
            if (!o.included) continue;
            var ow = view.effW(o), oh = view.effH(o);

            consider(bestX, x, o.x + ow);       // my left  → their right
            consider(bestX, x, o.x - w);        // my right → their left
            consider(bestX, x, o.x);            // left edges flush
            consider(bestX, x, o.x + ow - w);   // right edges flush

            consider(bestY, y, o.y + oh);
            consider(bestY, y, o.y - h);
            consider(bestY, y, o.y);
            consider(bestY, y, o.y + oh - h);
        }
        view.move(index, bestX.value, bestY.value);
    }

    function consider(best, actual, candidate) {
        var delta = Math.abs(actual - candidate);
        if (delta < best.delta) {
            best.delta = delta;
            best.value = candidate;
        }
    }
}
