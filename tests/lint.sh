#!/bin/sh
# Static checks for the quickshell config: qmllint plus the conventions it
# can't see. Run by tests/run.sh before the unit tests; runnable on its own.
#
# qmllint is not usable as a pass/fail on its own here. It cannot load
# Quickshell's types (the plugin is linked into `qs`, see run.sh) or see the
# root singletons (no qmldir at the config root), so every run prints ~470
# [missing-property] and a few [unresolved-type]/[import] lines that are noise.
# Its exit status is therefore ignored and the output is filtered to the
# categories that are real in this tree:
#
#   syntax            — a file that doesn't parse fails the whole shell load
#   unqualified       — a name reached through scope instead of an id
#   property-override — a redeclared Item property (`enabled`, `baseline`, …)
#   unused-imports
#
# Two [unqualified] lines are false positives and are dropped by message:
# PanelWindow's `margins` group ("unknown grouped property scope margins"),
# which qmllint can't resolve without the Quickshell types.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
qs="$root/de/.config/quickshell"

lint=$(command -v qmllint 2>/dev/null || true)
if [ -z "$lint" ]; then
    for candidate in /usr/lib64/qt6/bin/qmllint /usr/lib/qt6/bin/qmllint; do
        [ -x "$candidate" ] && lint=$candidate && break
    done
fi
if [ -z "$lint" ]; then
    echo "lint.sh: no qmllint (dev-qt/qtdeclarative)" >&2
    exit 127
fi
qmlpath=$(dirname "$(dirname "$lint")")/qml

cd "$qs"
files=$(find . -name '*.qml' | sort)
status=0

# `|| true`: qmllint exits non-zero whenever it prints anything, noise included.
found=$("$lint" -I "$qmlpath" $files 2>&1 || true)
bad=$(printf '%s\n' "$found" \
    | grep -E '\[(syntax|unqualified|property-override|unused-imports)\]$' \
    | grep -v 'unknown grouped property scope margins' || true)
if [ -n "$bad" ]; then
    printf '%s\n' "$bad"
    status=1
fi

# Conventions qmllint has no check for.
for f in $files; do
    grep -q '^pragma ComponentBehavior: Bound$' "$f" \
        || { echo "$f: missing 'pragma ComponentBehavior: Bound'"; status=1; }
    # Inside an IpcHandler block (tracked by brace depth), a `show` function
    # is dead: the CLI parses `qs ipc call <t> show` as its own `qs ipc show`.
    awk '/IpcHandler[ \t]*\{/ { d = 1; next }
         d > 0 { if ($0 ~ /function[ \t]+show[ \t]*\(/) bad = 1
                 d += gsub(/\{/, "{") - gsub(/\}/, "}") }
         END { exit !bad }' "$f" \
        && { echo "$f: IpcHandler has show() — 'qs ipc call <t> show' never reaches it; use open()"; status=1; }
done

if [ $status -eq 0 ]; then
    echo "lint: $(printf '%s\n' "$files" | wc -l) files clean"
fi
exit $status
