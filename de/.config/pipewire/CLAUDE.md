# Audio: PipeWire + WirePlumber

Loaded when working in this directory. Moved out of the root `CLAUDE.md`, which keeps only an index.

**Config:** `de/.config/pipewire/` + `de/.config/wireplumber/`. PipeWire/WirePlumber/pipewire-pulse run as runit user services.

- `pipewire.conf.d/custom.conf` — `default.clock.rate = 192000`, `allowed-rates = [192000]`, `link.max-buffers = 16`.
- `pipewire.conf.d/sink-eq.conf` — 16-band parametric EQ via builtin `filter-chain` (replaces EasyEffects). Two EQ sinks pinned via `target.object` to specific hardware: `effect_input.eq_fiio` → FiiO K11 USB DAC, `effect_input.eq_optical` → USB2.0 optical. All bands `bq_peaking`, Q=2.3521, APO(DR); coefficients mirror old `easyeffects/output/EQ.json`. **Keep both instances' coefficients in sync if regenerating.** Verify: `wpctl status | grep -E "effect_input\.eq_(fiio|optical)"`.
- `wireplumber.conf.d/softvol.conf` — `api.alsa.soft-mixer = true` for all USB cards (`alsa_card.usb-.*`); required for USB software volume.

**EQ switching:** apps connect to the default sink; `Alt+[` (`qs ipc call volume flip`) cycles the default between the two `effect_input.eq_*` sinks via `flip.sh set <sink>`, which also migrates playing streams. Raw `alsa_output.*` sinks excluded (pick those in the audio menu or via wpctl to bypass EQ).
