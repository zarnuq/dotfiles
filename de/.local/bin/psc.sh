#!/bin/sh
trap 'exit 0' INT TERM

while true; do
  pscircle \
    --tree-radius-increment=195 \
    --output=/tmp/pscircle.png \
    --output-width=3000 \
    --output-height=2000 \
    --background-color="1e1e2eff" \
    --dot-color-min="cba6f7ff" \
    --dot-color-max="F38BA8FF" \
    --link-color-min="b4befe66" \
    --link-color-max="f38ba8ff" \
    --tree-font-color="cdd6f4ff" \
    --toplists-font-color="CDD6F4FF" \
    --hide-top-levels=0 \
    --toplists-pid-font-color="9399B2FF"

  count=$(ps -C swaybg --no-headers | wc -l)
  kill_count=$((count - 1))

  if [ "$kill_count" -gt 0 ]; then
    ps -C swaybg --no-headers -o pid,etime --sort=etime | head -n "$kill_count" | awk '{print $1}' | xargs -r kill
  fi

  swaybg -i /tmp/pscircle.png -m fit &
  sleep 30
done
