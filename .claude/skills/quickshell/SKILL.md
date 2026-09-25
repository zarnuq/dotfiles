---
name: quickshell
description: Patterns and best practices for building Quickshell-based Wayland desktop shells with QML, covering architecture, services, components, config, state management, animations, and C++ plugin integration
---

## Project Structure

Quickshell projects follow a modular architecture:

```
shell.qml              # Entry point - extends ShellRoot
components/            # Reusable UI primitives
  controls/            # Interactive widgets (buttons, sliders, switches)
  containers/          # Layout containers (windows, list views)
  effects/             # Visual effects (elevation, shadows, masks)
modules/               # Feature modules
  bar/                 # Status bar
  drawers/             # Panel/orchestration system
  launcher/            # Application launcher
  dashboard/           # Top panel
  sidebar/             # Notification sidebar
  lock/                # Lock screen
  controlcenter/       # Settings UI
services/              # Singleton state managers
  Audio.qml
  Notifs.qml
  Network.qml
  Hypr.qml
  Colours.qml
  ...
config/                # Configuration system
  Config.qml
  AppearanceConfig.qml
  ...
utils/                 # Utility singletons
  Icons.qml
  Paths.qml
  Searcher.qml
plugin/                # C++ QML plugins
  src/Caelestia/
```

**Entry point pattern:**

```qml
// shell.qml
import Quickshell
import "modules"
import "modules/drawers"

ShellRoot {
    Background {}
    Drawers {}
    Lock {}
    Shortcuts {}
}
```

## QML Conventions

### Required Pragmas

```qml
pragma Singleton
pragma ComponentBehavior: Bound
```

### Naming Conventions

- **Files:** PascalCase matching component name (`StyledRect.qml`)
- **Singletons:** PascalCase accessed directly by name (`Hypr.qml`)
- **Root id:** Always `id: root`
- **Inline components:** `component Name: BaseType {}`
- **Imports:** Use `qs.` prefix for local modules (`qs.services`, `qs.config`)

### Type Annotations

```qml
readonly property real volume: sink?.audio?.volume ?? 0

function setVolume(newVolume: real): void {
    // implementation
}

signal valueChanged(newValue: real)
```

### Null Safety

```qml
// Optional chaining + nullish coalescing
sink?.audio?.volume ?? 0
monitor?.name ?? "Unknown"
```

## Service Architecture

### Singleton Service Pattern

```qml
// services/MyService.qml
pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell

Singleton {
    id: root

    // State properties
    readonly property real volume: sink?.audio?.volume ?? 0

    // IPC Handler for CLI access
    IpcHandler {
        target: "myService"
        function getVolume(): real { return root.volume }
        function setVolume(value: real): void { ... }
    }

    // Global keyboard shortcut
    CustomShortcut {
        name: "volumeUp"
        description: "Increase volume"
        onPressed: root.incrementVolume()
    }

    // Hot-reload safe persistent state
    PersistentProperties {
        id: props
        property bool enabled: true
        reloadableId: "myService"
    }
}
```

### Communication Patterns

**Hyprland Socket IPC:**

```qml
// Use Hyprland singleton
Quickshell.Hyprland {
    id: hypr
}

Connections {
    target: hypr
    function onRawEvent(event: string): void {
        // Handle events
    }
}
```

**PipeWire Audio:**

```qml
import Quickshell.Services.Pipewire as Pw

Pw.Pipewire {
    id: pipewire
}

Connections {
    target: pipewire.defaultAudioSink
    function onAudioChanged(): void {
        // React to volume changes
    }
}
```

**D-Bus (Notifications):**

```qml
import Quickshell.Services.Notifications as Notifs

Notifs.NotificationServer {
    onNotification: (notification) => {
        // Handle notification
    }
}
```

**Subprocess Execution:**

```qml
import Quickshell.Io

Process {
    id: process
    command: ["brightnessctl", "g"]

    stdout: StdioCollector {
        onStreamFinished: {
            const output = text.trim()
            // Process output
        }
    }
}
```

**File Watching:**

```qml
import Quickshell.Io

FileView {
    path: Paths.config + "/settings.json"
    watchChanges: true
    onLoaded: (data) => {
        // React to file changes
    }
}
```

