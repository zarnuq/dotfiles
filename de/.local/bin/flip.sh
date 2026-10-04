#!/bin/sh

# flip.sh set <sink> — make <sink> the default and move playing streams to it.
# Called by quickshell: the audio menu, and Volume.flip() (Alt+[), which cycles
# between the effect_input.eq_* chains and passes the next one here.
#
# pactl set-default-sink only affects future streams, hence the migration.

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
    # Plain-text listing, not `-f json`: that needed jq for one field. LC_ALL=C
    # keeps the "Sink Input #N" header unlocalised; the property key never is.
    LC_ALL=C pactl list sink-inputs \
        | awk '/^Sink Input #/ { id = substr($3, 2) } /^[ \t]+application\.name = / { print id }' \
        | while read -r input_id; do
            pactl move-sink-input "$input_id" "$next_sink" 2>/dev/null
        done

    echo "Switched to: $next_sink"
}

[ "$1" = "set" ] && [ -n "$2" ] || { echo "usage: flip.sh set <sink>" >&2; exit 1; }
switch_to "$2"
