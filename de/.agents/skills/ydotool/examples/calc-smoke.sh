#!/bin/sh
# Real-input smoke test for an open LibreOffice Calc window.
# Usage: UI_ORIGIN=x,y sh calc-smoke.sh   (x,y = window top-left on screen, see references/atspi.md)
set -eu
. "$(dirname "$0")/lib.sh"
calc() { ui --app soffice --window 'LibreOffice Calc' "$@"; }

case $(active_window) in *'LibreOffice Calc'*) ;; *) echo 'focus a Calc window first' >&2; exit 1 ;; esac

calc cell B2 --click          # locate by reference, click its center
text 7; key 28                # 7, Enter
text '=B2*6'; key 28          # formula in B3
expect B2 "$(calc cell B2 | sed -n "s/.* = '\(.*\)'.*/\1/p")" 7
expect B3 "$(calc cell B3 | sed -n "s/.* = '\(.*\)'.*/\1/p")" 42

key 29 44; key 29 44          # Ctrl+Z twice: leave the sheet as found
expect B2-undone "$(calc cell B2 | sed -n "s/.* = '\(.*\)'.*/\1/p")" ''