**HTTP Requests (from C++ plugin):**

```qml
import Caelestia

Requests.get(url, (response) => {
    // Handle response
})
```

## Component Design System

### Animation Primitives

```qml
// Anim.qml - NumberAnimation with M3 curves
NumberAnimation {
    duration: Appearance.anim.durations.normal
    easing.bezierCurve: Appearance.anim.curves.standard
}

// CAnim.qml - ColorAnimation variant
ColorAnimation {
    duration: Appearance.anim.durations.normal
    easing.bezierCurve: Appearance.anim.curves.standard
}
```

### Styled Base Components

```qml
// StyledRect.qml
Rectangle {
    color: "transparent"
    Behavior on color { CAnim {} }
}

// StyledText.qml
Text {
    renderType: Text.NativeRendering
    color: Colours.palette.m3onSurface
    font.family: Appearance.font.family.normal
    font.pixelSize: Appearance.font.size.normal
    Behavior on color { CAnim {} }
}
```

### StateLayer (Material Ripple)

```qml
// components/StateLayer.qml
MouseArea {
    id: root
    anchors.fill: parent
    hoverEnabled: true

    property color colour: Colours.tPalette.m3onSurface

    StyledClippingRect {
        id: layer
        anchors.fill: parent
        radius: parent.radius
        opacity: root.pressed ? 0.12 : root.containsMouse ? 0.08 : 0
        color: root.colour
        Behavior on opacity { Anim {} }
    }

    function onClicked(): void {} // Override point
    onClicked: onClicked()
}
```

### Material Icon

```qml
// components/MaterialIcon.qml
StyledText {
    id: root
    property string icon: "settings"
    property int fill: 0
    property int grade: 0
    property int opticalSize: 24

    text: root.icon
    font.family: "Material Symbols Rounded"
    font.variableAxes: ({
        "FILL": root.fill,
        "GRAD": root.grade,
        "opsz": root.opticalSize
    })
}
```

### StyledWindow (Wayland Layer Shell)

```qml
// components/containers/StyledWindow.qml
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    required property string name

    namespace: `caelestia-${root.name}`
    layer: Layer.Top

    margin {
        top: Config.bar.persistent ? Appearance.padding.normal : 0
    }

    ExclusionMode {
        id: exclusionMode
    }
}
```

## Module Patterns

### Wrapper/Content/Background Triad

```qml
// modules/sidebar/Wrapper.qml
StyledRect {
    id: root
    required property PersistentProperties visibilities

    implicitWidth: 0

    states: State {
        name: "visible"
        when: root.visibilities.sidebar && Config.sidebar.enabled
        PropertyChanges { root.implicitWidth: Config.sidebar.width }
    }

    transitions: [
        Transition {
            from: ""; to: "visible"
            Anim { property: "implicitWidth" }
        },
        Transition {
            from: "visible"; to: ""
            Anim { property: "implicitWidth" }
        }
    ]

    // Lazy-loaded content
    Loader {
        id: content
        active: false
        Component.onCompleted: active = Qt.binding(() =>
            root.visibilities.sidebar || root.state === "visible")
        sourceComponent: Content { visibilities: root.visibilities }
    }
}

// modules/sidebar/Content.qml
ColumnLayout {
    required property PersistentProperties visibilities

    // Actual UI content
}

// modules/sidebar/Background.qml
ShapePath {
    // Background shape definition
}
```

### Per-Screen Instantiation

```qml
// Create instances for each screen
Variants {
    model: Quickshell.screens
    Scope {
        required property ShellScreen modelData

        StyledWindow {
            screen: modelData
            // Window content
        }

        PersistentProperties {
            id: visibilities
            property bool bar: false
            property bool sidebar: false
            Component.onCompleted: Visibilities.load(modelData, visibilities)
        }
    }
}
```

### Lazy Loading

