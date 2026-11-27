pragma ComponentBehavior: Bound
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
    // Ctrl+F: the box fills the output and the preview takes the whole box.
    property bool zoomed: false
    widthFraction: root.zoomed ? 1 : 0.6
    heightFraction: root.zoomed ? 1 : 0.6
    // The history rows' height. No `rows` here, so boxHeight never reads it —
    // the box stays heightFraction tall — and PickerRow picks it up by default.
    rowHeight: s(32)

    property var entries: []      // [{id, raw, preview, isImage, meta, time}]

    readonly property var results: {
        var q = root.query.toLowerCase();
        return q === "" ? root.entries : root.entries.filter(e => e.preview.toLowerCase().includes(q));
    }

    // What j/k walk.
    count: root.results.length

    readonly property var cur: root.results[root.selected] || null

    // ── history ──────────────────────────────────────────────────────────
    // Listed once per open, never polled: the picker is transient, and a closed
    // one should cost nothing.
    // (The box's reset() clears the query; a running lister ignores a re-start.)
    onOpened: { root.zoomed = false; root.cache = ({}); lister.running = true; }

    Process {
        id: lister
        // Clipboard.qml's `<id> <epoch>` log rides after the list; its lines
        // have no tab, which is how parse() tells them apart.
        command: ["sh", "-c", 'cliphist list; cat "$1" 2>/dev/null', "sh", Config.stateDir + "/clip-times"]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }

    // `id<TAB>preview`, where cliphist renders an image entry's preview as
    // `[[ binary data 40 KiB png 1362x367 ]]`. That line is enough to know an
    // entry is an image, so nothing has to be decoded to find out — which is
    // the whole point of not doing this the way clipfzf does (it decodes and
    // asks `file` for the mime type, per highlighted row).
    function parse(text): void {
        var lines = text.split("\n"), out = [], times = {};
        for (var j = 0; j < lines.length; j++) {
            var tm = lines[j].match(/^(\d+) (\d+)$/);
            if (tm) times[tm[1]] = tm[2] * 1000;   // later lines win
        }
        var today = new Date().toDateString();
        for (var i = 0; i < lines.length; i++) {
            var t = lines[i].indexOf("\t");
            if (t < 0) continue;
            var id = lines[i].slice(0, t);
            var d = times[id] ? new Date(times[id]) : null;
            var preview = lines[i].slice(t + 1);
            var m = preview.match(/^\[\[\s*binary data\s+(.*?)\s*\]\]$/);
            out.push({
                id: id,
                raw: lines[i],
                preview: preview,
                isImage: m !== null,
                meta: m !== null ? m[1] : "",
                // Copied before the log existed: no time.
                time: !d ? "" : Qt.formatDateTime(d, d.toDateString() === today ? "hh:mm" : "MMM d hh:mm")
            });
        }
        root.entries = out;
    }

    // ── preview ──────────────────────────────────────────────────────────
    readonly property string cacheDir:
        Config.cacheHome + "/quickshell/clip"

    // id -> {text} | {img}. Cleared on every open, so an id that changed hands
    // (a `cliphist wipe` restarts ids at 1) can't show the previous entry's
    // contents; the decoded image files are purged once at startup for the same
    // reason, and the preview Image is uncached so it re-reads from disk.
    property var cache: ({})
    property string previewText: ""
    property string previewImage: ""

    Component.onCompleted: Quickshell.execDetached(["sh", "-c", 'rm -f "$1"/*.img', "sh", root.cacheDir])

    onCurChanged: {
        var hit = root.cur ? root.cache[root.cur.id] : undefined;
        root.apply(hit || {});
        if (root.cur && !hit) debounce.restart();
        else debounce.stop();
    }

    function apply(v): void {
        root.previewText = v.text || "";
        root.previewImage = v.img || "";
    }

    function store(id, v): void {
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

    function decode(): void {
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
    function copy(): void {
        if (!root.cur) return;
        Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", root.cur.id]);
        root.hide();
    }

    // A text entry in $EDITOR; saving a change copies it back (and so into
    // history as a new entry). wl-copy's output is dropped for the reason
    // clipfzf dropped it: its daemon would inherit kitty's pty and hold the
    // window open. It reads stdin into its own temp file, so the rm is safe.
    // Images are skipped: there is no image editor to hand them to.
    // zsh, not sh: qs inherits Gentoo's EDITOR=/bin/nano, and only .zshenv
    // sets the real one. ${=EDITOR} splits it, so `code --wait` works too.
    function edit(): void {
        if (!root.cur || root.cur.isImage) return;
        Quickshell.execDetached(["kitty", "-e", "zsh", "-c",
            'f=$(mktemp --suffix=.txt) || exit; cliphist decode "$1" > "$f"; cp "$f" "$f.orig"; ${=EDITOR:-nvim} "$f"; '
            + 'cmp -s "$f" "$f.orig" || wl-copy < "$f" >/dev/null 2>&1; rm -f "$f" "$f.orig"',
            "zsh", root.cur.id]);
        root.hide();
    }

    // OCR an image entry to text on the clipboard (so into history too). Grey +
    // 3x upscale first: raw tesseract on a dark-themed screenshot read garbage,
    // the scaled copy read it nearly clean. Meant for a crop of text — a photo
    // gives noise. Nothing readable = clipboard untouched, toast says so.
    function ocr(): void {
        if (!root.cur || !root.cur.isImage) return;
        Quickshell.execDetached(["sh", "-c",
            't=$(cliphist decode "$1" | magick - -colorspace gray -resize 300% png:- | tesseract stdin stdout --psm 6 2>/dev/null); '
            + 'if [ -n "$(printf %s "$t" | tr -d "[:space:]")" ]; then printf %s "$t" | wl-copy; '
            + 'notify-send -a clipboard "Text copied" "$(printf %s "$t" | head -c 200)"; '
            + 'else notify-send -a clipboard "No text found" "Clipboard unchanged"; fi',
            "sh", root.cur.id]);
        root.hide();
    }

    // cliphist delete takes the whole list line on stdin, not an id.
    function remove(): void {
        if (!root.cur || deleter.running) return;
        deleter.command = ["sh", "-c", 'printf "%s\\n" "$1" | cliphist delete', "sh", root.cur.raw];
        deleter.running = true;
    }

    Process {
        id: deleter
        onExited: lister.running = true
    }

    box: Component {
        PickerQueryBox {
            picker: root
            placeholder: "Clipboard…"
            hint: "⏎ copy   ^e edit   ^t ocr   ^f full   ^d delete"

            onSubmitted: root.copy()
            onExtraKey: function (e) {
                if (!(e.modifiers & Qt.ControlModifier)) return;
                if (e.key === Qt.Key_D) root.remove();
                else if (e.key === Qt.Key_E) root.edit();
                else if (e.key === Qt.Key_T) root.ocr();
                else if (e.key === Qt.Key_F) root.zoomed = !root.zoomed;
                else return;
                e.accepted = true;
            }

            Row {
                anchors.fill: parent
                spacing: 0

                // History list.
                PickerResults {
                    id: list
                    picker: root
                    width: root.zoomed ? 0 : Math.round(parent.width / 2)
                    visible: !root.zoomed
                    height: parent.height
                    model: root.results
                    emptyText: root.entries.length === 0 ? "clipboard history empty" : "no matches"

                    delegate: PickerRow {
                        id: rowItem
                        picker: root
                        width: list.width
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

                        trailing: rowItem.modelData.time
                        trailingWidth: root.s(90)
                        trailingSize: root.s(12)
                        trailingColor: Theme.overlay0
                    }
                }

                Rectangle { width: 1; height: parent.height; color: Theme.surface1; visible: !root.zoomed }

                // Preview.
                Item {
                    id: pane
                    width: root.zoomed ? parent.width : parent.width - Math.round(parent.width / 2) - 1
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
                        font.pixelSize: root.s(root.zoomed ? 20 : 13)
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
