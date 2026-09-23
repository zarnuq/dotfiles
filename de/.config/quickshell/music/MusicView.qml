pragma ComponentBehavior: Bound
import Quickshell.Services.Mpris
import QtQuick
import ".."

// Window content: composition and focus. MusicController owns queue interaction;
// the header, queue, search bar and overlays own their respective presentation.
FocusScope {
    id: root
    focus: true

    property var client: MpdClient
    property alias controller: state

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
        anchors.margins: Ui.hs(12)
        client: root.client
        art: root.art
    }

    Row {
        id: tabs
        anchors { top: header.bottom; left: parent.left; right: parent.right }
        anchors.margins: Ui.hs(12)
        anchors.topMargin: Ui.hs(6)
        height: Ui.hs(24)
        spacing: Ui.hs(18)

        Repeater {
            model: state.tabs
            delegate: Txt {
                id: tabLabel
                required property var modelData
                required property int index
                readonly property bool active: index === state.tab
                // No leading digit: 1-5 still switch tabs, they just aren't
                // printed. A step above the list rows (fs(13)) and well under
                // the header, which is the order they should read in.
                text: modelData.name
                font.pixelSize: Ui.fs(15)
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
        anchors.topMargin: Ui.s(4)
        visible: state.tab === 0
        controller: state
    }

    // A pane is built the first time you visit its tab and kept afterwards, so
    // the directory you were in survives a trip to the queue. A tab you never
    // open is never built.
    component Pane: Loader {
        required property int tab
        anchors { top: tabRule.bottom; left: parent.left; right: parent.right; bottom: statusBar.top }
        anchors.topMargin: Ui.s(4)
        active: state.tab === tab || status === Loader.Ready
        visible: state.tab === tab
    }

    Pane { id: dirPane; tab: 1; sourceComponent: MusicDirectories { client: root.client } }
    Pane { id: playlistPane; tab: 2; sourceComponent: MusicPlaylists { client: root.client } }
    Pane { id: lyricsPane; tab: 3; sourceComponent: MusicLyrics { client: root.client } }
    Pane {
        id: searchPane
        tab: 4
        sourceComponent: MusicSearch {
            client: root.client
            // The pane cannot take focus back itself; the FocusScope must.
            onFocusReleased: root.forceActiveFocus()
        }
    }

    // Leaving the Search tab must release its field EXPLICITLY. A FocusScope
    // delegates to whichever descendant holds focus, so forceActiveFocus()
    // cannot take it back from a TextInput that still has it, and hiding the
    // pane's Loader does not clear it either. Without this, switching away
    // (Tab is not consumed by a TextInput) left every key typing into an
    // invisible search box. Arriving is the other way round now: the pane
    // starts in normal mode and only takes the keyboard when `i` asks it to.
    onActivePaneChanged: {
        if (searchPane.item && state.tab !== 4) searchPane.item.leaveField();
        root.forceActiveFocus();
    }
    readonly property var activePane: state.tab === 1 ? dirPane.item
                                      : state.tab === 2 ? playlistPane.item
                                      : state.tab === 3 ? lyricsPane.item
                                      : state.tab === 4 ? searchPane.item : null
    Binding { target: state; property: "pane"; value: root.activePane }

    MusicBanner {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: statusBar.top
        anchors.bottomMargin: Ui.s(10)
        controller: state
    }

    MusicStatusBar {
        id: statusBar
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        controller: state
    }

    MusicOverlay {
        anchors.fill: parent
        mode: state.overlay
        song: state.current
        onDismissed: state.overlay = ""
    }

    // Loaded only while it is up. A chooser that exists all session is a list
    // tree for nothing — and destroying it is what makes the focus return
    // certain: a hidden FocusScope still holds `focus`, so the scope below
    // would delegate right back into it and every key after an add, on every
    // tab, would land nowhere.
    Loader {
        id: playlistPicker
        anchors.fill: parent
        active: state.overlay === "playlist"
        sourceComponent: MusicPlaylistPicker {
            client: root.client
            uris: state.addTargets
            onClosed: { state.overlay = ""; root.forceActiveFocus(); }
            onAdded: (name, count) => state.notify(
                count === 1 ? "Added to  " + name : "Added " + count + " songs to  " + name)
        }
        onActiveChanged: if (!active) root.forceActiveFocus()
    }
}