```qml
// Conditional Loader activation
Loader {
    id: content
    active: false
    Component.onCompleted: {
        active = Qt.binding(() => root.visible || root.animating)
    }
    sourceComponent: Content {}
}

// Timer-delayed initialization
Timer {
    running: true
    interval: Appearance.anim.durations.extraLarge
    onTriggered: {
        content.active = Qt.binding(() => shouldLoad())
    }
}

// LazyLoader for dialogs
LazyLoader {
    function open(): void { activeAsync = true; }
    function close(): void { rejected(); }

    FloatingWindow {
        // Dialog content
    }
}
```

## Animation System

### Implicit Behavior Animations

```qml
Rectangle {
    id: root
    color: Colours.palette.m3surface
    radius: Appearance.rounding.normal

    Behavior on color { CAnim {} }
    Behavior on radius { Anim {} }
    Behavior on implicitWidth {
        Anim { duration: Appearance.anim.durations.large }
    }
    Behavior on opacity { Anim {} }
}
```

### Material Design 3 Curves

```qml
// Standard - for property changes
easing.bezierCurve: [0.2, 0, 0, 1]  // standard

// Emphasized - for exit/close animations
easing.bezierCurve: [0.2, 0, 0, 1]  // emphasized

// Expressive Spatial - for enter/open animations
easing.bezierCurve: [0.05, 0.7, 0.1, 1]  // expressiveDefaultSpatial
```

### Enter vs Exit Curves

```qml
transitions: [
    // Opening: Use expressive spatial for lively entrance
    Transition {
        from: ""; to: "visible"
        Anim {
            property: "implicitWidth"
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
    },
    // Closing: Use emphasized for graceful exit
    Transition {
        from: "visible"; to: ""
        Anim {
            property: "implicitWidth"
            easing.bezierCurve: Appearance.anim.curves.emphasized
        }
    }
]
```

### States/Transitions for Panels

```qml
Item {
    id: root
    implicitHeight: 0

    states: State {
        name: "visible"
        when: shouldShow
        PropertyChanges { root.implicitHeight: contentHeight }
    }

    transitions: [
        Transition {
            from: ""; to: "visible"
            Anim { property: "implicitHeight" }
        },
        Transition {
            from: "visible"; to: ""
            Anim { property: "implicitHeight" }
        }
    ]
}
```

### Sequential Animations

```qml
SequentialAnimation {
    id: expandAnim
    PropertyAction { target: root; property: "animating"; value: true }
    Anim { property: "implicitHeight"; to: targetHeight }
    ScriptAction {
        script: root.implicitHeight = Qt.binding(() => content.implicitHeight)
    }
    PropertyAction { target: root; property: "animating"; value: false }
}
```

### List Item Remove Animation

```qml
ListView {
    delegate: Item {
        ListView.onRemove: removeAnim.start()

        SequentialAnimation {
            id: removeAnim
            PropertyAction { property: "ListView.delayRemove"; value: true }
            Anim { property: "x"; to: width * 2 }
            PropertyAction { property: "ListView.delayRemove"; value: false }
        }
    }
}
```

## Configuration System

### JsonAdapter + JsonObject

```qml
// config/Config.qml
pragma Singleton
import Quickshell.Io

Singleton {
    id: root

    FileView {
        id: fileView
        path: Paths.config + "/shell.json"
        watchChanges: true
        onLoaded: (data) => {
            adapter.json = data
            Toaster.toast("Config loaded", "", "settings", "success")
        }
    }

    JsonAdapter {
        id: adapter
        property AppearanceConfig appearance: AppearanceConfig {}
        property GeneralConfig general: GeneralConfig {}
        property BarConfig bar: BarConfig {}
        // ... more sections
    }

    function save(): void {
        saveTimer.restart()
    }

    Timer {
        id: saveTimer
        interval: 500  // Debounce
        onTriggered: {
            const config = {
                appearance: adapter.appearance.serialize(),
                general: adapter.general.serialize(),
                bar: adapter.bar.serialize()
            }
            fileView.setText(JSON.stringify(config, null, 2))
        }
    }
}

// config/AppearanceConfig.qml
JsonObject {
    property Rounding rounding: Rounding {}
    property Spacing spacing: Spacing {}

    component Rounding: JsonObject {
        property real scale: 1
        property int small: 8 * scale
        property int normal: 12 * scale
        property int large: 16 * scale

        function serialize(): object {
            return { scale, small, normal, large }
        }
    }

    component Spacing: JsonObject {
        property real scale: 1
        property int smaller: 4 * scale
        property int small: 8 * scale
        property int normal: 16 * scale
        property int large: 24 * scale
    }

    function serialize(): object {
        return {
            rounding: rounding.serialize(),
            spacing: spacing.serialize()
        }
    }
}
```

