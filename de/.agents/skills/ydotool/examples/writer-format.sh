#!/bin/sh
# Real-input formatting test for an open LibreOffice Writer window.
# Usage: UI_ORIGIN=x,y sh writer-format.sh
set -eu
. "$(dirname "$0")/lib.sh"
writer() { ui --app soffice --window 'LibreOffice Writer' "$@"; }

case $(active_window) in *'LibreOffice Writer'*) ;; *) echo 'focus a Writer window first' >&2; exit 1 ;; esac

writer click 'LibreOffice Document' --role 'document text'
key 29 107                    # Ctrl+End: caret to document end
key 28                        # Enter: new paragraph
text 'plain then emphasis'
key 29 42 105                 # Ctrl+Shift+Left: select previous word
key 29 48                     # Ctrl+B
key 107                       # End: drop the selection

# Assert on formatting runs, not pixels. AutoCorrect may change typed text, so check it too.
writer text 'LibreOffice Document' --role 'document text' --attrs weight | tail -2 > /tmp/writer-runs.$$
expect plain-run "$(sed -n 1p /tmp/writer-runs.$$)" "'plain then ' {'weight': '400'}"
expect bold-run "$(sed -n 2p /tmp/writer-runs.$$)" "'emphasis' {'weight': '600'}"
rm -f /tmp/writer-runs.$$
