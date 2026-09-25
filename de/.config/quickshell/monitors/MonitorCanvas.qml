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
        var e = view.extent(canvas.entries);
        if (!e) return { x: 0, y: 0, w: 1920, h: 1080 };
        return { x: e.minX, y: e.minY, w: Math.max(1, e.maxX - e.minX), h: Math.max(1, e.maxY - e.minY) };
    }

    readonly property real pad: view.s(28)
    readonly property real zoom: Math.min((width - pad * 2) / bounds.w,
                                          (height - pad * 2) / bounds.h)
    // Centre the arrangement in whatever space is left over.
    readonly property real originX: (width - bounds.w * zoom) / 2 - bounds.x * zoom
    readonly property real originY: (height - bounds.h * zoom) / 2 - bounds.y * zoom

    /// Snap threshold in LAYOUT pixels, derived from a constant on-screen
    /// distance — so it feels the same whether the arrangement is three 4K heads
    /// or one laptop panel. Generous on purpose: at this zoom a tenth of that is
    /// a few pixels of mouse travel, which is not a target anyone can hit.
    readonly property real snapPx: view.s(22) / Math.max(zoom, 0.0001)

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

            // Mid-drag the rectangle follows the snapped drop point rather than
            // the model. Choosing it in the binding, instead of assigning x/y from
            // the drag handler, means there is no binding to break: an assignment
            // replaces it for good, and a head released that way kept the pixel it
            // was dropped at while the model held the snapped value — a gap the
            // layout did not have, drawn until the next reload.
            x: canvas.originX + (drag.dragging ? drag.dropX : mon.x) * canvas.zoom
            y: canvas.originY + (drag.dragging ? drag.dropY : mon.y) * canvas.zoom
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
                id: drag
                anchors.fill: parent

                // The rectangle is drawn SNAPPED while you drag, not corrected on
                // release: a near miss used to drop a head a few pixels shy of its
                // neighbour and say nothing, so the gap was yours to notice. Now it
                // visibly clicks into place under the cursor.
                //
                // The model is still only written on release. A drag emits a move
                // per frame, and each one would rebuild the working array and with
                // it every delegate's bindings.
                property real grabDX: 0   // cursor's offset INSIDE the rect
                property real grabDY: 0
                property real dropX: 0    // layout position release will commit
                property real dropY: 0
                property bool dragging: false

                onPressed: mouse => {
                    canvas.view.selected = head.index;
                    // Held constant for the whole drag, which is what keeps the
                    // pointer on the same spot of the rectangle. Accumulating
                    // frame deltas cannot: the rect moves by the SNAPPED amount,
                    // not the amount the mouse moved, so the two drift apart.
                    grabDX = mouse.x;
                    grabDY = mouse.y;
                    dropX = head.mon.x;
                    dropY = head.mon.y;
                    // Last, so the rect switches to the drop point only once it
                    // holds where the head already is.
                    dragging = head.mon.included;
                }

                onPositionChanged: mouse => {
                    if (!dragging) return;
                    var p = mapToItem(canvas, mouse.x, mouse.y);
                    var at = canvas.snapFor(head.index,
                                            (p.x - grabDX - canvas.originX) / canvas.zoom,
                                            (p.y - grabDY - canvas.originY) / canvas.zoom);
                    dropX = at.x;
                    dropY = at.y;
                }

                onReleased: {
                    if (!dragging) return;
                    // Commit first: dropping `dragging` hands x/y back to the
                    // model, which must already hold the snapped position.
                    canvas.view.move(head.index, dropX, dropY);
                    dragging = false;
                }

                onDoubleClicked: canvas.view.toggleIncluded(head.index)
            }
        }
    }

    /// Where a head dragged to (x, y) — layout pixels — should actually land.
    ///
    /// Two stages. Edges first snap to their neighbours' within `snapPx`: that is
    /// the alignment you meant when you were nearly right, and each axis is
    /// snapped independently to the nearest of the four that matter — edge-to-edge
    /// (screens abutting, which is what lets the pointer cross) and flush sides.
    ///
    /// Then, if the result still touches nothing, it is pulled flush against the
    /// nearest head anyway. A gap between two outputs is never what anyone means:
    /// it is dead space in the layout that windows can be placed in and the
    /// pointer skips across. So this canvas cannot express one.
    function snapFor(index, x, y) {
        var mon = entries[index];
        var w = view.effW(mon), h = view.effH(mon);
        var others = neighbours(index);

        var bestX = { delta: snapPx, value: x }, bestY = { delta: snapPx, value: y };
        for (var i = 0; i < others.length; i++) {
            var o = others[i];
            consider(bestX, x, o.x + o.w);      // my left  → their right
            consider(bestX, x, o.x - w);        // my right → their left
            consider(bestX, x, o.x);            // left edges flush
            consider(bestX, x, o.x + o.w - w);  // right edges flush

            consider(bestY, y, o.y + o.h);
            consider(bestY, y, o.y - h);
            consider(bestY, y, o.y);
            consider(bestY, y, o.y + o.h - h);
        }

        var at = { x: bestX.value, y: bestY.value, w: w, h: h };
        return touches(others, at) ? { x: at.x, y: at.y } : attach(others, at);
    }

    /// Every OTHER head that is in the layout, as a rectangle with its effective
    /// size — what each stage below measures against. A head merely plugged in is
    /// not something to line up with.
    function neighbours(index) {
        var out = [];
        for (var i = 0; i < entries.length; i++) {
            var o = entries[i];
            if (i !== index && o.included)
                out.push({ x: o.x, y: o.y, w: view.effW(o), h: view.effH(o) });
        }
        return out;
    }

    function consider(best, actual, candidate) {
        var delta = Math.abs(actual - candidate);
        if (delta < best.delta) {
            best.delta = delta;
            best.value = candidate;
        }
    }

    /// Does this rectangle meet any other head? Sharing an edge counts (a gap of
    /// exactly 0); meeting only at a corner does not, since nothing can cross it.
    function touches(others, r) {
        for (var i = 0; i < others.length; i++) {
            var o = others[i];
            var ox = Math.min(r.x + r.w, o.x + o.w) - Math.max(r.x, o.x);
            var oy = Math.min(r.y + r.h, o.y + o.h) - Math.max(r.y, o.y);
            if (ox >= 0 && oy >= 0 && (ox > 0 || oy > 0)) return true;
        }
        return false;
    }

    /// Pull a free-floating head flush against its nearest neighbour: close the
    /// axis it is actually separated on (the smaller gap when it is adrift
    /// diagonally — that is the side it was dragged toward), then slide the other
    /// axis just far enough to overlap, so the two share an edge rather than
    /// meeting at a corner.
    function attach(others, r) {
        var x = r.x, y = r.y, w = r.w, h = r.h;

        var near = null, nearGap = Infinity;
        for (var i = 0; i < others.length; i++) {
            var o = others[i];
            var d = gap(x, w, o.x, o.w) + gap(y, h, o.y, o.h);
            if (d < nearGap) { nearGap = d; near = o; }
        }
        if (!near) return { x: x, y: y };

        var gx = gap(x, w, near.x, near.w), gy = gap(y, h, near.y, near.h);
        // Closing an axis that is already overlapping would shove the head out to
        // that neighbour's side for no reason, so only a positive gap is closed.
        if (gy === 0 || (gx > 0 && gx <= gy)) {
            x = (x + w / 2 < near.x + near.w / 2) ? near.x - w : near.x + near.w;
            y = slideInto(y, h, near.y, near.h);
        } else {
            y = (y + h / 2 < near.y + near.h / 2) ? near.y - h : near.y + near.h;
            x = slideInto(x, w, near.x, near.w);
        }
        return { x: x, y: y };
    }

    /// Distance between two 1-D spans; 0 when they overlap at all.
    function gap(a, alen, b, blen) {
        if (a + alen < b) return b - (a + alen);
        if (b + blen < a) return a - (b + blen);
        return 0;
    }

    /// Move a span the minimum needed for it to overlap the other one.
    function slideInto(a, alen, b, blen) {
        if (a + alen < b) return b;
        if (a > b + blen) return b + blen - alen;
        return a;
    }
}