### Convenience Alias

```qml
// config/Appearance.qml
pragma Singleton
import Quickshell

Singleton {
    // Shortens Config.appearance.* to Appearance.*
    property Rounding rounding: Config.appearance.rounding
    property Spacing spacing: Config.appearance.spacing
    property FontConfig font: Config.appearance.font
    property AnimConfig anim: Config.appearance.anim
    property real transparency: Config.appearance.transparency
}
```

### Scale-Based Design Tokens

```qml
JsonObject {
    property real scale: 1

    // Computed from scale
    property int small: 12 * scale
    property int normal: 17 * scale
    property int large: 22 * scale

    // Changing scale automatically updates all derived values
}
```

## State Management

### PersistentProperties

```qml
// State survives hot reload
PersistentProperties {
    id: props
    reloadableId: "uniqueId"  // Must be unique
    property bool enabled: true
    property int count: 0
    property string lastAction: ""
}
```

### Per-Screen State

```qml
// services/Visibilities.qml
pragma Singleton

Singleton {
    id: root
    property var screens: new Map()

    function load(screen, visibilities): void {
        screens.set(Hypr.monitorFor(screen), visibilities)
    }

    function getForActive(): PersistentProperties {
        return screens.get(Hypr.focusedMonitor)
    }
}
```

### File Persistence

```qml
// Notifications persistence
Timer {
    id: saveTimer
    interval: 1000  // 1 second debounce
    onTriggered: {
        const data = list.map(n => n.serialize())
        fileView.setText(JSON.stringify(data, null, 2))
    }
}

// Update timer when list changes
onListChanged: saveTimer.restart()
```

### Reference Counting

```qml
// services/SystemUsage.qml
Singleton {
    id: root
    property int refCount: 0

    // Only poll when someone needs data
    Timer {
        running: root.refCount > 0
        interval: 3000
        onTriggered: updateStats()
    }
}

// Component that needs stats
Ref { service: SystemUsage }  // Increments refCount
```

## C++ Plugin Integration

### Plugin Structure

```cmake
# CMakeLists.txt
qt_add_qml_module(myplugin
    URI Caelestia
    VERSION 1.0
    SOURCES
        src/utils.cpp
        src/requests.cpp
    QML_FILES
        MyComponent.qml
)
```

### QML Singleton

```cpp
// src/utils.h
class CUtils : public QObject {
    Q_OBJECT
    QML_SINGLETON

public:
    Q_INVOKABLE void saveItem(QQuickItem* item, const QString& path);
    Q_INVOKABLE QString readFile(const QString& path);
};
```

### QML Element

```cpp
// src/appdb.h
class AppDb : public QObject {
    Q_OBJECT
    QML_ELEMENT

public:
    Q_INVOKABLE void recordLaunch(const QString& appId);
    Q_INVOKABLE QList<AppEntry> getRecent(int limit);
};
```

### When to Use C++

| Use C++                                 | Use QML               |
| --------------------------------------- | --------------------- |
| Audio processing (CAVA, beat detection) | UI components         |
| SQLite database access                  | State management      |
| HTTP requests                           | Service orchestration |
| Image analysis (dominant color)         | Animations            |
| Performance-critical operations         | Business logic        |

## Common Idioms

### Debounce/Throttle

```qml
// Debounce config saves
Timer {
    id: saveTimer
    interval: 500
    onTriggered: saveConfig()
}

onConfigChanged: saveTimer.restart()  // Restart cancels previous

// Rate limit DDC brightness writes
Timer {
    id: ddcTimer
    interval: 500
    onTriggered: writeBrightness()
}
```

### Toast Notifications

```qml
import Caelestia

Toaster.toast(
    "Volume Changed",           // Title
    "Volume set to 50%",        // Message
    "volume_up",                // Icon
    "info"                      // Type: info/success/warning/error
)

// Guarded by config
if (Config.utilities.toasts.volume) {
    Toaster.toast(...)
}
```

