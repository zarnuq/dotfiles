#!/bin/sh
# QML unit tests for the quickshell config: tests/quickshell/tst_*.qml.
#
#   tests/run.sh                 # tests/lint.sh, then every case
#   tests/run.sh -functions      # list the cases without running them
#   tests/run.sh MusicController # one TestCase by name
#
# Why the staging copy, rather than pointing qmltestrunner straight at
# tests/quickshell: the runner cannot load anything that imports Quickshell.
# /usr/lib64/qt6/qml/Quickshell/qmldir declares `optional plugin
# quickshell-coreplugin` with a `linktarget` — the plugin is linked INTO the
# `qs` binary and there is no .so for a plain Qt process to dlopen, so the
# import can only ever fail here.
#
# The units under test import nothing but QtQuick for exactly that reason, but
# that is not sufficient on its own: MusicController.qml lives in music/, and
# reading a file from a directory that has a qmldir registers the whole
# directory as a module — including its `singleton MpdClient`, whose `import
# Quickshell` then fails and takes the case down at initTestCase with
# "Type MpdClient unavailable". The file under test never mentions MpdClient;
# being filed next to it is enough.
#
# So each source a test names is copied into a staging tree at the same relative
# path, leaving every qmldir behind. Nothing is stubbed or rewritten — the files
# under test are byte-identical copies, and the tests run unmodified.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tests="$root/tests/quickshell"

# Gentoo installs it off PATH, under the Qt6 bindir.
runner=$(command -v qmltestrunner 2>/dev/null || true)
if [ -z "$runner" ]; then
    for candidate in /usr/lib64/qt6/bin/qmltestrunner /usr/lib/qt6/bin/qmltestrunner; do
        [ -x "$candidate" ] && runner=$candidate && break
    done
fi
if [ -z "$runner" ]; then
    echo "run.sh: no qmltestrunner (dev-qt/qtdeclarative)" >&2
    exit 127
fi

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT INT TERM

mkdir -p "$stage/tests/quickshell"
cp "$tests"/tst_*.qml "$stage/tests/quickshell/"

# The sources are whatever the tests reach for, so a new test naming a new file
# needs no edit here. Relative paths are kept as written, which is what lets the
# copies resolve each other exactly as they do in the repo.
for rel in $(sed -n 's|.*\(\.\./\.\./[A-Za-z0-9_./-]*\).*|\1|p' "$tests"/tst_*.qml | sort -u); do
    src="$tests/$rel"
    if [ ! -f "$src" ]; then
        echo "run.sh: test references a missing source: $rel" >&2
        exit 1
    fi
    dest="$stage/tests/quickshell/$rel"
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
done

# Lint first, but only on a full run: `run.sh MusicController` or `-functions`
# is someone iterating on one case, and a lint failure elsewhere is noise there.
status=0
if [ $# -eq 0 ]; then
    sh "$root/tests/lint.sh" || status=$?
fi

# offscreen: no compositor needed, so this runs over ssh and in a hook.
cd "$stage/tests/quickshell"
"$runner" -input . -platform offscreen "$@" || status=$?
exit $status
