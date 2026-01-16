#!/bin/sh
# ~/.local/bin/kill-process

ps aux | tail -n +2 | \
    grep -v '^\s*root.*\[' | \
    grep -v 'kthread\|kworker\|ksoftirqd\|migration\|watchdog\|writeback\|kswapd\|kthrotld\|irq\|scsi\|xfsaild' | \
    awk '{printf "%-10s %-6s %s\n", $1, $2, $11}' | \
    rofi -dmenu -p "Kill process: " | \
    awk '{print $2}' | \
    xargs -r kill -9