### Default Property Alias (Slots)

```qml
// components/Card.qml
StyledRect {
    default property alias content: contentColumn.data

    ColumnLayout {
        id: contentColumn
        // Children added here via default property
    }
}

// Usage
Card {
    StyledText { text: "Title" }
    StyledText { text: "Content" }
}
```

### Inline Components

```qml
// Define types inline
component ItemData: QtObject {
    required property string name
    required property int value
    property bool active: true
}

ListModel {
    ListElement {
        item: ItemData { name: "A"; value: 1 }
    }
}
```

### i18n

```qml
StyledText {
    text: qsTr("Hello, World!")
}

StyledText {
    text: qsTr("Volume: %1%").arg(Math.round(volume * 100))
}
```

### XDG Paths

```qml
// utils/Paths.qml
pragma Singleton

Singleton {
    readonly property string home: Qt.platform.os === "linux"
        ? Qt.environment.HOME
        : Qt.environment.USERPROFILE

    readonly property string data: Qt.environment.XDG_DATA_HOME
        ?? `${home}/.local/share`

    readonly property string config: Qt.environment.XDG_CONFIG_HOME
        ?? `${home}/.config`

    readonly property string cache: Qt.environment.XDG_CACHE_HOME
        ?? `${home}/.cache`

    readonly property string state: Qt.environment.XDG_STATE_HOME
        ?? `${home}/.local/state`

    function absolutePath(path: string): string {
        if (path.startsWith("~/")) return home + path.slice(1)
        if (path.startsWith("$HOME/")) return home + path.slice(5)
        return path
    }
}
```

## Anti-Patterns to Avoid

❌ **Don't hardcode colors/sizes**

```qml
// BAD
color: "#1a1a1a"
font.pixelSize: 16

// GOOD
color: Colours.palette.m3surface
font.pixelSize: Appearance.font.size.normal
```

❌ **Don't create multiple FileView for same file**

```qml
// BAD - Each FileView watches separately
FileView { path: "/proc/stat" }
FileView { path: "/proc/stat" }

// GOOD - Centralize in service
// services/SystemUsage.qml has single FileView
```

❌ **Don't poll when not needed**

```qml
// BAD - Always polling
Timer { running: true; interval: 1000 }

// GOOD - Only when visible/needed
Timer { running: refCount > 0 }
```

❌ **Don't forget persistent IDs**

```qml
// BAD - State lost on reload
PersistentProperties { property bool enabled }

// GOOD - State survives reload
PersistentProperties {
    reloadableId: "featureName"
    property bool enabled
}
```

## Debugging & Diagnostics

### LSP Diagnostics

Check QML files for errors using the OpenCode LSP diagnostics command:

```bash
opencode debug lsp diagnostics <file.qml>
```

Use this after editing QML files to catch type errors, missing imports, unresolved
properties, and other issues before reloading the shell. `<file.qml>` must be an absolute
path.

### QML Language Server (qmlls) Caveats

The QML language server has known limitations to be aware of:

- **Broken when file is malformed:** qmlls does not work well when a file is not
  correctly structured. Completions and lints won't work unless braces are closed
  correctly and the file is syntactically valid.
- **No Quickshell type docs:** The LSP cannot provide any documentation for
  Quickshell-specific types.
- **`PanelWindow` unresolved:** `PanelWindow` in particular cannot be resolved by
  qmlls, so diagnostics referencing it may be false positives.

To enable qmlls support, create an empty `.qmlls.ini` file next to `shell.qml`.
Quickshell will replace it with a managed configuration. This file should be
gitignored as its content is machine-specific.

Keep these caveats in mind when interpreting diagnostics -- some errors (especially
around Quickshell-specific types like `PanelWindow`, `ShellRoot`, `Singleton`,
`Variants`, etc.) may be false positives from the language server rather than
actual bugs.

## Resources

- [Quickshell Documentation](https://quickshell.org)
- [Material Design 3](https://m3.material.io)
- [QML Best Practices](https://doc.qt.io/qt-6/qml-coding-conventions.html)
