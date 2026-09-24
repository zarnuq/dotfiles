import QtQuick
import QtTest

TestCase {
    id: testCase
    name: "MusicController"

    property var controller
    property var fakeClient
    property var controllerComponent

    Component {
        id: clientComponent
        QtObject {
            property var queue: []
            property int songPos: -1
            property bool connected: false
            property var calls: []
            function record(name, args) { calls = calls.concat([{ name: name, args: args || [] }]); }
            // The controller calls this from announceAdded(); without it the
            // banner path throws a TypeError that the suite swallows.
            function songTitle(song) { return song ? (song.Title || song.file || "") : ""; }
            // Added alongside queueWasBulk, which announceAdded() consults.
            property bool queueWasBulk: false
            function toggle() { record("toggle"); }
            function stop() { record("stop"); }
            function next() { record("next"); }
            function previous() { record("previous"); }
            function changeVolume(delta) { record("changeVolume", [delta]); }
            function seekBy(delta) { record("seekBy", [delta]); }
            function toggleRepeat() { record("toggleRepeat"); }
            function toggleRandom() { record("toggleRandom"); }
            function toggleConsume() { record("toggleConsume"); }
            function toggleSingle() { record("toggleSingle"); }
            function clearQueue() { record("clearQueue"); }
            function playId(id) { record("playId", [id]); }
            function sendList(commands) { record("sendList", commands); }
            function moveSong(from, to) { record("moveSong", [from, to]); }
            function refreshQueue() { record("refreshQueue"); }
        }
    }

    SignalSpy { id: revealSpy; signalName: "revealRequested" }
    SignalSpy { id: closeSpy; signalName: "closeRequested" }
    SignalSpy { id: resetSpy; signalName: "resetRequested" }

    function songs(ids) {
        return ids.map(function (id, index) {
            return { Id: String(id), Pos: String(index), Title: "Song " + id,
                     file: "dir/" + id + ".flac",
                     Artist: "Artist " + (index % 2), Album: "Album" };
        });
    }

    function initTestCase() {
        controllerComponent = Qt.createComponent("../../de/.config/quickshell/music/MusicController.qml");
        compare(controllerComponent.status, Component.Ready, controllerComponent.errorString());
    }

    function init() {
        fakeClient = createTemporaryObject(clientComponent, testCase, { queue: songs([10, 20, 30, 40]) });
        controller = createTemporaryObject(controllerComponent, testCase, { client: fakeClient });
        verify(controller !== null);
        revealSpy.target = controller;
        closeSpy.target = controller;
        resetSpy.target = controller;
        revealSpy.clear();
        closeSpy.clear();
        resetSpy.clear();
    }

    function press(key, modifiers) {
        var event = { key: key, modifiers: modifiers || Qt.NoModifier, accepted: false };
        controller.handleKey(event);
        return event.accepted;
    }

    function test_initialQueueAndIncrementalModel() {
        compare(controller.rowModel.count, 4);
        for (var i = 0; i < 4; i++) controller.rowModel.setProperty(i, "n", i + 1);
        fakeClient.queue = songs([10, 20, 30, 40, 50]);
        compare(controller.rowModel.count, 5);
        compare(controller.rowModel.get(3).n, 4);
        compare(controller.rowModel.get(4).n, 0);
        fakeClient.queue = songs([10, 30, 40, 50]);
        compare(controller.rowModel.count, 4);
        compare(controller.rowModel.get(0).n, 1);
        compare(controller.rowModel.get(1).n, 3);
        compare(controller.rowModel.get(2).n, 4);
        fakeClient.queue = songs([10, 40, 30, 50]);
        compare(controller.rowModel.count, 4);
        compare(controller.rowModel.get(0).n, 1);
        compare(controller.current.Id, "10");
        controller.moveTo(2);
        compare(controller.current.Id, "30");
        fakeClient.queue = [];
        compare(controller.rowModel.count, 0);
        compare(controller.cursor, 0);
        compare(controller.current, null);
    }

    // C-a hands the picker URIs, and the marked rows win over the cursor the
    // same way deleting does. The picker is a `modal`, not an `overlay`: it
    // routes its own keys, where an overlay is a scrim any key dismisses.
    function test_playlistPickerTakesTheQueueSelection() {
        controller.moveTo(1);
        verify(press(Qt.Key_A, Qt.ControlModifier));
        compare(controller.modal, "playlist");
        compare(controller.modalArg, ["dir/20.flac"]);

        controller.closeModal();
        controller.toggleMark();          // marks row 1, steps to 2
        controller.toggleMark();
        press(Qt.Key_A, Qt.ControlModifier);
        compare(controller.modalArg, ["dir/20.flac", "dir/30.flac"]);

        // Closing clears the arg with the modal, or it outlives the picker that
        // was handed it.
        controller.closeModal();
        compare(controller.modalArg, []);

        // An empty queue has nothing to offer, and must not raise the picker.
        controller.clearMarks();
        fakeClient.queue = [];
        press(Qt.Key_A, Qt.ControlModifier);
        compare(controller.modal, "");
        compare(controller.notice, "Nothing selected");
    }

    // While the picker is up it owns the keyboard: a key must not fall through
    // to the globals, nor dismiss it the way the info overlay is dismissed.
    // Unaccepted is the point — the event is left for the picker's own focus
    // scope to take, rather than being swallowed here.
    function test_playlistModalKeepsItsKeys() {
        controller.openModal("playlist", []);
        compare(press(Qt.Key_P), false);
        compare(controller.modal, "playlist");
        compare(fakeClient.calls.length, 0);

        // An overlay is the other half of the contract: any key dismisses it,
        // and that key is consumed rather than reaching the globals.
        controller.closeModal();
        controller.overlay = "info";
        compare(press(Qt.Key_P), true);
        compare(controller.overlay, "");
        compare(fakeClient.calls.length, 0);
    }

    function test_marksFollowIdsAndDeleteAsOneBatch() {
        controller.toggleMark();
        controller.moveTo(2);
        controller.toggleMark();
        compare(controller.markedCount, 2);
        fakeClient.queue = songs([30, 20, 10, 40]);
        verify(controller.isMarked(fakeClient.queue[0]));
        verify(controller.isMarked(fakeClient.queue[2]));
        controller.deleteSelected();
        compare(fakeClient.calls, [{ name: "sendList", args: ["deleteid 30", "deleteid 10"] }]);
        compare(controller.markedCount, 0);
    }

    function test_removedMarksDoNotBlockCursorActions() {
        controller.toggleMark();
        fakeClient.queue = songs([20, 30, 40]);
        compare(controller.markedCount, 0);
        compare(controller.targets()[0].Id, "30");
        controller.moveSelected(1);
        compare(fakeClient.calls, [{ name: "moveSong", args: [1, 2] }]);
        controller.deleteSelected();
        compare(fakeClient.calls[1], { name: "sendList", args: ["deleteid 40"] });
    }

    function test_navigationAndModifierPriority() {
        controller.viewportRows = 4;
        verify(press(Qt.Key_D, Qt.ControlModifier));
        compare(controller.cursor, 2);
        compare(fakeClient.calls.length, 0);
        press(Qt.Key_U, Qt.ControlModifier);
        compare(controller.cursor, 0);
        press(Qt.Key_Space);
        compare(controller.cursor, 1);
        compare(controller.markedCount, 1);
        press(Qt.Key_Space, Qt.ControlModifier);
        compare(controller.cursor, 1);
        compare(controller.markedCount, 3);
        press(Qt.Key_D, Qt.ControlModifier | Qt.ShiftModifier);
        compare(fakeClient.calls, [{ name: "clearQueue", args: [] }]);
        compare(controller.markedCount, 0);
        press(Qt.Key_C, Qt.ShiftModifier);
        compare(fakeClient.calls[1].name, "toggleConsume");
        press(Qt.Key_J, Qt.ShiftModifier);
        compare(fakeClient.calls[2], { name: "moveSong", args: [1, 2] });
        compare(controller.cursor, 2);
        press(Qt.Key_G, Qt.ShiftModifier);
        compare(controller.cursor, 3);
        press(Qt.Key_G);
        compare(controller.cursor, 0);
        press(Qt.Key_Return);
        compare(fakeClient.calls[3], { name: "playId", args: ["10"] });
    }

    function test_arrowsControlTransport() {
        controller.cursor = 2;
        press(Qt.Key_Up);
        press(Qt.Key_Down);
        press(Qt.Key_Left);
        press(Qt.Key_Right);
        compare(controller.cursor, 2);
        compare(fakeClient.calls, [
            { name: "changeVolume", args: [5] }, { name: "changeVolume", args: [-5] },
            { name: "seekBy", args: [-5] }, { name: "seekBy", args: [5] }
        ]);
    }

    function test_otherTabsDoNotEditHiddenQueue() {
        controller.setTab(1);
        verify(!press(Qt.Key_D));
        verify(!press(Qt.Key_D, Qt.ShiftModifier));
        verify(!press(Qt.Key_J, Qt.ShiftModifier));
        verify(!press(Qt.Key_Return));
        verify(!press(Qt.Key_Space));
        compare(fakeClient.calls, []);
        compare(controller.cursor, 0);
        compare(controller.markedCount, 0);
        verify(press(Qt.Key_P));
        compare(fakeClient.calls[0].name, "toggle");
        press(Qt.Key_5);
        compare(controller.tab, 4);
        press(Qt.Key_Tab);
        compare(controller.tab, 0);
        press(Qt.Key_Backtab);
        compare(controller.tab, 4);
    }

    function test_searchWrapAndDismissal() {
        press(Qt.Key_Slash);
        verify(controller.searching);
        controller.cursor = 1;
        controller.updateQuery("ARTIST 0");
        compare(controller.cursor, 2);
        controller.finishSearch(false);
        verify(!controller.searching);
        compare(controller.query, "ARTIST 0");
        press(Qt.Key_N);
        compare(controller.cursor, 0);
        press(Qt.Key_N, Qt.ShiftModifier);
        compare(controller.cursor, 2);
        press(Qt.Key_Slash);
        compare(controller.query, "");
        controller.updateQuery("Song 40");
        compare(controller.cursor, 3);
        verify(!press(Qt.Key_D));
        compare(fakeClient.calls.length, 0);
        controller.finishSearch(true);
        compare(controller.query, "");
        verify(!controller.searching);
        compare(closeSpy.count, 0);
    }

    function test_overlayDismissalConsumesTheKey() {
        press(Qt.Key_QuoteLeft);
        compare(controller.overlay, "help");
        press(Qt.Key_D);
        compare(controller.overlay, "");
        compare(fakeClient.calls.length, 0);
        press(Qt.Key_I);
        compare(controller.overlay, "info");
        press(Qt.Key_Escape);
        compare(closeSpy.count, 0);
        press(Qt.Key_Escape);
        compare(closeSpy.count, 1);
    }

    function test_lateSongStatusCompletesInitialJumpOnce() {
        fakeClient.queue = [];
        fakeClient.connected = true;
        controller.reset();
        compare(resetSpy.count, 1);
        // reset() no longer refetches: MpdClient.retainQueue() owns the initial
        // load, so the window's Loader triggers it rather than the controller.
        compare(fakeClient.calls, []);
        fakeClient.queue = songs([10, 20, 30, 40]);
        compare(controller.cursor, 0);
        compare(revealSpy.count, 0);
        fakeClient.songPos = 2;
        compare(controller.cursor, 2);
        compare(revealSpy.count, 1);
        controller.moveTo(0);
        fakeClient.songPos = 3;
        fakeClient.queue = songs([10, 20, 30, 40, 50]);
        compare(controller.cursor, 0);
        compare(revealSpy.count, 1);
    }

    function test_songStatusBeforeQueueWaitsForItsRow() {
        fakeClient.queue = [];
        controller.reset();
        fakeClient.songPos = 3;
        fakeClient.queue = songs([10, 20]);
        compare(revealSpy.count, 0);
        fakeClient.queue = songs([10, 20, 30, 40]);
        compare(controller.cursor, 3);
        compare(revealSpy.count, 1);
    }
}
