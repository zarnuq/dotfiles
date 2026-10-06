pragma ComponentBehavior: Bound
import Quickshell
import QtQuick

// Screenshot annotator — what `capture annotate` opens (replaced satty).
// Screenshot.qml dumps the clipboard image to `path` and builds this window;
// closing it destroys it.
//
// Shapes are kept in IMAGE pixels and drawn twice by the same function: scaled
// onto a display-sized Canvas over a display-sized Image while you draw (cheap —
// the software renderer never touches a full-resolution bitmap per stroke), and
// once at k=1 over the native image, grabbed to a file, only while exporting.
//
// Keys: p pen · a arrow · r rect · b box (filled) · o obfuscate (mosaic) ·
// t text (click, type, Return/Esc to finish) · c crop (the last one drawn wins;
// undo drops it like a shape) · 1–6 colour · u / Ctrl+Z undo ·
// wheel zoom (at the cursor) · middle-drag pan · 0 back to fit ·
// Return / Ctrl+C copy · Ctrl+S save to ~/Pictures and copy · Esc close.
FloatingWindow {
    id: root

    required property string path
    signal done()

    // A query makes the URL unique, so the pixmap cache never hands back the
    // previous session's image (the dump file name is reused).
    readonly property string src: "file://" + path + "?" + Date.now()

    // Native size, from a full decode that is dropped as soon as it's read.
    property int natW: 0
    property int natH: 0
    Image {
        id: probe
        visible: false
        source: root.src
        onStatusChanged: if (status === Image.Ready) {
            root.natW = implicitWidth; root.natH = implicitHeight; source = "";
        }
    }

    property var shapes: []          // { tool, color, width, pts: [x0, y0, …], text? } in image px
    property int rev: 0              // bumped on every edit: shapes is mutated in place
    property var editing: null       // the text shape being typed into
    property string tool: "pen"
    readonly property var colors: [Theme.red, Theme.peach, Theme.yellow, Theme.green, Theme.blue, Theme.mauve]
    property color colour: Theme.red
    readonly property int strokeWidth: 5     // image px
    property string after: ""               // shell run on the exported file ($1) — "" while not exporting

    title: "Annotate"
    color: Theme.base
    implicitWidth: Config.s(1200)
    implicitHeight: Config.s(800)
    visible: true
    onClosed: root.done()

    // Obfuscate regions aren't Canvas strokes: each is the screenshot decoded at
    // 1/block size and blown back up unsmoothed, clipped to the shape's rect — a
    // real mosaic from plain Image scaling, since there are no shaders under the
    // software backend. Same sourceSize on screen and in the export, so both
    // look identical and share one cached decode.
    readonly property int block: 14     // image px per mosaic cell
    readonly property var mosaics: root.rev >= 0 ? root.shapes.filter(sh => sh.tool === "obfuscate") : []

    // [x, y, w, h] in image px, clamped to the image; the whole image without one.
    readonly property var crop: {
        var c = root.rev >= 0 ? root.shapes.filter(sh => sh.tool === "crop").pop() : null;
        if (!c) return [0, 0, root.natW, root.natH];
        var x0 = Math.max(0, Math.round(Math.min(c.pts[0], c.pts[2])));
        var y0 = Math.max(0, Math.round(Math.min(c.pts[1], c.pts[3])));
        var x1 = Math.min(root.natW, Math.round(Math.max(c.pts[0], c.pts[2])));
        var y1 = Math.min(root.natH, Math.round(Math.max(c.pts[1], c.pts[3])));
        return x1 - x0 < 2 || y1 - y0 < 2 ? [0, 0, root.natW, root.natH] : [x0, y0, x1 - x0, y1 - y0];
    }
    Component {
        id: mosaic
        Item {
            id: m
            required property var modelData
            readonly property real k: parent ? parent.k : 0
            readonly property var p: m.modelData.pts
            x: Math.min(m.p[0], m.p[2]) * m.k
            y: Math.min(m.p[1], m.p[3]) * m.k
            width: Math.abs(m.p[2] - m.p[0]) * m.k
            height: Math.abs(m.p[3] - m.p[1]) * m.k
            clip: true
            Image {
                x: -m.x; y: -m.y
                width: root.natW * m.k
                height: root.natH * m.k
                source: root.src
                sourceSize: Qt.size(Math.ceil(root.natW / root.block), Math.ceil(root.natH / root.block))
                smooth: false
            }
        }
    }

    function changed(): void { root.rev++; draw.requestPaint(); }

    function commitText(): void {
        var ed = root.editing;
        root.editing = null;
        if (ed && ed.text === "") root.shapes.splice(root.shapes.indexOf(ed), 1);
        root.changed();
    }

    function drawShape(ctx, sh, k): void {
        if (sh.tool === "obfuscate" || sh.tool === "crop") return;
        var p = sh.pts.map(v => v * k), n = p.length;
        var x0 = p[0], y0 = p[1], x1 = p[n - 2], y1 = p[n - 1];
        ctx.strokeStyle = sh.color;
        ctx.fillStyle = sh.color;
        ctx.lineWidth = sh.width * k;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        if (sh.tool === "text") {
            ctx.font = "bold " + Math.round(sh.width * 8 * k) + "px '" + Theme.font + "'";
            ctx.textBaseline = "top";
            ctx.fillText(sh.text + (sh === root.editing ? "▏" : ""), x0, y0);
            return;
        }
        if (sh.tool === "rect") { ctx.strokeRect(x0, y0, x1 - x0, y1 - y0); return; }
        if (sh.tool === "box")  { ctx.fillRect(x0, y0, x1 - x0, y1 - y0); return; }
        ctx.beginPath();
        ctx.moveTo(x0, y0);
        for (var i = 2; i < n; i += 2) ctx.lineTo(p[i], p[i + 1]);
        if (sh.tool === "arrow") {
            var a = Math.atan2(y1 - y0, x1 - x0), h = ctx.lineWidth * 4;
            ctx.moveTo(x1 - h * Math.cos(a - 0.5), y1 - h * Math.sin(a - 0.5));
            ctx.lineTo(x1, y1);
            ctx.lineTo(x1 - h * Math.cos(a + 0.5), y1 - h * Math.sin(a + 0.5));
        }
        ctx.stroke();
    }

    // Deferred: done() destroys this window, and every caller is a handler
    // running inside it.
    function finish(): void { Qt.callLater(root.done); }

    function exportTo(cmd): void {
        if (root.natW > 0) root.after = cmd;
    }

    Item {
        anchors.fill: parent
        focus: true
        Component.onCompleted: forceActiveFocus()

        Keys.onPressed: e => {
            var ctrl = e.modifiers & Qt.ControlModifier;
            var ed = root.editing;
            if (ed && !ctrl) {
                if (e.key === Qt.Key_Escape || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.commitText();
                else if (e.key === Qt.Key_Backspace) ed.text = ed.text.slice(0, -1);
                else if (e.text.length === 1 && e.text >= " ") ed.text += e.text;
                root.changed();
                e.accepted = true;
                return;
            }
            if (ed) root.commitText();
            var tools = { [Qt.Key_P]: "pen", [Qt.Key_A]: "arrow", [Qt.Key_R]: "rect", [Qt.Key_B]: "box",
                          [Qt.Key_O]: "obfuscate", [Qt.Key_T]: "text", [Qt.Key_C]: "crop" };
            if (e.key === Qt.Key_Escape) root.finish();
            else if (e.key === Qt.Key_U || (ctrl && e.key === Qt.Key_Z)) { root.shapes.pop(); root.changed(); }
            else if (ctrl && e.key === Qt.Key_S)
                root.exportTo("f=~/Pictures/screenshot-$(date +%Y-%m-%d_%H-%M-%S).png; cp \"$1\" \"$f\""
                              + " && wl-copy --type image/png < \"$1\" && notify-send Screenshot \"Saved $f\"");
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || (ctrl && e.key === Qt.Key_C))
                root.exportTo("wl-copy --type image/png < \"$1\" && notify-send Screenshot 'Copied!'");
            else if (!ctrl && e.key === Qt.Key_0) view.reset();
            else if (!ctrl && tools[e.key]) root.tool = tools[e.key];
            else if (!ctrl && e.key >= Qt.Key_1 && e.key < Qt.Key_1 + root.colors.length) root.colour = root.colors[e.key - Qt.Key_1];
            else return;
            e.accepted = true;
        }

        // Zoom is a multiple of fit (1 = fit), toward the cursor. The
        // image may overflow the view; nothing clips it (the software renderer
        // doesn't nest clips, and the mosaics clip themselves), the bar's
        // backdrop and the window edge hide it instead. The Canvas stays
        // view-sized and translates, so zooming never grows its CPU buffer.
        Item {
            id: view
            anchors { top: parent.top; left: parent.left; right: parent.right; bottom: bar.top }
            anchors.margins: Config.s(12)

            // Fit, never upscale.
            readonly property real fit: root.natW > 0 ? Math.min(width / root.natW, height / root.natH, 1) : 0
            property real zoom: 1
            property real ox: 0              // pan from centre, view px
            property real oy: 0
            readonly property real k: fit * zoom
            readonly property real imgX: Math.round((view.width - root.natW * k) / 2 + view.clampOff(ox, root.natW * k - view.width))
            readonly property real imgY: Math.round((view.height - root.natH * k) / 2 + view.clampOff(oy, root.natH * k - view.height))
            onKChanged: draw.requestPaint()
            onImgXChanged: draw.requestPaint()
            onImgYChanged: draw.requestPaint()

            // An image smaller than the view stays centred; a larger one can't
            // be panned past its edges.
            function clampOff(o, over) { var s = Math.max(0, over / 2); return Math.max(-s, Math.min(s, o)); }

            function zoomAt(z, mx, my): void {
                if (root.natW <= 0) return;
                z = Math.max(1, Math.min(z, 8 / view.fit));    // at most 8 screen px per image px
                var ix = (mx - view.imgX) / view.k, iy = (my - view.imgY) / view.k, nk = view.fit * z;
                view.zoom = z;
                view.ox = view.clampOff(mx - ix * nk - (view.width - root.natW * nk) / 2, root.natW * nk - view.width);
                view.oy = view.clampOff(my - iy * nk - (view.height - root.natH * nk) / 2, root.natH * nk - view.height);
            }

            function pan(dx, dy): void {
                var ow = root.natW * view.k - view.width, oh = root.natH * view.k - view.height;
                view.ox = view.clampOff(view.clampOff(view.ox, ow) + dx, ow);
                view.oy = view.clampOff(view.clampOff(view.oy, oh) + dy, oh);
            }

            function reset(): void { view.zoom = 1; view.ox = 0; view.oy = 0; }

            Image {
                id: shot
                x: view.imgX
                y: view.imgY
                width: Math.round(root.natW * view.k)
                height: Math.round(root.natH * view.k)
                // Decoded at fit size, or once at native while zoomed: a
                // sourceSize per wheel tick would re-decode on every tick.
                sourceSize: view.zoom > 1 ? Qt.size(root.natW, root.natH) : Qt.size(width, height)
                source: root.natW > 0 ? root.src : ""
            }

            Item {
                anchors.fill: shot
                property real k: view.k
                Repeater { model: root.mosaics; delegate: mosaic }
            }

            Canvas {
                id: draw
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.save();
                    ctx.translate(view.imgX, view.imgY);
                    root.shapes.forEach(sh => root.drawShape(ctx, sh, view.k));
                    var c = root.crop.map(v => v * view.k), w = shot.width, h = shot.height;
                    if (c[2] < w || c[3] < h) {
                        ctx.fillStyle = Theme.scrim;
                        ctx.fillRect(0, 0, w, c[1]);
                        ctx.fillRect(0, c[1] + c[3], w, h - c[1] - c[3]);
                        ctx.fillRect(0, c[1], c[0], c[3]);
                        ctx.fillRect(c[0] + c[2], c[1], w - c[0] - c[2], c[3]);
                        ctx.strokeStyle = Theme.mauve;
                        ctx.lineWidth = 1;
                        ctx.strokeRect(c[0] + 0.5, c[1] + 0.5, c[2] - 1, c[3] - 1);
                    }
                    ctx.restore();
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    cursorShape: Qt.CrossCursor
                    property real lx: 0
                    property real ly: 0
                    function at(m) { return [(m.x - view.imgX) / view.k, (m.y - view.imgY) / view.k]; }
                    onWheel: w => view.zoomAt(view.zoom * Math.pow(1.0015, w.angleDelta.y), w.x, w.y)
                    onPressed: m => {
                        if (m.button === Qt.MiddleButton) { lx = m.x; ly = m.y; return; }
                        if (root.editing) root.commitText();
                        var p = at(m), text = root.tool === "text";
                        var sh = { tool: root.tool, color: String(root.colour), width: root.strokeWidth,
                                   pts: text ? p : p.concat(p), text: "" };
                        root.shapes.push(sh);
                        if (text) root.editing = sh;
                        root.changed();
                    }
                    onPositionChanged: m => {
                        if (pressedButtons & Qt.MiddleButton) { view.pan(m.x - lx, m.y - ly); lx = m.x; ly = m.y; return; }
                        var sh = root.shapes[root.shapes.length - 1];
                        if (!pressed || !sh || sh.tool === "text") return;
                        var p = at(m);
                        if (sh.tool === "pen") sh.pts.push(p[0], p[1]);
                        else sh.pts.splice(-2, 2, p[0], p[1]);
                        root.changed();
                    }
                }
            }
        }

        // Hides a zoomed image's overflow behind the bar.
        Rectangle {
            anchors { top: view.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
            color: Theme.base
        }

        Row {
            id: bar
            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: Config.s(8) }
            spacing: Config.s(14)

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Config.s(14); height: width
                color: root.colour
            }
            Repeater {
                model: ["pen", "arrow", "rect", "box", "obfuscate", "text", "crop"]
                Txt {
                    id: toolLabel
                    required property string modelData
                    text: toolLabel.modelData[0] + " " + toolLabel.modelData
                    color: root.tool === toolLabel.modelData ? Theme.mauve : Theme.overlay1
                    font.pixelSize: Config.s(12)
                }
            }
            Txt {
                text: "1–6 colour · u undo · scroll zoom · mid-drag pan · 0 fit · ⏎ copy · ^S save · esc close"
                color: Theme.overlay0
                font.pixelSize: Config.s(12)
            }
        }

        // Full-resolution render, built only while exporting: the native image
        // plus the shapes at k=1, shifted under a crop-sized window, grabbed once
        // both have painted. Parked past the window's right edge so it never
        // shows; grabToImage renders the subtree on its own and cuts it to out's
        // bounds. Not hidden under a zero-size clip: the software renderer
        // doesn't nest clips, so out's own clip leaked it on screen.
        // (Canvas.loadImage/drawImage would be one item fewer, but under the
        // software backend the image never loads.)
        Item {
            x: parent.width
            Loader {
                active: root.after !== ""
                sourceComponent: Item {
                    id: out
                    readonly property string file: Config.runtimeDir + "/annotated.png"
                    width: root.crop[2]
                    height: root.crop[3]
                    Item {
                        x: -root.crop[0]; y: -root.crop[1]
                        width: root.natW
                        height: root.natH
                        Image {
                            id: full
                            source: root.src
                            // Native on purpose: this IS the full-res render. Same
                            // key as `shot`'s zoomed decode, so a zoomed export reuses it.
                            sourceSize: Qt.size(root.natW, root.natH)
                            onStatusChanged: if (status === Image.Ready) overlay.requestPaint()
                        }
                        Item {
                            anchors.fill: parent
                            property real k: 1
                            Repeater { model: root.mosaics; delegate: mosaic }
                        }
                        Canvas {
                            id: overlay
                            anchors.fill: parent
                            property bool grabbed: false
                            // The clear is load-bearing: with nothing drawn (no shapes,
                            // or only a crop) painted never fires, so neither does the grab.
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                root.shapes.forEach(sh => root.drawShape(ctx, sh, 1));
                            }
                            onPainted: if (full.status === Image.Ready && !grabbed) {
                                grabbed = true;
                                out.grabToImage(r => {
                                    if (r.saveToFile(out.file))
                                        Quickshell.execDetached(["bash", "-c", root.after, "_", out.file]);
                                    else
                                        Quickshell.execDetached(["notify-send", "Screenshot", "Annotate: export failed"]);
                                    root.finish();
                                });
                            }
                        }
                    }
                }
            }
        }
    }
}
