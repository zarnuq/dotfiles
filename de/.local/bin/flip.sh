#!/bin/sh

# Two modes:
#   flip.sh            cycle the default sink between the EQ-wrapped outputs
#   flip.sh set <sink> switch to a named sink (the quickshell audio menu)
#
# Cycle the default sink between the two EQ-wrapped outputs:
#   effect_input.eq_fiio     -> FiiO K11 (USB DAC)
#   effect_input.eq_optical  -> motherboard S/PDIF optical (PCH) -> AVR
#
# Apps connect to the default sink, so flipping here moves their stream
# through the EQ chain pinned to the corresponding hardware output. We
# also migrate any already-playing sink-inputs to the new default —
# pactl set-default-sink only affects future streams.
#
# Raw alsa_output.* sinks are intentionally excluded — pick those via
# wpctl/pavucontrol if you want to bypass the EQ.

# Hardcoded because both the EQ chains and the optical profile setup
# are hardware-specific to this machine. The PCH card carries the
# motherboard's rear optical S/PDIF jack; the +input:analog-stereo
# variant keeps the analog input available alongside the digital out.
OPTICAL_CARD="alsa_card.pci-0000_00_1f.3"
OPTICAL_PROFILE="output:iec958-stereo+input:analog-stereo"

switch_to() {
    next_sink="$1"

    # If switching to the optical EQ, make sure the PCH card is on an
    # iec958 profile so the filter-chain's target.object actually resolves.
    if [ "$next_sink" = "effect_input.eq_optical" ]; then
        current_profile=$(pactl list cards | awk -v c="$OPTICAL_CARD" '
            $1 == "Name:" && $2 == c { found=1 }
            found && /Active Profile:/ { print $3; exit }
        ')
        case "$current_profile" in
            *iec958-stereo*) ;;  # already exposes the digital output
            *) pactl set-card-profile "$OPTICAL_CARD" "$OPTICAL_PROFILE" 2>/dev/null ;;
        esac
    fi

    pactl set-default-sink "$next_sink"

    # Migrate currently-playing app streams to the new default; a new default
    # only catches future ones. Only streams carrying an application.name —
    # that's what separates a real app from the filter chains' own playback
    # inputs and the mic loopback, which feed raw hardware and would break the
    # EQ graph if they were dragged along.
    pactl -f json list sink-inputs \
        | jq -r '.[] | select(.properties["application.name"] != null) | .index' \
        | while read -r input_id; do
            pactl move-sink-input "$input_id" "$next_sink" 2>/dev/null
        done

    # Nudge reach's audio block (RTMIN+1) so the bar names the new sink at once.
    kill -35 "$(pidof reach)" 2>/dev/null

    echo "Switched to: $next_sink"
}

# `set` skips the cycling entirely — the caller already knows the sink it wants,
# including the raw alsa_output.* ones the cycle deliberately steps over.
if [ "$1" = "set" ]; then
    [ -n "$2" ] || { echo "usage: flip.sh set <sink>" >&2; exit 1; }
    switch_to "$2"
    exit
fi

sinks="$(pactl list short sinks | awk '$2 ~ /^effect_input\.eq_/ {print $2}')"

set -- $sinks
if [ "$#" -eq 0 ]; then
    echo "No EQ sinks found — is sink-eq.conf loaded?" >&2
    exit 1
fi

default=$(pactl info | awk -F': ' '/Default Sink/{print $2}')

index=0
for sink in "$@"; do
    [ "$sink" = "$default" ] && break
    index=$((index + 1))
done

next_index=$(( (index + 1) % $# ))

i=0
for sink in "$@"; do
    if [ "$i" -eq "$next_index" ]; then
        next_sink="$sink"
        break
    fi
    i=$((i + 1))
done

switch_to "$next_sink"
