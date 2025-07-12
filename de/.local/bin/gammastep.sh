#!/bin/bash
if pgrep -x "gammastep"; then
    pkill gammastep
else
    gammastep -O 4000:4000 &
fi

