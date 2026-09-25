import Quickshell
import Quickshell.Io
import QtQuick

// Clipboard history picker (replaces `clipfzf`, the Super+V floating kitty).
//
// Capture already lived here — Clipboard.qml runs the two wl-paste watchers —
// and this was the half still in a terminal.
//
// The image preview is what made it worth moving: inside fzf, clipfzf can only
// draw one by shelling `kitten icat` in unicode-placeholder mode (the one mode
// that survives fzf's redraws), and only because it is always run inside kitty.
// Here an image entry is a file on disk and an Image points at it.
//
// Picker owns the overlay, the IPC target, the focused-monitor latching and the
// hover guard; this file is the list, the preview and the keys.
Picker {
    id: root

    ipcTarget: "clipboard"
    widthFraction: 0.6
    heightFraction: 0.6

    readonly property int queryHeight: s(46)
    readonly property int footerHeight: s(28)
    readonly property int listRowHeight: s(32)

    property var entries: []      // [{id, raw, preview, isImage, meta}]
    property string query: ""

    readonly property var results: {
        var q = root.query.toLowerCase();
        if (q === "") return root.entries;
        var out = [];
        for (var i = 0; i < root.entries.length; i++)
            if (root.entries[i].preview.toLowerCase().indexOf(q) !== -1) out.push(root.entries[i]);
        return out;
    }
    onQueryChanged: root.selected = 0

    // What j/k walk: Picker's own move() clamps against this, so the picker
    // doesn't carry its own copy of that arithmetic.
    count: root.results.length

    readonly property var cur: (root.selected >= 0 && root.selected < root.results.length)
                               ? root.results[root.selected] : null

    // ── history ──────────────────────────────────────────────────────────
    // Listed once per open, never polled: the picker is transient, and a closed
    // one should cost nothing.
    onOpened: { root.query = ""; root.cache = ({}); root.reload(); }

    function reload() { if (!lister.running) lister.running = true; }

    Process {
        id: lister
        command: ["cliphist", "list"]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }

    // `id<TAB>preview`, where cliphist renders an image entry's preview as
    // `[[ binary data 40 KiB png 1362x367 ]]`. That line is enough to know an
    // entry is an image, so nothing has to be decoded to find out — which is
    // the whole point of not doing this the way clipfzf does (it decodes and
    // asks `file` for the mime type, per highlighted row).
    function parse(text) {
        var lines = text.split("\n"), out = [];
        for (var i = 0; i < lines.length; i++) {
            var t = lines[i].indexOf("\t");
            if (t < 0) continue;
            var preview = lines[i].slice(t + 1);
            var m = preview.match(/^\[\[\s*binary data\s+(.*?)\s*\]\]$/);
            out.push({
                id: lines[i].slice(0, t),
                raw: lines[i],
                preview: preview,
                isImage: m !== null,
                meta: m !== null ? m[1] : ""
            });
        }
        root.entries = out;
        if (root.selected >= root.results.length) root.selected = Math.max(0, root.results.length - 1);
    }

    // ── preview ──────────────────────────────────────────────────────────
    readonly property string cacheDir:
        (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/quickshell/clip"

    // id -> {text} | {img}. Cleared on every open, so an id that changed hands
    // (a `cliphist wipe` restarts ids at 1) can't show the previous entry's
    // contents; the decoded image files are purged once at startup for the same
    // reason, and the preview Image is uncached so it re-reads from disk.
    property var cache: ({})
    property string previewText: ""
    property string previewImage: ""

    Component.onCompleted: Quickshell.execDetached(["sh", "-c", 'rm -f "$1"/*.img', "sh", root.cacheDir])

    onCurChanged: {
        root.previewText = "";
        root.previewImage = "";
        if (!root.cur) { debounce.stop(); return; }
        var hit = root.cache[root.cur.id];
        if (hit !== undefined) { root.apply(hit); debounce.stop(); return; }
        debounce.restart();
    }

    function apply(v) {
        root.previewText = v.text !== undefined ? v.text : "";
        root.previewImage = v.img !== undefined ? v.img : "";
    }

    function store(id, v) {
        var c = root.cache;
        c[id] = v;
        root.cache = c;
        if (root.cur && root.cur.id === id) root.apply(v);
    }

    // Debounced so holding j/k doesn't spawn a decode per row it passes over.
    Timer {
        id: debounce
        interval: 60
        onTriggered: root.decode()
    }

    function decode() {
        var e = root.cur;
        if (!e || root.cache[e.id] !== undefined) return;
        if (textDec.running || imgDec.running) { debounce.restart(); return; }
        if (e.isImage) {
            imgDec.entryId = e.id;
            imgDec.command = ["sh", "-c", 'mkdir -p "$2" && cliphist decode "$1" > "$2/$1.img"',
                              "sh", e.id, root.cacheDir];
            imgDec.running = true;
        } else {
            textDec.entryId = e.id;
            // head -c bounds it: the pane shows a screenful, and a 10MB paste
            // has no business becoming a QML string.
            textDec.command = ["sh", "-c", 'cliphist decode "$1" | head -c 4000', "sh", e.id];
            textDec.running = true;
        }
    }

    Process {
        id: textDec
        property string entryId: ""
        stdout: StdioCollector { onStreamFinished: root.store(textDec.entryId, { text: text }) }
    }

    // Writes a file rather than a pipe, so the result is the path, not stdout.
    Process {
        id: imgDec
        property string entryId: ""
        onExited: function (code) {
            if (code === 0) root.store(imgDec.entryId, { img: root.cacheDir + "/" + imgDec.entryId + ".img" });
        }
    }

    // ── actions ──────────────────────────────────────────────────────────
    // wl-copy forks a daemon to serve the selection for as long as it's owned,
    // so it has to outlive this call — execDetached is exactly that. clipfzf's
    // stdout/stderr redirect exists only because that daemon inherited kitty's
    // pty and kept the window from closing; there is no pty here.
    function copy() {
        if (!root.cur) return;
        Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", root.cur.id]);
        root.hide();
    }

    // cliphist delete takes the whole list line on stdin, not an id.
    function remove() {
        if (!root.cur || deleter.running) return;
        deleter.command = ["sh", "-c", 'printf "%s\\n" "$1" | cliphist delete', "sh", root.cur.raw];
        deleter.running = true;
    }

    Process {
        id: deleter
        onExited: root.reload()
    }

    box: Component {
        Column {
            spacing: 0

            // Called by Picker each time the box appears on an output.
            function reset() { search.reset(); root.query = ""; }

            PickerSearch {
                id: search
                picker: root
                width: parent.width
                height: root.queryHeight
                margin: root.s(12)
                fontSize: root.s(19)
                placeholder: "Clipboard…"
                onTextChanged: root.query = text

                onSubmitted: root.copy()
                onExtraKey: function (e) {
                    if (e.key !== Qt.Key_D || !(e.modifiers & Qt.ControlModifier)) return;
                    root.remove();
                    e.accepted = true;
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.surface1 }

            Row {
                width: parent.width
                height: parent.height - root.queryHeight - root.footerHeight - 2
                spacing: 0

                // History list.
                PickerResults {
                    id: list
                    picker: root
                    width: Math.round(parent.width / 2)
                    height: parent.height
                    model: root.results
                    emptyText: root.entries.length === 0 ? "clipboard history empty" : "no matches"
                    emptySize: root.s(14)

                    delegate: PickerRow {
                        id: rowItem
                        picker: root
                        width: list.width
                        rowHeight: root.listRowHeight
                        onActivated: root.copy()

                        hMargin: root.s(12)
                        cellSpacing: root.s(10)

                        icon: rowItem.modelData.isImage ? "" : ""
                        iconWidth: root.s(18)
                        iconSize: root.s(14)
                        iconAlign: Text.AlignHCenter
                        iconColor: rowItem.modelData.isImage ? Theme.blue : Theme.subtext0

                        // An image entry has no text to show, so its
                        // size and format stand in for a preview.
                        label: rowItem.modelData.isImage
                               ? rowItem.modelData.meta : rowItem.modelData.preview
                        labelSize: root.s(14)
                        labelColor: rowItem.modelData.isImage ? Theme.subtext0
                                    : rowItem.sel ? Theme.rowSelectFg : Theme.text
                    }
                }

                Rectangle { width: 1; height: parent.height; color: Theme.surface1 }

                // Preview.
                Item {
                    id: pane
                    width: parent.width - Math.round(parent.width / 2) - 1
                    height: parent.height
                    clip: true

                    Image {
                        anchors.fill: parent
                        anchors.margins: root.s(10)
                        visible: root.previewImage !== "" && status === Image.Ready
                        source: root.previewImage === "" ? "" : "file://" + root.previewImage
                        // Bounded on purpose: under QT_QUICK_BACKEND=software
                        // every pixel of this is decoded and scaled on the
                        // CPU, so it is decoded at pane size, never at the
                        // source's (a full-resolution screenshot would be
                        // several hundred MB of pixmap for a 600px pane).
                        sourceSize.width: pane.width
                        sourceSize.height: pane.height
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        // The path is reused whenever an id comes back
                        // around, so a cached pixmap could outlive its file.
                        cache: false
                    }

                    Txt {
                        anchors.fill: parent
                        anchors.margins: root.s(12)
                        visible: root.previewImage === ""
                        text: root.previewText
                        color: Theme.subtext0
                        font.pixelSize: root.s(13)
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.surface1 }

            Item {
                width: parent.width
                height: root.footerHeight

                Txt {
                    anchors.left: parent.left
                    anchors.leftMargin: root.s(12)
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.results.length ? (root.selected + 1) + "/" + root.results.length : "0/0"
                    color: Theme.surface1
                    font.pixelSize: root.s(11)
                }

                Txt {
                    anchors.right: parent.right
                    anchors.rightMargin: root.s(12)
                    anchors.verticalCenter: parent.verticalCenter
                    text: "⏎ copy   ^d delete"
                    color: Theme.surface1
                    font.pixelSize: root.s(11)
                }
            }
        }
    }
}
