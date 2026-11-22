# Tests

Loaded when working in this directory. Moved out of the root `CLAUDE.md`, which keeps only an index.

`tests/run.sh` runs `tests/lint.sh` and then the QML unit tests (`tests/quickshell/tst_*.qml`: `FileSearch`, `MusicController`, `Ansi`) under `qmltestrunner`, which Gentoo installs **off PATH** at `/usr/lib64/qt6/bin/`. A TestCase name or flag (`tests/run.sh MusicController`, `-functions`) skips the lint. Units must import only QtQuick — Quickshell's plugin is linked into `qs` and can't be loaded — and the runner stages copies so a sibling `qmldir` doesn't drag Quickshell in; each script's header explains the details. `lint.sh` fails on qmllint's `syntax`/`unqualified`/`property-override`/`unused-imports`, a missing `ComponentBehavior: Bound`, or an `IpcHandler` exposing `show()` or taking an untyped argument; its other ~470 warnings are noise it filters out.
