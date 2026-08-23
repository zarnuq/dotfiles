import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

// Visual wallpaper picker: category sidebar + thumbnail grid.
// Triggered by IPC so the reach keybind is `qs ipc call wallpaperpicker toggle`.
//
// Tiles come from ~/.cache/wallpaper-thumbs (see the wallpaper-thumbs script),
// never from the originals -- decoding a 22MB source per tile is what makes a
// previewer peg every core. The script is re-run on each open so newly added
// wallpapers appear; warm it costs ~35ms.
//
// Per-output overlay + pointer containment to find the focused monitor is the
// same trick Launcher.qml uses, for the same reason: reach has no IPC to ask,
// and it gives keyboard focus to every layer surface.
Scope {
    id: root
    property bool open: false

    property var all: []        // [{cat, path, thumb}] -- every wallpaper
    property var cats: ["All"]  // sidebar entries
    property int catIndex: 0
    property var results: []    // `all` filtered to the selected category
    property int selected: 0
    property int columns: 1     // set by the grid; j/k step by this
    property string activeScreen: ""

    property var dims: ({})     // path -> "WxH", memoized so revisits never re-probe
    property string curDim: ""

    readonly property string tool: Quickshell.env("HOME") + "/.local/bin/wallpaper-thumbs"

    onOpenChanged: if (open) { activeScreen = ""; fallback.restart(); reload(); }
    Timer {
        id: fallback
        interval: 150
        onTriggered: if (root.open && root.activeScreen === "") root.activeScreen = "DP-2";
    }

    function show()   { root.open = true; }
    function hide()   { root.open = false; }
    function toggle() { root.open = !root.open; }

    function reload() { if (!loader.running) loader.running = true; }

    // Render missing thumbs, then list. ';' not '&&' so a failed render still lists.
    Process {
        id: loader
        command: ["sh", "-c", root.tool + " >/dev/null 2>&1; " + root.tool + " --list"]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }

    function parse(text) {
        var lines = text.split("\n");
        var out = [], cats = ["All"], seen = ({});
        for (var i = 0; i < lines.length; i++) {
            if (lines[i] === "") continue;
            var p = lines[i].split("\t");
            if (p.length < 3) continue;
            out.push({ cat: p[0], path: p[1], thumb: p[2] });
            if (!seen[p[0]]) { seen[p[0]] = true; cats.push(p[0]); }
        }
        // Assign wholesale so the grid never flashes empty on a reload.
        root.all = out;
        root.cats = cats;
        if (root.catIndex >= cats.length) root.catIndex = 0;
        root.refresh();
    }

    function refresh() {
        var c = root.cats[root.catIndex], out = [];
        for (var i = 0; i < root.all.length; i++)
            if (c === "All" || root.all[i].cat === c) out.push(root.all[i]);
        root.results = out;
        root.selected = 0;
    }

    function setCat(i) {
        if (root.cats.length === 0) return;
        root.catIndex = (i + root.cats.length) % root.cats.length;
        root.refresh();
    }
    function move(d) {
        if (root.results.length === 0) return;
        root.selected = Math.max(0, Math.min(root.results.length - 1, root.selected + d));
    }
    // close=false applies without dismissing, so you can flip through live.
    function apply(close) {
        if (root.selected < 0 || root.selected >= root.results.length) return;
        Wallpaper.set(root.results[root.selected].path);
        if (close) root.hide();
    }

    function curPath() {
        if (root.selected < 0 || root.selected >= root.results.length) return "";
        return root.results[root.selected].path;
    }

    onSelectedChanged: root.updateDim()
    onResultsChanged: root.updateDim()

    function updateDim() {
        var p = root.curPath();
        if (p === "") { root.curDim = ""; dimProbe.stop(); return; }
        if (root.dims[p] !== undefined) { root.curDim = root.dims[p]; dimProbe.stop(); return; }
        root.curDim = "";
        dimProbe.restart();
    }

    // Debounced so holding j/k doesn't spawn a probe per row.
    Timer {
        id: dimProbe
        interval: 60
        onTriggered: root.probeDim()
    }

    function probeDim() {
        var p = root.curPath();
        if (p === "" || root.dims[p] !== undefined) return;
        if (dimProc.running) { dimProbe.restart(); return; }
        dimProc.path = p;
        dimProc.command = ["magick", "identify", "-ping", "-format", "%wx%h", p];
        dimProc.running = true;
    }

    // -ping reads the header only: 2ms on a 22MB PNG, where a full read is 558ms.
    Process {
        id: dimProc
        property string path: ""
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text.trim();
                if (t === "" || dimProc.path === "") return;
                var d = root.dims;
                d[dimProc.path] = t;
                root.dims = d;
                if (dimProc.path === root.curPath()) root.curDim = t;
            }
        }
    }

    IpcHandler {
        target: "wallpaperpicker"
        function toggle(): void { root.toggle(); }
        function show(): void   { root.show(); }
        function hide(): void   { root.hide(); }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: root.open

            color: "transparent"
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: (root.open && win.modelData.name === root.activeScreen)
                                         ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            anchors { top: true; bottom: true; left: true; right: true }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.hide()
                onContainsMouseChanged: if (containsMouse && root.open) root.activeScreen = win.modelData.name
            }

            Rectangle {
                id: box
                visible: root.open && win.modelData.name === root.activeScreen
                onVisibleChanged: if (visible) keys.forceActiveFocus()
                width: Math.round(win.width * 0.7)
                height: Math.round(win.height * 0.72)
                anchors.centerIn: parent
                color: Theme.base
                border.color: Theme.mauve
                border.width: 1
                radius: Theme.borderRadius

                MouseArea { anchors.fill: parent }   // swallow clicks so they don't close

                Item {
                    id: keys
                    anchors.fill: parent
                    anchors.margins: box.border.width
                    focus: true

                    Keys.onPressed: function (e) {
                        var plain = !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier));
                        if (e.key === Qt.Key_Escape) { root.hide(); }
                        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.apply(true); }
                        else if (e.key === Qt.Key_Space) { root.apply(false); }
                        else if (e.key === Qt.Key_Tab) { root.setCat(root.catIndex + 1); }
                        else if (e.key === Qt.Key_Backtab) { root.setCat(root.catIndex - 1); }
                        else if (e.key === Qt.Key_Right || (plain && e.key === Qt.Key_L)) { root.move(1); }
                        else if (e.key === Qt.Key_Left  || (plain && e.key === Qt.Key_H)) { root.move(-1); }
                        else if (e.key === Qt.Key_Down  || (plain && e.key === Qt.Key_J)) { root.move(root.columns); }
                        else if (e.key === Qt.Key_Up    || (plain && e.key === Qt.Key_K)) { root.move(-root.columns); }
                        else if (e.key === Qt.Key_Home) { root.selected = 0; }
                        else if (e.key === Qt.Key_End)  { root.selected = root.results.length - 1; }
                        else { return; }
                        e.accepted = true;
                    }

                    Row {
                        anchors.fill: parent
                        spacing: 0

                        // Category sidebar.
                        Rectangle {
                            width: 190
                            height: parent.height
                            color: Theme.base

                            ListView {
                                anchors.fill: parent
                                anchors.topMargin: 8
                                model: root.cats
                                boundsBehavior: Flickable.StopAtBounds
                                clip: true

                                delegate: Rectangle {
                                    required property string modelData
                                    required property int index
                                    width: 190; height: 34
                                    color: index === root.catIndex ? "#11111b" : "transparent"

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: { root.setCat(index); keys.forceActiveFocus(); }
                                    }

                                    Txt {
                                        anchors.fill: parent
                                        anchors.leftMargin: 14; anchors.rightMargin: 10
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                        text: modelData
                                        font.pixelSize: 15
                                        color: index === root.catIndex ? Theme.mauve : Theme.subtext0
                                    }
                                }
                            }
                        }

                        Rectangle { width: 1; height: parent.height; color: Theme.surface1 }

                        Column {
                            width: parent.width - 191
                            height: parent.height
                            spacing: 0

                            Item {
                                width: parent.width
                                height: parent.height - 34

                            GridView {
                                id: grid
                                anchors.fill: parent
                                clip: true
                                model: root.results
                                currentIndex: root.selected
                                boundsBehavior: Flickable.StopAtBounds

                                // ~250px tiles, whole number of columns, 16:9.
                                readonly property int cols: Math.max(1, Math.floor(width / 250))
                                cellWidth: Math.floor(width / cols)
                                cellHeight: Math.round(cellWidth * 9 / 16)
                                onColsChanged: root.columns = cols
                                Component.onCompleted: root.columns = cols

                                // Four extra rows kept alive around the viewport -- enough
                                // that a fast wheel scroll never outruns the decoders,
                                // still a bounded number of 400x225 pixmaps.
                                cacheBuffer: cellHeight * 4

                                flickDeceleration: 3000
                                maximumFlickVelocity: 6000

                                onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)

                                delegate: Item {
                                    required property var modelData
                                    required property int index
                                    width: grid.cellWidth
                                    height: grid.cellHeight

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 3
                                        color: Theme.surface0
                                        border.width: 2
                                        border.color: index === root.selected ? Theme.mauve : "transparent"

                                        Image {
                                            anchors.fill: parent
                                            anchors.margins: 2
                                            source: "file://" + modelData.thumb
                                            // Thumbs are natively 400x225, so this is a 1:1
                                            // decode with no rescale. Deliberately NOT
                                            // Wallpaper.decodeSize -- that value is the
                                            // full-screen shared-buffer size and pointing
                                            // tiles at it would decode originals-sized
                                            // pixmaps and blow up the wallpaper layer.
                                            sourceSize.width: 400
                                            sourceSize.height: 225
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true   // never block the UI thread on scroll
                                            cache: true
                                            clip: true
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onEntered: root.selected = index
                                            onClicked: { root.selected = index; root.apply(true); }
                                        }
                                    }
                                }
                            }

                            // Flickable's default wheel step is a few pixels (barely moves
                            // on a 250px tile grid); a full row per notch overshoots. Half a
                            // row sits between. NoButton so clicks/hover still reach tiles.
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                onWheel: function (w) {
                                    var step = grid.cellHeight * ((w.modifiers & Qt.ShiftModifier) ? 2 : 0.5);
                                    var max = Math.max(0, grid.contentHeight - grid.height);
                                    grid.contentY = Math.max(0, Math.min(max,
                                        grid.contentY + (w.angleDelta.y > 0 ? -step : step)));
                                }
                            }
                            }

                            // Footer: what's selected, where you are, and the keys.
                            Rectangle {
                                width: parent.width
                                height: 34
                                color: Theme.base

                                Rectangle { width: parent.width; height: 1; color: Theme.surface1 }

                                Row {
                                    id: info
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.max(0, hints.x - info.x - 16)
                                    spacing: 10

                                    Txt {
                                        // Yields to the dimensions label, which never elides.
                                        width: Math.max(0, info.width - dim.width - info.spacing)
                                        elide: Text.ElideMiddle
                                        font.pixelSize: 13
                                        color: Theme.subtext0
                                        text: {
                                            var p = root.curPath();
                                            return p === "" ? "" : p.substring(p.lastIndexOf("/") + 1);
                                        }
                                    }

                                    Txt {
                                        id: dim
                                        font.pixelSize: 13
                                        color: Theme.surface1
                                        text: root.curDim
                                    }
                                }

                                Txt {
                                    id: hints
                                    anchors.right: parent.right
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    font.pixelSize: 13
                                    color: Theme.surface1
                                    text: (root.results.length ? (root.selected + 1) + "/" + root.results.length : "0/0")
                                          + "   ⏎ set   ␣ preview   ⇥ category"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
