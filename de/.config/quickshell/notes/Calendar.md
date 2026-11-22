# Calendar

`Calendar.qml` — ICS agenda list in the left bar (reads `calendar.url` via `calendar.sh events`, every 5 min). The refresh button runs `calendar.sh refresh` as a one-shot `Poll` and takes its output as the new list. Colour by day: today red → six days out mauve; an event already under way (negative `days_from_today`) wraps round the table, which is what the script's Python negative indexing used to do.
