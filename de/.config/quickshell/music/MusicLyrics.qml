pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick
import ".."

// Tab 4 — the .lrc beside the playing track, scrolling with it. MPD serves
// audio, not arbitrary files, so this is read from disk: `file:` is relative to
// music_directory (~/Music), same basename with the extension swapped. All
// 3,523 sidecars here are time-tagged [mm:ss.xx], so it follows playback;
// untagged lines keep their order and simply never highlight.
Item {
    id: root

    required property var client

    readonly property string musicDir: (Quickshell.env("HOME") || "") + "/Music/"
    readonly property string lrcPath: {
        var file = root.client.song.file || "";
        if (file === "") return "";
        var dot = file.lastIndexOf(".");
        var slash = file.lastIndexOf("/");
        return root.musicDir + (dot > slash ? file.substring(0, dot) : file) + ".lrc";
    }

    property var lines: []          // [{ t: seconds or -1, text }]
    readonly property bool synced: {
        for (var i = 0; i < root.lines.length; i++)
            if (root.lines[i].t >= 0 && !root.lines[i].untimed) return true;
        return false;
    }
    readonly property string status: {
        if (root.client.song.file === undefined) return "nothing playing";
        if (root.lines.length === 0) return "no .lrc beside this track";
        return root.synced ? "synced" : "unsynced";
    }

    // The last line whose stamp has passed.
    readonly property int activeLine: {
        if (!root.synced) return -1;
        var now = root.client.elapsed;
        var hit = -1;
        for (var i = 0; i < root.lines.length; i++) {
            if (root.lines[i].t < 0 || root.lines[i].untimed) continue;
            if (root.lines[i].t <= now) hit = i; else break;
        }
        return hit;
    }

    function parse(text) {
        if (!text) { root.lines = []; return; }
        var out = [];
        var raw = text.split("\n");
        var lastT = -1;
        for (var i = 0; i < raw.length; i++) {
            var line = raw[i];
            var re = /\[(\d+):(\d+(?:\.\d+)?)\]/g;
            var m, last = 0, stamps = [];
            while ((m = re.exec(line)) !== null) {
                stamps.push(parseInt(m[1]) * 60 + parseFloat(m[2]));
                last = re.lastIndex;
            }
            var body = line.substring(last).trim();
            if (stamps.length === 0) {
                // Metadata like [ar:...] has no numeric stamp and no body. A
                // real untagged line inherits the last stamp seen so it sorts
                // where it sits in the file — carrying -1 sorted every one of
                // them above the entire song.
                if (body !== "" && !/^\[[a-z]+:/i.test(line))
                    out.push({ t: lastT, text: line.trim(), untimed: true });
                continue;
            }
            for (var s = 0; s < stamps.length; s++) {
                lastT = stamps[s];
                out.push({ t: stamps[s], text: body, untimed: false });
            }
        }
        // Index as tiebreak: Array.sort is not required to be stable for the
        // lines an untagged run shares a stamp with.
        for (var k = 0; k < out.length; k++) out[k].i = k;
        out.sort((a, b) => (a.t - b.t) || (a.i - b.i));
        root.lines = out;
    }

    function handleKey(event) {
        switch (event.key) {
        case Qt.Key_J: view.contentY = Math.min(view.contentY + Ui.s(31),
                                                Math.max(0, view.contentHeight - view.height));
            return true;
        case Qt.Key_K: view.contentY = Math.max(view.contentY - Ui.s(31), 0); return true;
        }
        return false;
    }

    onLrcPathChanged: root.lines = []

    // Most tracks having no sidecar is normal, not an error worth logging.
    FileView {
        id: lrc
        path: root.lrcPath
        printErrors: false
        onLoaded: root.parse(lrc.text())
        onLoadFailed: root.lines = []
    }

    Connections {
        target: root
        function onActiveLineChanged() {
            if (root.activeLine >= 0) view.positionViewAtIndex(root.activeLine, ListView.Center);
        }
    }

    Txt {
        id: head
        anchors { top: parent.top; left: parent.left; right: parent.right }
        anchors.margins: Ui.s(12)
        anchors.bottomMargin: 0
        height: Ui.s(20)
        elide: Text.ElideRight
        font.pixelSize: Ui.fs(12)
        color: Theme.subtext0
        text: root.client.song.file !== undefined
              ? root.client.songTitle(root.client.song) + "  ·  " + (root.client.song.Artist || "")
              : ""
    }

    ListView {
        id: view
        anchors { top: head.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        anchors.topMargin: Ui.s(4)
        clip: true
        model: root.lines
        cacheBuffer: 0
        boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
            id: row
            required property var modelData
            required property int index
            readonly property bool active: row.index === root.activeLine
            width: view.width
            height: lyric.implicitHeight + Ui.s(8)

            Txt {
                id: lyric
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                anchors.leftMargin: Ui.s(16)
                anchors.rightMargin: Ui.s(16)
                wrapMode: Text.WordWrap
                font.pixelSize: Ui.fs(14)
                font.bold: row.active
                color: row.active ? Theme.mauve : (root.synced ? Theme.overlay0 : Theme.text)
                text: row.modelData.text === "" ? " " : row.modelData.text
            }
        }
    }

    Txt {
        anchors.centerIn: parent
        visible: root.lines.length === 0
        color: Theme.surface1
        font.pixelSize: Ui.fs(13)
        text: root.client.song.file === undefined ? "nothing playing" : "no lyrics for this track"
    }
}
