#!/bin/sh

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

# Migrate currently-playing app streams to the new default. Only move
# inputs already feeding an EQ sink — otherwise we'd grab the filter
# chains' own playback sink-inputs (which go to raw hardware) and break
# the EQ graph.
eq_sink_ids=" $(pactl list short sinks | awk '$2 ~ /^effect_input\.eq_/ {print $1}' | tr '\n' ' ') "

pactl list short sink-inputs | while read -r input_id sink_id _rest; do
    case "$eq_sink_ids" in
        *" $sink_id "*) pactl move-sink-input "$input_id" "$next_sink" 2>/dev/null ;;
    esac
done

echo "Switched to: $next_sink"
