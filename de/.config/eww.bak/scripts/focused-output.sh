#!/usr/bin/env bash

# Print initial state
swaymsg -t get_outputs \
  | jq -r '.[] | select(.focused).name'

# Subscribe to changes
swaymsg -t subscribe '["output"]' | while read -r _; do
  swaymsg -t get_outputs \
    | jq -r '.[] | select(.focused).name'
done

