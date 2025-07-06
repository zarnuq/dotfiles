#!/bin/sh
killall yambar

monitors=$(wlr-randr | grep "^[^ ]" | awk '{ print$1 }')
total=$(wlr-randr | grep "^[^ ]" | awk '{ print$1 }' | wc -l)

for monitor in ${monitors}; do
	riverctl focus-output ${monitor}
	yambar &
	sleep 0.2
done
exit 0
