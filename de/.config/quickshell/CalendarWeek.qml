import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

// Outlook-style week grid, as a full-screen overlay on the focused monitor.
//
// Why an overlay and not the sidebar: the ambient Calendar.qml card is pinned
// to a 420x451 slot (357x359 on the laptop at 0.85 scale). Seven day columns in
// 420px is 60px each — colour blocks with no room for a title. A week grid only
// reads at overlay size, so this is a separate widget that Calendar.qml's
// agenda list complements rather than replaces.
//
// The per-output / pointer-latching dance is the same one Launcher.qml does,
// and for the same reason: reach exposes no "which output has focus" IPC and
// grants keyboard focus to every layer surface, so pointer containment under
// sloppy focus is what singles one out. See Launcher.qml for the long version.
Scope {
    id: root
    property bool open: false
    property int offset: 0          // weeks from the current one; 0 = this week

    readonly property string script: Quickshell.env("HOME") + "/.config/quickshell/scripts/calendar.sh"
    property var week: ({ label: "", days: [], allday: [], timed: [], min_hour: 8, max_hour: 20, now: null })

    readonly property int minHour: week.min_hour !== undefined ? week.min_hour : 8
    readonly property int maxHour: week.max_hour !== undefined ? week.max_hour : 20
    property string activeScreen: ""

    onOpenChanged: if (open) { activeScreen = ""; fallback.restart(); reload(); }

    // If no pointer-enter ever arrives (cursor dead still as the surfaces map,
    // or the overlay opened from `qs ipc call` with no mouse movement at all),
    // fall back so the grid still shows somewhere. Launcher.qml hardcodes
    // "DP-2" here, which draws nothing on the laptop — resolve against the
    // screens that actually exist instead.
    Timer {
        id: fallback
        interval: 150
        onTriggered: {
            if (!root.open || root.activeScreen !== "") return;
            var screens = Quickshell.screens;
            if (screens.length === 0) return;
            for (var i = 0; i < screens.length; i++) {
                if (screens[i].name === "DP-2") { root.activeScreen = "DP-2"; return; }
            }
            root.activeScreen = screens[0].name;
        }
    }

    function show()   { root.open = true; }
    function hide()   { root.open = false; }
    function toggle() { root.open = !root.open; }
    function reload() { proc.running = false; proc.running = true; }
    function showWeek(o) { root.offset = o; reload(); }

    Process {
        id: proc
        command: [root.script, "week", String(root.offset)]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.week = JSON.parse(text); }
                catch (e) { root.week = { label: "unavailable", days: [], allday: [], timed: [], min_hour: 8, max_hour: 20, now: null }; }
            }
        }
    }

    // Keep the "now" line moving (and the grid fresh) while the overlay is up.
    Timer {
        interval: 60000
        running: root.open
        repeat: true
        onTriggered: root.reload()
    }

    IpcHandler {
        target: "calendar"
        function toggle(): void { root.toggle(); }
        function show(): void   { root.show(); }
        function hide(): void   { root.hide(); }
        function next(): void   { root.showWeek(root.offset + 1); }
        function prev(): void   { root.showWeek(root.offset - 1); }
        function today(): void  { root.showWeek(0); }
    }

    // ── Overlap layout ───────────────────────────────────────────────────────
    // Events that share a time range have to split their day column. Walk each
    // day in start order, group into clusters of transitively-overlapping
    // events, and pack each cluster into lanes (first lane whose last event has
    // ended). Lane count is per *cluster*, not per day, so two events at 9am
    // don't shrink an unrelated 5pm event to half width.
    function layout(timed) {
        var byDay = [[], [], [], [], [], [], []];
        for (var i = 0; i < timed.length; i++) {
            var t = timed[i];
            if (t.day < 0 || t.day > 6) continue;
            byDay[t.day].push({ day: t.day, start: t.start, end: t.end, summary: t.summary,
                                location: t.location, color: t.color, time: t.time, lane: 0, lanes: 1 });
        }

        var out = [];
        for (var d = 0; d < 7; d++) {
            var evs = byDay[d];
            evs.sort(function (a, b) { return (a.start - b.start) || (b.end - a.end); });

            var i2 = 0;
            while (i2 < evs.length) {
                var j = i2 + 1, clusterEnd = evs[i2].end;
                while (j < evs.length && evs[j].start < clusterEnd) {
                    clusterEnd = Math.max(clusterEnd, evs[j].end);
                    j++;
                }
                var lanes = [];                       // lane index -> minute it frees up
                for (var k = i2; k < j; k++) {
                    var e = evs[k], placed = -1;
                    for (var l = 0; l < lanes.length; l++) {
                        if (lanes[l] <= e.start) { placed = l; break; }
                    }
                    if (placed < 0) { placed = lanes.length; lanes.push(0); }
                    lanes[placed] = e.end;
                    e.lane = placed;
                }
                for (var m = i2; m < j; m++) { evs[m].lanes = lanes.length; out.push(evs[m]); }
                i2 = j;
            }
        }
        return out;
    }

    readonly property var laid: layout(week && week.timed ? week.timed : [])

    // All-day chips bucketed per column, so the band is a row of 7 stacks.
    readonly property var alldayByDay: {
        var out = [[], [], [], [], [], [], []];
        var src = (week && week.allday) ? week.allday : [];
        for (var i = 0; i < src.length; i++) {
            if (src[i].day >= 0 && src[i].day <= 6) out[src[i].day].push(src[i]);
        }
        return out;
    }
    readonly property int alldayRows: {
        var n = 0;
        for (var i = 0; i < alldayByDay.length; i++) n = Math.max(n, alldayByDay[i].length);
        return n;
    }

    function hourLabel(h) {
        var ampm = h < 12 ? "AM" : "PM";
        var hh = h % 12; if (hh === 0) hh = 12;
        return hh + " " + ampm;
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
                onVisibleChanged: if (visible) keys.forceActiveFocus();
                width: Math.round(win.width * 0.88)
                height: Math.round(win.height * 0.88)
                anchors.centerIn: parent
                color: Theme.base
                border.color: Theme.mauve
                border.width: 1
                radius: Theme.borderRadius

                MouseArea { anchors.fill: parent }   // swallow clicks so they don't close

                readonly property int gutterW: 62
                readonly property real colW: (width - 2 * border.width - gutterW) / 7

                FocusScope {
                    id: keys
                    anchors.fill: parent
                    focus: true
                    Keys.onPressed: function (e) {
                        if (e.key === Qt.Key_Escape) { root.hide(); e.accepted = true; }
                        else if (e.key === Qt.Key_Left || e.key === Qt.Key_H) { root.showWeek(root.offset - 1); e.accepted = true; }
                        else if (e.key === Qt.Key_Right || e.key === Qt.Key_L) { root.showWeek(root.offset + 1); e.accepted = true; }
                        else if (e.key === Qt.Key_T || e.key === Qt.Key_Home) { root.showWeek(0); e.accepted = true; }
                        else if (e.key === Qt.Key_R) { Quickshell.execDetached([root.script, "refresh"]); root.reload(); e.accepted = true; }
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: box.border.width
                        spacing: 0

                        // ── Header: nav, week label, today/refresh ───────────
                        Item {
                            id: header
                            width: parent.width
                            height: 48

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10

                                HeaderBtn { icon: "󰅁"; size: 18; anchors.verticalCenter: parent.verticalCenter
                                            onClicked: root.showWeek(root.offset - 1) }
                                HeaderBtn { icon: "󰅂"; size: 18; anchors.verticalCenter: parent.verticalCenter
                                            onClicked: root.showWeek(root.offset + 1) }
                                Txt {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.week.label || "…"
                                    font.pixelSize: 17
                                    color: Theme.text
                                }
                                Txt {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: root.offset !== 0
                                    text: root.offset > 0 ? "+" + root.offset + "w" : root.offset + "w"
                                    font.pixelSize: 12
                                    color: Theme.subtext0
                                }
                            }

                            Row {
                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 14

                                Txt {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "today"; font.pixelSize: 13
                                    color: todayMa.containsMouse ? Theme.text : Theme.subtext0
                                    MouseArea { id: todayMa; anchors.fill: parent; hoverEnabled: true
                                                onClicked: root.showWeek(0) }
                                }
                                HeaderBtn { icon: "󰑓"; size: 15; anchors.verticalCenter: parent.verticalCenter
                                            onClicked: { Quickshell.execDetached([root.script, "refresh"]); root.reload(); } }
                                HeaderBtn { icon: "󰅖"; size: 15; anchors.verticalCenter: parent.verticalCenter
                                            onClicked: root.hide() }
                            }

                            Rectangle { anchors.bottom: parent.bottom; width: parent.width
                                        height: 1; color: Theme.surface0 }
                        }

                        // ── Day header row ──────────────────────────────────
                        Item {
                            id: dayHeader
                            width: parent.width
                            height: 46

                            Repeater {
                                model: root.week.days || []
                                Item {
                                    required property var modelData
                                    required property int index
                                    x: box.gutterW + index * box.colW
                                    width: box.colW
                                    height: dayHeader.height

                                    Rectangle {
                                        visible: modelData.today
                                        anchors.fill: parent
                                        color: Qt.rgba(Theme.mauve.r, Theme.mauve.g, Theme.mauve.b, 0.10)
                                    }
                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 1
                                        Txt {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.dom
                                            font.pixelSize: 20
                                            color: modelData.today ? Theme.mauve : Theme.text
                                        }
                                        Txt {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.dow
                                            font.pixelSize: 11
                                            color: modelData.today ? Theme.mauve : Theme.subtext0
                                        }
                                    }
                                    Rectangle { anchors.left: parent.left; width: 1
                                                height: parent.height; color: Theme.surface0 }
                                }
                            }
                            Rectangle { anchors.bottom: parent.bottom; width: parent.width
                                        height: 1; color: Theme.surface0 }
                        }

                        // ── All-day band (Canvas assignments land here) ──────
                        Item {
                            id: alldayBand
                            width: parent.width
                            // Grows with content up to 4 rows, then scrolls.
                            height: root.alldayRows === 0 ? 0 : Math.min(root.alldayRows, 4) * 21 + 8
                            visible: root.alldayRows > 0
                            clip: true

                            Txt {
                                x: 8; y: 6
                                width: box.gutterW - 12
                                text: "all-day"; font.pixelSize: 10; color: Theme.subtext0
                                horizontalAlignment: Text.AlignRight
                            }

                            Flickable {
                                anchors.fill: parent
                                anchors.topMargin: 4
                                contentHeight: root.alldayRows * 21
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                Repeater {
                                    model: root.alldayByDay
                                    Column {
                                        id: dayStack
                                        required property var modelData
                                        required property int index
                                        x: box.gutterW + index * box.colW + 1
                                        width: box.colW - 2
                                        spacing: 1

                                        Repeater {
                                            // dayStack by id, not `parent` — the inner delegate
                                            // shadows modelData, so the implicit lookup is ambiguous.
                                            model: dayStack.modelData
                                            Rectangle {
                                                required property var modelData
                                                width: dayStack.width
                                                height: 20
                                                color: "transparent"
                                                Rectangle {
                                                    anchors.fill: parent
                                                    color: modelData.color
                                                    opacity: 0.20
                                                }
                                                Rectangle { width: 3; height: parent.height; color: modelData.color }
                                                Txt {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 7; anchors.rightMargin: 4
                                                    verticalAlignment: Text.AlignVCenter
                                                    text: modelData.summary
                                                    font.pixelSize: 10
                                                    color: Theme.text
                                                    elide: Text.ElideRight
                                                }
                                                HoverNote { detail: modelData.summary
                                                          sub: modelData.location }
                                            }
                                        }
                                    }
                                }
                            }
                            Rectangle { anchors.bottom: parent.bottom; width: parent.width
                                        height: 1; color: Theme.surface0 }
                        }

                        // ── Hour grid ───────────────────────────────────────
                        Flickable {
                            id: scroller
                            width: parent.width
                            height: parent.height - header.height - dayHeader.height - alldayBand.height
                            contentHeight: grid.height
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            // The grid is always the full 24h day, so every hour is
                            // reachable. Sizing it to the week's event range instead
                            // made contentHeight equal the viewport exactly — nothing
                            // to scroll, and anything outside 8am-8pm unreachable.
                            // ~12 hours visible at a time; the rest is a scroll away.
                            readonly property int span: 24
                            readonly property real hourH: Math.max(46, height / 12)

                            Item {
                                id: grid
                                width: scroller.width
                                height: scroller.span * scroller.hourH

                                readonly property real pxPerMin: scroller.hourH / 60

                                function yFor(min) { return min * pxPerMin; }   // minutes from midnight

                                // Hour rules + labels
                                Repeater {
                                    model: scroller.span + 1
                                    Item {
                                        required property int index
                                        y: index * scroller.hourH
                                        width: grid.width
                                        height: 1
                                        Rectangle { width: grid.width; height: 1; color: Theme.surface0 }
                                        Txt {
                                            x: 8; y: -6
                                            width: box.gutterW - 14
                                            text: root.hourLabel(index)
                                            font.pixelSize: 10
                                            color: Theme.subtext0
                                            horizontalAlignment: Text.AlignRight
                                            visible: index < scroller.span
                                        }
                                        // Half-hour rule, dimmer.
                                        Rectangle {
                                            x: box.gutterW
                                            y: scroller.hourH / 2
                                            width: grid.width - box.gutterW
                                            height: 1
                                            color: Qt.rgba(Theme.surface0.r, Theme.surface0.g, Theme.surface0.b, 0.45)
                                            visible: index < scroller.span
                                        }
                                    }
                                }

                                // Day column separators + weekend/today tint
                                Repeater {
                                    model: root.week.days || []
                                    Item {
                                        required property var modelData
                                        required property int index
                                        x: box.gutterW + index * box.colW
                                        width: box.colW
                                        height: grid.height
                                        Rectangle {
                                            visible: modelData.today
                                            anchors.fill: parent
                                            color: Qt.rgba(Theme.mauve.r, Theme.mauve.g, Theme.mauve.b, 0.05)
                                        }
                                        Rectangle { anchors.left: parent.left; width: 1
                                                    height: parent.height; color: Theme.surface0 }
                                    }
                                }

                                // Events
                                Repeater {
                                    model: root.laid
                                    Rectangle {
                                        id: ev
                                        required property var modelData
                                        readonly property real laneW: box.colW / modelData.lanes
                                        // JSON hands us "#89b4fa" as a string; assigning it to a
                                        // color-typed property is what makes .r/.g/.b exist.
                                        readonly property color accent: modelData.color

                                        x: box.gutterW + modelData.day * box.colW + modelData.lane * laneW + 1
                                        width: laneW - 2
                                        y: grid.yFor(modelData.start)
                                        height: Math.max(15, (modelData.end - modelData.start) * grid.pxPerMin - 1)

                                        color: Qt.rgba(ev.accent.r, ev.accent.g, ev.accent.b, 0.18)
                                        border.color: Qt.rgba(ev.accent.r, ev.accent.g, ev.accent.b, 0.45)
                                        border.width: 1
                                        radius: Theme.borderRadius

                                        Rectangle { width: 3; height: parent.height; color: modelData.color }

                                        Column {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8; anchors.rightMargin: 4
                                            anchors.topMargin: 3; anchors.bottomMargin: 2
                                            spacing: 1
                                            clip: true

                                            Txt {
                                                width: parent.width
                                                text: modelData.summary
                                                font.pixelSize: 11
                                                font.bold: true
                                                color: modelData.color
                                                elide: Text.ElideRight
                                                maximumLineCount: ev.height > 46 ? 2 : 1
                                                wrapMode: Text.WordWrap
                                            }
                                            Txt {
                                                width: parent.width
                                                visible: ev.height > 34
                                                text: modelData.time
                                                font.pixelSize: 10
                                                color: Theme.subtext0
                                                elide: Text.ElideRight
                                            }
                                            Txt {
                                                width: parent.width
                                                visible: ev.height > 60 && modelData.location !== ""
                                                text: "󰍎 " + modelData.location
                                                font.pixelSize: 10
                                                color: Theme.subtext0
                                                elide: Text.ElideRight
                                            }
                                        }

                                        HoverNote {
                                            detail: modelData.summary
                                            sub: modelData.time + (modelData.location ? "  ·  " + modelData.location : "")
                                        }
                                    }
                                }

                                // Now line — dim across the full week, solid on today.
                                Item {
                                    visible: root.week.now !== null && root.week.now !== undefined
                                    y: root.week.now ? grid.yFor(root.week.now.min) : 0
                                    width: grid.width
                                    height: 1
                                    z: 10

                                    Rectangle {
                                        x: box.gutterW
                                        width: grid.width - box.gutterW
                                        height: 1
                                        color: Qt.rgba(Theme.red.r, Theme.red.g, Theme.red.b, 0.25)
                                    }
                                    Rectangle {
                                        x: box.gutterW + (root.week.now ? root.week.now.day : 0) * box.colW
                                        width: box.colW
                                        height: 2
                                        y: -1
                                        color: Theme.red
                                    }
                                    Rectangle {
                                        x: box.gutterW + (root.week.now ? root.week.now.day : 0) * box.colW - 3
                                        y: -3
                                        width: 7; height: 7; radius: 4
                                        color: Theme.red
                                    }
                                }
                            }

                            // Open on the week's first event rather than at midnight,
                            // which would otherwise be eight empty hours of scrolling.
                            function scrollToFirst() {
                                var t = root.week.timed;
                                var first = root.minHour * 60;
                                if (t && t.length > 0) {
                                    first = t[0].start;
                                    for (var i = 1; i < t.length; i++) first = Math.min(first, t[i].start);
                                }
                                contentY = Math.max(0, Math.min(grid.yFor(first) - scroller.hourH * 0.5,
                                                                grid.height - height));
                            }
                            // Deferred: on the first load the Column has not finished
                            // sizing when the JSON lands, so an immediate contentY
                            // lands somewhere arbitrary.
                            Connections {
                                target: root
                                function onWeekChanged() { Qt.callLater(scroller.scrollToFirst); }
                            }
                            Connections {
                                target: box
                                function onVisibleChanged() {
                                    if (box.visible) Qt.callLater(scroller.scrollToFirst);
                                }
                            }
                        }
                    }
                }

                Txt {
                    anchors.centerIn: parent
                    visible: (root.week.timed || []).length === 0 && root.alldayRows === 0
                    text: root.week.label === "unavailable" ? "calendar unavailable" : "nothing scheduled this week"
                    color: Theme.subtext0
                    font.pixelSize: 14
                }
            }
        }
    }
}
