pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
// Parent import: Theme/Config/Txt and the shared Picker chrome live one
// level up; a QML file does not see its parent directory implicitly.
import ".."

// Minimal drun-style app launcher (replaces `rofi -show drun`), plus two
// sigil modes on the same query: "/" searches $HOME instead of the app list and
// opens the hit in nvim (directories in yazi), and ">" lists the shell's own
// menus and actions — the one place that answers "what can this thing open?"
// without knowing a keybind. Both cost nothing to add, since no app name
// begins with either character.
// Triggered by IPC so the reach keybind is just `qs ipc call launcher toggle`.
// Picker owns the overlay, the IPC target and the focused-monitor logic; this
// file is just the query, the list, and the keys. The corpus and the ranking
// are managed by FileIndex.qml; FileSearch.js implements indexing and ranking.
Picker {
    id: root

    ipcTarget: "launcher"
    widthFraction: 0.35
    heightFraction: 0.5

    property string query: ""

    // The first character picks the mode; the rest is that mode's query.
    // No app's name starts with a slash or an angle bracket, so the sigils cost
    // nothing — an empty sigil is a valid query meaning "show me everything".
    readonly property bool fileMode: root.query.charAt(0) === "/"
    readonly property string fileQuery: root.fileMode ? root.query.slice(1) : ""
    property var fileResults: []

    // ">" is the menu list (Commands.qml). A dozen rows off a literal array, so
    // unlike file mode there is nothing to index, debounce or release.
    readonly property bool cmdMode: root.query.charAt(0) === ">"
    readonly property string cmdQuery: root.cmdMode ? root.query.slice(1) : ""

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
        function onReadyChanged(): void { if (FileIndex.ready && root.fileQuery !== "") debounce.restart(); }
    }

    // A live binding, NOT a snapshot. DesktopEntries scans asynchronously —
    // `applications.values` is empty at load and fills ~50ms later — so a list
    // computed once when the box opened stayed empty for that entire open if
    // you hit Super+Space right after the shell started or hot-reloaded. Read
    // inside a binding, a late scan (or a rescan when a package is installed)
    // fills the list that's already on screen.
    readonly property var results: {
        if (root.fileMode) return root.fileResults;
        if (root.cmdMode) return Commands.search(root.cmdQuery);
        var q = root.query.toLowerCase();
        return DesktopEntries.applications.values
            .filter(a => !a.noDisplay && a.name.toLowerCase().includes(q))
            .sort((x, y) => x.name.localeCompare(y.name));
    }
    onQueryChanged: root.selected = 0

    // What the arrows walk.
    count: root.results.length

    // Enter edits: nvim for a file, yazi for a directory (nvim on a directory
    // lands in netrw, which nvim-tree disables). Shift+Enter always opens yazi
    // — on a file that means yazi in its parent with the file selected, which
    // is the "land next to it and look around" case. Ctrl+Enter hands it to
    // xdg-open instead (an image or a PDF in nvim is no use), Ctrl+T drops a
    // shell in the containing directory, and Ctrl+Y copies the path without
    // opening anything.
    function launch(action): void {
        var hit = root.results[root.selected];
        if (!hit) return;

        if (root.cmdMode) {
            // Hide FIRST: the launcher is a full-screen overlay on every
            // output, and the surface being summoned has to come up over an
            // empty screen rather than under this one.
            root.hide();
            Commands.run(hit);
            return;
        }

        if (!root.fileMode) {
            hit.execute();
        } else if (action === "copy") {
            Quickshell.execDetached(["wl-copy", "--", hit.path]);
        } else if (action === "xdg") {
            Quickshell.execDetached(["xdg-open", hit.path]);
        } else if (action === "term") {
            // hit.dir is the ~-abbreviated label the row draws; cut the real
            // parent off the path instead. A directory hit is its own cwd.
            var cwd = hit.isDir ? hit.path : hit.path.slice(0, hit.path.lastIndexOf("/"));
            Quickshell.execDetached(["kitty", "--directory", cwd]);
        } else if (action === "yazi" || hit.isDir) {
            // yazi runs *inside* an interactive zsh rather than as kitty's
            // command, so quitting it (`q`) drops into a shell in the directory
            // it was left in instead of taking the window down. `y` is the
            // zshrc wrapper that does the --cwd-file dance.
            Quickshell.execDetached(["kitty", "-e", "zsh", "-ic", 'y "$1"; exec zsh', "zsh", hit.path]);
        } else {
            Quickshell.execDetached(["kitty", "-e", "nvim", hit.path]);
        }
        root.hide();
    }

    box: Component {
        Column {
            spacing: 0

            // Called by Picker every time the box appears on an output.
            function reset(): void { search.reset(); root.query = ""; }

            // The placeholder survives the lone sigil that switches mode, so the
            // box says what it's searching before you've typed a query.
            PickerSearch {
                id: search
                picker: root
                width: parent.width
                height: root.s(52)
                margin: root.s(12)
                fontSize: root.s(24)
                placeholder: text === "/" ? "Find file…"
                             : text === ">" ? "Open menu…"
                             : "Search…  ( / files, > menus)"
                placeholderShown: text === "" || text === "/" || text === ">"
                onTextChanged: root.query = text

                onSubmitted: function (e) {
                    root.launch((e.modifiers & Qt.ControlModifier) ? "xdg"
                                : (e.modifiers & Qt.ShiftModifier) ? "yazi" : "");
                }
                onExtraKey: function (e) {
                    if (!(e.modifiers & Qt.ControlModifier) || !root.fileMode) return;
                    if (e.key === Qt.Key_Y) root.launch("copy");
                    else if (e.key === Qt.Key_T) root.launch("term");
                    else return;
                    e.accepted = true;
                }
            }

            PickerResults {
                id: list
                picker: root
                width: parent.width
                height: parent.height - root.s(52)
                model: root.results
                emptySize: root.s(17)
                emptyText: root.cmdMode ? "no matches"
                           : !root.fileMode ? (root.query === "" ? "no applications found" : "no matches")
                           : !FileIndex.ready ? "indexing…"
                           : root.fileQuery === "" ? FileIndex.count + " files"
                           : "no matches"

                delegate: Rectangle {
                    id: entry
                    required property var modelData
                    required property int index
                    width: list.width; height: root.s(38)
                    color: entry.index === root.selected ? Theme.rowSelectBg : "transparent"

                    PickerHover {
                        picker: root
                        row: entry.index
                        onActivated: root.launch()
                    }

                    // App row: icon + name. File row: a glyph, the basename,
                    // and the parent directory dimmed on the right. Menu row:
                    // a glyph, the name, a gloss and the key that also does it.
                    Item {
                        anchors.fill: parent
                        anchors.leftMargin: root.s(12); anchors.rightMargin: root.s(12)

                        Image {
                            visible: !root.fileMode && !root.cmdMode
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.s(26); height: root.s(26)
                            sourceSize.width: root.s(26); sourceSize.height: root.s(26)
                            fillMode: Image.PreserveAspectFit
                            source: entry.modelData.icon
                                    ? Quickshell.iconPath(entry.modelData.icon, "application-x-executable") : ""
                        }

                        Txt {
                            visible: root.fileMode || root.cmdMode
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.s(26)
                            horizontalAlignment: Text.AlignHCenter
                            text: root.cmdMode ? entry.modelData.glyph
                                  : entry.modelData.isDir ? "" : ""
                            color: root.cmdMode ? Theme.mauve
                                   : entry.modelData.isDir ? Theme.blue : Theme.subtext0
                            font.pixelSize: root.s(16)
                        }

                        // The key that also does this, read out of config.zon
                        // by Commands — the point of the list is to teach the
                        // binding, not to replace it. Anchored outermost and
                        // never elided: on a narrow output the gloss is what
                        // should give way.
                        Txt {
                            id: keyLabel
                            visible: root.cmdMode && entry.modelData.key !== ""
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.cmdMode ? entry.modelData.key : ""
                            color: Theme.overlay0
                            font.pixelSize: root.s(15)
                        }

                        Txt {
                            id: dirLabel
                            visible: root.fileMode || root.cmdMode
                            anchors.right: keyLabel.visible ? keyLabel.left : parent.right
                            anchors.rightMargin: keyLabel.visible ? root.s(14) : 0
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, parent.width * 0.55)
                            // Elided from the LEFT for a path (the deep end is
                            // what tells four .zshrc hits apart) but from the
                            // RIGHT for a gloss, which reads forwards.
                            elide: root.cmdMode ? Text.ElideRight : Text.ElideLeft
                            horizontalAlignment: Text.AlignRight
                            text: root.cmdMode ? entry.modelData.desc
                                  : root.fileMode ? entry.modelData.dir : ""
                            color: Theme.subtext0
                            font.pixelSize: root.s(15)
                        }

                        Txt {
                            anchors.left: parent.left
                            anchors.leftMargin: root.s(34)
                            anchors.right: (root.fileMode || root.cmdMode) ? dirLabel.left : parent.right
                            anchors.rightMargin: root.s(8)
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: entry.modelData.name
                            color: entry.index === root.selected ? Theme.rowSelectFg : Theme.text
                            font.pixelSize: root.s(19)
                        }
                    }
                }
            }
        }
    }
}
