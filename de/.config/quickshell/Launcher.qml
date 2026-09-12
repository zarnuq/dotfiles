import Quickshell
import QtQuick

// Minimal drun-style app launcher (replaces `rofi -show drun`), plus a file
// mode: a query beginning with "/" searches $HOME instead of the app list and
// opens the hit in nvim (directories in yazi).
// Triggered by IPC so the reach keybind is just `qs ipc call launcher toggle`.
// Picker owns the overlay, the IPC target and the focused-monitor logic; this
// file is just the query, the list, and the keys. The corpus and the ranking
// live in FileIndex.qml — including why this doesn't just shell out to fzf.
//
// Geometry/colours match spotlight-dark.rasi: 35%x50%, 1px mauve border, zero
// padding, input font 20, tight rows, dark (#11111b) selection with #bac2de text.
Picker {
    id: root

    ipcTarget: "launcher"
    widthFraction: 0.35
    heightFraction: 0.5

    property string query: ""

    // "/" as the first character switches modes; the rest is the file query.
    // No app's name starts with a slash, so the sigil costs nothing.
    readonly property bool fileMode: root.query.charAt(0) === "/"
    readonly property string fileQuery: root.fileMode ? root.query.slice(1) : ""
    property var fileResults: []

    // The index is ~10 MB of JS strings, so it's built when file mode is first
    // entered rather than at startup, and dropped once the launcher has been
    // shut for a minute. Rebuilding costs ~0.1s of fd, which is also what keeps
    // it from ever going stale.
    onFileModeChanged: if (fileMode) { idleRelease.stop(); if (!FileIndex.ready) FileIndex.build(); }
    onOpenChanged: if (!open) idleRelease.restart();
    Timer { id: idleRelease; interval: 60000; onTriggered: FileIndex.release() }

    // Debounced because the first keystroke of a new query is a full scan of
    // ~46k entries (~50-130ms); every later one narrows the previous result set
    // and costs ~1ms. Without this, holding backspace re-scans per character.
    Timer {
        id: debounce
        interval: 40
        onTriggered: root.fileResults = FileIndex.search(root.fileQuery, 200)
    }
    onFileQueryChanged: if (fileQuery === "") { fileResults = []; debounce.stop(); } else debounce.restart();

    // fd finishes after the box is already open and typed into.
    Connections {
        target: FileIndex
        function onReadyChanged() { if (FileIndex.ready && root.fileQuery !== "") debounce.restart(); }
    }

    // A live binding, NOT a snapshot. DesktopEntries scans asynchronously —
    // `applications.values` is empty at load and fills ~50ms later — so a list
    // computed once when the box opened stayed empty for that entire open if
    // you hit Super+Space right after the shell started or hot-reloaded. Read
    // inside a binding, a late scan (or a rescan when a package is installed)
    // fills the list that's already on screen.
    readonly property var results: {
        if (root.fileMode) return root.fileResults;
        var q = root.query.toLowerCase();
        var vals = DesktopEntries.applications.values;
        var out = [];
        for (var i = 0; i < vals.length; i++) {
            var a = vals[i];
            if (a.noDisplay) continue;
            if (q === "" || a.name.toLowerCase().indexOf(q) !== -1) out.push(a);
        }
        out.sort(function (x, y) { return x.name.localeCompare(y.name); });
        return out;
    }
    onQueryChanged: root.selected = 0

    // yazi is run *inside* an interactive zsh rather than as kitty's command,
    // so quitting it (`q`) drops into a shell in the directory it was left in
    // instead of taking the window down with it. `y` is the zshrc wrapper that
    // does the --cwd-file dance; `exec zsh` replaces it with a clean prompt.
    function yaziCmd(path) {
        return ["kitty", "-e", "zsh", "-ic", 'y "$1"; exec zsh', "zsh", path];
    }

    // Enter edits: nvim for a file, yazi for a directory (nvim on a directory
    // lands in netrw, which nvim-tree disables). Shift+Enter always opens yazi
    // — on a file that means yazi in its parent with the file selected, which
    // is the "land next to it and look around" case. Ctrl+Enter hands it to
    // xdg-open instead (an image or a PDF in nvim is no use), Ctrl+T drops a
    // shell in the containing directory, and Ctrl+Y copies the path without
    // opening anything.
    function launch(action) {
        if (root.selected < 0 || root.selected >= root.results.length) return;
        var hit = root.results[root.selected];

        if (!root.fileMode) {
            hit.execute();
        } else if (action === "copy") {
            Quickshell.execDetached(["wl-copy", "--", hit.path]);
        } else if (action === "xdg") {
            Quickshell.execDetached(["xdg-open", hit.path]);
        } else if (action === "yazi") {
            Quickshell.execDetached(root.yaziCmd(hit.path));
        } else if (action === "term") {
            // hit.dir is the ~-abbreviated label the row draws; cut the real
            // parent off the path instead. A directory hit is its own cwd.
            var cwd = hit.isDir ? hit.path : hit.path.slice(0, hit.path.lastIndexOf("/"));
            Quickshell.execDetached(["kitty", "--directory", cwd]);
        } else if (hit.isDir) {
            Quickshell.execDetached(root.yaziCmd(hit.path));
        } else {
            Quickshell.execDetached(["kitty", "-e", "nvim", hit.path]);
        }
        root.hide();
    }

    box: Component {
        Column {
            id: content
            spacing: 0

            // Called by Picker every time the box appears on an output.
            function reset() {
                field.text = ""; root.query = ""; root.selected = 0;
                field.forceActiveFocus();
            }

            // Input row (rofi inputbar: no box, just the entry).
            Item {
                width: parent.width
                height: 52

                TextInput {
                    id: field
                    anchors.fill: parent
                    anchors.leftMargin: 12; anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Theme.font; font.pixelSize: 24
                    focus: true
                    onTextChanged: root.query = text
                    Keys.onPressed: function (e) {
                        if (e.key === Qt.Key_Escape) { root.hide(); e.accepted = true; }
                        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                            root.launch((e.modifiers & Qt.ControlModifier) ? "xdg"
                                        : (e.modifiers & Qt.ShiftModifier) ? "yazi" : "");
                            e.accepted = true;
                        } else if (e.key === Qt.Key_Y && (e.modifiers & Qt.ControlModifier) && root.fileMode) {
                            root.launch("copy"); e.accepted = true;
                        } else if (e.key === Qt.Key_T && (e.modifiers & Qt.ControlModifier) && root.fileMode) {
                            root.launch("term"); e.accepted = true;
                        }
                        else if (e.key === Qt.Key_Down || (e.key === Qt.Key_J && (e.modifiers & Qt.ControlModifier))) {
                            root.selected = Math.min(root.selected + 1, root.results.length - 1); e.accepted = true;
                        } else if (e.key === Qt.Key_Up || (e.key === Qt.Key_K && (e.modifiers & Qt.ControlModifier))) {
                            root.selected = Math.max(root.selected - 1, 0); e.accepted = true;
                        }
                    }
                }

                // Placeholder. It also survives the lone "/" that switches to
                // file mode, so the box says what it's searching before you've
                // typed a query — which means it has to start AFTER the slash
                // and its cursor instead of on top of them.
                Txt {
                    anchors.fill: parent
                    anchors.leftMargin: 12 + (field.text === "" ? 0 : field.contentWidth + 10)
                    anchors.rightMargin: 12
                    verticalAlignment: Text.AlignVCenter
                    text: field.text === "/" ? "Find file…" : "Search…  ( / for files)"
                    color: Theme.subtext0
                    font.pixelSize: 24
                    visible: field.text === "" || field.text === "/"
                }
            }

            // Results.
            Item {
                width: parent.width
                height: parent.height - 52

                Txt {
                    anchors.centerIn: parent
                    visible: root.results.length === 0
                    text: !root.fileMode ? (root.query === "" ? "no applications found" : "no matches")
                          : !FileIndex.ready ? "indexing…"
                          : root.fileQuery === "" ? FileIndex.count + " files"
                          : "no matches"
                    color: Theme.subtext0
                    font.pixelSize: 17
                }

                ListView {
                    id: list
                    anchors.fill: parent
                    clip: true
                    model: root.results
                    currentIndex: root.selected
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: list.width; height: 38
                        color: index === root.selected ? Theme.rowSelectBg : "transparent"

                        // positionChanged, NOT entered: arrowing down scrolls
                        // the view, which slides a different row under a
                        // motionless cursor and fires entered — so every
                        // keypress handed the selection straight back to
                        // whatever the pointer happened to sit on. Only real
                        // pointer movement should steal it.
                        MouseArea {
                            id: hover
                            anchors.fill: parent
                            hoverEnabled: true
                            onPositionChanged: function (e) { if (root.hoverMoved(hover, e)) root.selected = index; }
                            onClicked: { root.selected = index; root.launch(); }
                        }

                        // App row: icon + name. File row: a glyph, the
                        // basename, and the parent directory dimmed on the
                        // right — elided from the LEFT, so the deep end of the
                        // path stays visible. That tail is the only thing
                        // telling four identically-named .zshrc hits apart.
                        Item {
                            anchors.fill: parent
                            anchors.leftMargin: 12; anchors.rightMargin: 12

                            Image {
                                visible: !root.fileMode
                                anchors.verticalCenter: parent.verticalCenter
                                width: 26; height: 26
                                sourceSize.width: 26; sourceSize.height: 26
                                fillMode: Image.PreserveAspectFit
                                source: (!root.fileMode && modelData.icon)
                                        ? Quickshell.iconPath(modelData.icon, "application-x-executable") : ""
                            }

                            Txt {
                                visible: root.fileMode
                                anchors.verticalCenter: parent.verticalCenter
                                width: 26
                                horizontalAlignment: Text.AlignHCenter
                                text: (root.fileMode && modelData.isDir) ? "\uf07b" : "\uf15b"
                                color: (root.fileMode && modelData.isDir) ? Theme.blue : Theme.subtext0
                                font.pixelSize: 16
                            }

                            Txt {
                                id: dirLabel
                                visible: root.fileMode
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, parent.width * 0.55)
                                elide: Text.ElideLeft
                                horizontalAlignment: Text.AlignRight
                                text: root.fileMode ? modelData.dir : ""
                                color: Theme.subtext0
                                font.pixelSize: 15
                            }

                            Txt {
                                anchors.left: parent.left
                                anchors.leftMargin: 34
                                anchors.right: root.fileMode ? dirLabel.left : parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                text: modelData.name
                                color: index === root.selected ? Theme.rowSelectFg : Theme.text
                                font.pixelSize: 19
                            }
                        }
                    }
                }
            }
        }
    }
}
