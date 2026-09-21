pragma ComponentBehavior: Bound
import Quickshell.Services.Mpris
import QtQuick
// Parent import: `Txt` (and the root singletons) live one level up. A QML
// file does NOT see its parent directory implicitly — only its own.
import ".."

// Window content: composition and focus. MusicController owns queue interaction;
// the header, queue, search bar and overlays own their respective presentation.
FocusScope {
    id: root
    focus: true

    property var client: MpdClient
    property alias controller: state
    property real fontScale: 1.2
    function s(n) { return Config.s(n); }
    function fs(n) { return Math.round(root.s(n) * root.fontScale); }

    signal closeRequested()

    // Reuse the bridge's cached artwork instead of another MPD albumart request.
    property string art: {
        var players = Mpris.players ? Mpris.players.values : [];
        for (var i = 0; i < players.length; i++)
            if ((players[i].dbusName || "").toLowerCase().indexOf("mpd") >= 0)
                return players[i].trackArtUrl || "";
        return "";
    }

    function reset() {
        state.reset();
        root.forceActiveFocus();
    }

    MusicController {
        id: state
        client: root.client
        viewportRows: queueView.viewportRows
        onCloseRequested: root.closeRequested()
        // Once the input hides, subsequent keys belong to the music view.
        onSearchingChanged: if (!searching) root.forceActiveFocus()
    }

    Keys.onPressed: event => state.handleKey(event)

    MusicHeader {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        anchors.margins: root.s(12)
        client: root.client
        art: root.art
        fontScale: root.fontScale
    }

    Row {
        id: tabs
        anchors { top: header.bottom; left: parent.left; right: parent.right }
        anchors.margins: root.s(12)
        anchors.topMargin: root.s(6)
        height: root.s(30)
        spacing: root.s(18)

        Repeater {
            model: state.tabs
            delegate: Txt {
                id: tabLabel
                required property var modelData
                required property int index
                readonly property bool active: index === state.tab
                text: (index + 1) + " " + modelData.name
                font.pixelSize: root.fs(13)
                font.bold: active
                color: active ? Theme.mauve : Theme.subtext0
                MouseArea {
                    anchors.fill: parent
                    onClicked: state.setTab(tabLabel.index)
                }
            }
        }
    }

    Rectangle {
        id: tabRule
        anchors { top: tabs.bottom; left: parent.left; right: parent.right }
        height: 1
        color: Theme.surface0
    }

    MusicQueue {
        id: queueView
        anchors { top: tabRule.bottom; left: parent.left; right: parent.right; bottom: statusBar.top }
        anchors.topMargin: root.s(4)
        visible: state.tab === 0
        controller: state
        fontScale: root.fontScale
    }

    // A pane is built the first time you visit its tab and kept afterwards, so
    // the directory you were in survives a trip to the queue. A tab you never
    // open is never built.
    component Pane: Loader {
        anchors { top: tabRule.bottom; left: parent.left; right: parent.right; bottom: statusBar.top }
        anchors.topMargin: root.s(4)
    }

    Pane {
        id: dirPane
        active: state.tab === 1 || status === Loader.Ready
        visible: state.tab === 1
        sourceComponent: MusicDirectories { client: root.client; fontScale: root.fontScale }
    }
    Pane {
        id: playlistPane
        active: state.tab === 2 || status === Loader.Ready
        visible: state.tab === 2
        sourceComponent: MusicPlaylists { client: root.client; fontScale: root.fontScale }
    }
    Pane {
        id: lyricsPane
        active: state.tab === 3 || status === Loader.Ready
        visible: state.tab === 3
        sourceComponent: MusicLyrics { client: root.client; fontScale: root.fontScale }
    }
    Pane {
        id: searchPane
        active: state.tab === 4 || status === Loader.Ready
        visible: state.tab === 4
        sourceComponent: MusicSearch {
            client: root.client
            fontScale: root.fontScale
            // The pane cannot take focus back itself; the FocusScope must.
            onFocusReleased: root.forceActiveFocus()
        }
    }

    // Search owns the keyboard while its field has focus, so hand focus over
    // when that tab is shown and take it back on the way out.
    onActivePaneChanged: {
        // Leaving the Search tab must release its field EXPLICITLY. A
        // FocusScope delegates to whichever descendant holds focus, so
        // forceActiveFocus() here cannot take it back from a TextInput that
        // still has it — and hiding the pane's Loader does not clear it either.
        // Without this, switching away (Tab is not consumed by a TextInput)
        // left every subsequent key typing into an invisible search box.
        if (searchPane.item && state.tab !== 4) searchPane.item.leaveField();
        if (state.tab === 4 && searchPane.item) searchPane.item.focusField();
        else root.forceActiveFocus();
    }
    readonly property var activePane: state.tab === 1 ? dirPane.item
                                      : state.tab === 2 ? playlistPane.item
                                      : state.tab === 3 ? lyricsPane.item
                                      : state.tab === 4 ? searchPane.item : null
    Binding { target: state; property: "pane"; value: root.activePane }

    MusicBanner {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: statusBar.top
        anchors.bottomMargin: root.s(10)
        controller: state
        fontScale: root.fontScale
    }

    MusicStatusBar {
        id: statusBar
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        controller: state
        fontScale: root.fontScale
    }

    MusicOverlay {
        anchors.fill: parent
        mode: state.overlay
        song: state.current
        fontScale: root.fontScale
        onDismissed: state.overlay = ""
    }
}
