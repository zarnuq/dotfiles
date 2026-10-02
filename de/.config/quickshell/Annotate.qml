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
// t text (click, type, Return/Esc to finish) · 1–6 colour · u / Ctrl+Z undo ·
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
        if (sh.tool === "obfuscate") return;
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
                          [Qt.Key_O]: "obfuscate", [Qt.Key_T]: "text" };
            if (e.key === Qt.Key_Escape) root.finish();
            else if (e.key === Qt.Key_U || (ctrl && e.key === Qt.Key_Z)) { root.shapes.pop(); root.changed(); }
            else if (ctrl && e.key === Qt.Key_S)
                root.exportTo("f=~/Pictures/screenshot-$(date +%Y-%m-%d_%H-%M-%S).png; cp \"$1\" \"$f\""
                              + " && wl-copy --type image/png < \"$1\" && notify-send Screenshot \"Saved $f\"");
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || (ctrl && e.key === Qt.Key_C))
                root.exportTo("wl-copy --type image/png < \"$1\" && notify-send Screenshot 'Copied!'");
            else if (!ctrl && tools[e.key]) root.tool = tools[e.key];
            else if (!ctrl && e.key >= Qt.Key_1 && e.key < Qt.Key_1 + root.colors.length) root.colour = root.colors[e.key - Qt.Key_1];
            else return;
            e.accepted = true;
        }

        Item {
            id: view
            anchors { top: parent.top; left: parent.left; right: parent.right; bottom: bar.top }
            anchors.margins: Config.s(12)

            // Fit, never upscale.
            readonly property real fit: root.natW > 0 ? Math.min(width / root.natW, height / root.natH, 1) : 0

            Image {
                id: shot
                anchors.centerIn: parent
                width: Math.round(root.natW * view.fit)
                height: Math.round(root.natH * view.fit)
                sourceSize: Qt.size(width, height)
                source: root.natW > 0 ? root.src : ""
            }

            Item {
                anchors.fill: shot
                property real k: view.fit
                Repeater { model: root.mosaics; delegate: mosaic }
            }

            Canvas {
                id: draw
                anchors.fill: shot
                onWidthChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    root.shapes.forEach(sh => root.drawShape(ctx, sh, view.fit));
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.CrossCursor
                    function at(m) { return [m.x / view.fit, m.y / view.fit]; }
                    onPressed: m => {
                        if (root.editing) root.commitText();
                        var p = at(m), text = root.tool === "text";
                        var sh = { tool: root.tool, color: String(root.colour), width: root.strokeWidth,
                                   pts: text ? p : p.concat(p), text: "" };
                        root.shapes.push(sh);
                        if (text) root.editing = sh;
                        root.changed();
                    }
                    onPositionChanged: m => {
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
                model: ["pen", "arrow", "rect", "box", "obfuscate", "text"]
                Txt {
                    id: toolLabel
                    required property string modelData
                    text: toolLabel.modelData[0] + " " + toolLabel.modelData
                    color: root.tool === toolLabel.modelData ? Theme.mauve : Theme.overlay1
                    font.pixelSize: Config.s(12)
                }
            }
            Txt {
                text: "1–6 colour · u undo · ⏎ copy · ^S save · esc close"
                color: Theme.overlay0
                font.pixelSize: Config.s(12)
            }
        }

        // Full-resolution render, built only while exporting: the native image
        // plus the shapes at k=1, grabbed once both have painted. Zero-size and
        // clipped so it never shows; grabToImage renders the subtree on its own.
        // (Canvas.loadImage/drawImage would be one item fewer, but under the
        // software backend the image never loads.)
        Item {
            width: 0; height: 0
            clip: true
            Loader {
                active: root.after !== ""
                sourceComponent: Item {
                    id: out
                    readonly property string file: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/annotated.png"
                    width: root.natW
                    height: root.natH
                    Image {
                        id: full
                        source: root.src
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
                        onPaint: root.shapes.forEach(sh => root.drawShape(getContext("2d"), sh, 1))
                        // painted fires every frame under the software backend.
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
