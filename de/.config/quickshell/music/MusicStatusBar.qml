pragma ComponentBehavior: Bound
import QtQuick
import ".."

// Queue status and in-place search; search keystrokes stay in the text field.
Rectangle {
    id: root
    required property MusicController controller
    height: Ui.s(34)
    color: Theme.crust

    Txt {
        visible: !root.controller.searching
        anchors.left: parent.left
        anchors.leftMargin: Ui.s(12)
        anchors.verticalCenter: parent.verticalCenter
        font.pixelSize: Ui.fs(12)
        color: Theme.subtext0
        text: {
            if (root.controller.tab !== 0) {
                var pane = root.controller.pane;
                return pane && pane.status !== undefined
                       ? pane.status : root.controller.tabs[root.controller.tab].name;
            }
            if (root.controller.query !== "") {
                var n = 0;
                for (var i = 0; i < root.controller.queue.length; i++) if (root.controller.matches(i)) n++;
                return "/" + root.controller.query + "   " + n + " match" + (n === 1 ? "" : "es")
                       + "   (n/N to step)";
            }
            if (root.controller.markedCount > 0) return root.controller.markedCount + " selected";
            var position = root.controller.queue.length > 0 ? root.controller.cursor + 1 : 0;
            return position + " / " + root.controller.queue.length;
        }
    }
    Item {
        anchors.left: parent.left
        anchors.leftMargin: Ui.s(12)
        anchors.right: parent.right
        anchors.rightMargin: Ui.s(12)
        anchors.verticalCenter: parent.verticalCenter
        height: Ui.s(18)
        visible: root.controller.searching

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: Ui.fs(12)
            color: Theme.mauve
            text: "/"
            id: slash
        }

        Field {
            id: searchField
            anchors.fill: parent
            anchors.leftMargin: Ui.s(12)
            font.pixelSize: Ui.fs(12)
            focus: root.controller.searching
            onTextChanged: root.controller.updateQuery(text)
            onVisibleChanged: if (visible) { text = ""; forceActiveFocus(); }
            Keys.onPressed: function (e) {
                if (e.key === Qt.Key_Escape
                    || (e.key === Qt.Key_C && (e.modifiers & Qt.ControlModifier))) {
                    root.controller.finishSearch(true);
                    e.accepted = true;
                } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                    root.controller.finishSearch(false);
                    e.accepted = true;
                }
            }

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                visible: searchField.text === ""
                color: Theme.surface1
                font.pixelSize: Ui.fs(12)
                text: "search the queue"
            }
        }
    }

    Txt {
        anchors.right: parent.right
        anchors.rightMargin: Ui.s(12)
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.controller.searching
        font.pixelSize: Ui.fs(11)
        color: Theme.surface1
        text: "~ help"
    }
}
