#app spawns
riverctl map normal Super P                             spawn "swaylock"; riverctl map normal Super+Shift P exit
riverctl map normal Super Tab                           spawn "kitty -e tmux"; riverctl map normal Super+Shift Tab                     spawn "wezterm"
riverctl map normal Super Space                         spawn "env QT_QPA_PLATFORMTHEME=qt6ct QT_STYLE_OVERRIDE=kvantum rofi -show drun -show-icons"
riverctl map normal Super+Control Space                 spawn 'ls ~/.local/bin/*.sh | xargs -n1 basename | rofi -dmenu -p "" | xargs -I{} sh -c "~/.local/bin/'{}'"'
riverctl map normal Super BackSpace                     spawn 'kitty sh -c "emacsclient -t"'
riverctl map normal Super Q                             close
riverctl map normal Super W                             spawn "legcord" 
riverctl map normal Super E                             spawn "nemo"
riverctl map normal Super R                             spawn "kitty -e rmpc"
riverctl map normal Super T                             spawn "zen-browser & zen";  riverctl map normal Super+Shift T spawn "brave"
riverctl map normal Super A                             spawn "pavucontrol"
riverctl map normal Super S                             spawn 'grim -g "$(slurp)"'; riverctl map normal Super+Shift S spawn 'grim -o DP-2'
riverctl map normal Super D                             spawn "steam"
riverctl map normal Super F                             toggle-fullscreen
riverctl map normal Super V                             toggle-float
riverctl map normal Super B                             spawn "wtype \"\$(grep -v '^#' ~/.local/bin/bkmrk.txt | rofi -dmenu | cut -d' ' -f1; sleep .5)\""

#movement
riverctl map normal Super J                             focus-view down
riverctl map normal Super K                             focus-view up
riverctl map normal Super H                             focus-view left
riverctl map normal Super L                             focus-view right

riverctl map normal Super N                             focus-output next 
riverctl map normal Super Period                        focus-output previous 
riverctl map normal Super+Shift N                       send-to-output next 
riverctl map normal Super+Shift Period                  send-to-output previous 

riverctl map normal Super Return                        zoom
riverctl map normal Super Up                            send-layout-cmd rivertile "main-location top"
riverctl map normal Super Right                         send-layout-cmd rivertile "main-location right"
riverctl map normal Super Down                          send-layout-cmd rivertile "main-location bottom"
riverctl map normal Super Left                          send-layout-cmd rivertile "main-location left"
riverctl map -repeat normal Super+Shift H               send-layout-cmd rivertile "main-ratio -0.05"
riverctl map -repeat normal Super+Shift L               send-layout-cmd rivertile "main-ratio +0.05"
riverctl map -repeat normal Super+Shift M               send-layout-cmd rivertile "main-count +1"
riverctl map -repeat normal Super+Shift Comma           send-layout-cmd rivertile "main-count -1"

riverctl map -repeat normal Super+Control H             resize horizontal  30
riverctl map -repeat normal Super+Control J             resize vertical    30
riverctl map -repeat normal Super+Control K             resize vertical   -30
riverctl map -repeat normal Super+Control L             resize horizontal -30
riverctl map -repeat normal Super+Control+Shift H       move left  30
riverctl map -repeat normal Super+Control+Shift J       move down  30
riverctl map -repeat normal Super+Control+Shift K       move up    30
riverctl map -repeat normal Super+Control+Shift L       move right 30

riverctl map-pointer normal Super BTN_LEFT              move-view
riverctl map-pointer normal Super BTN_RIGHT             resize-view
riverctl map-pointer normal Super BTN_MIDDLE            toggle-float


#workspaces
for i in $(seq 1 9)
do
    tags=$((1 << ($i - 1)))
    riverctl map normal Super                           $i set-focused-tags $tags
    riverctl map normal Super+Shift                     $i set-view-tags $tags
    riverctl map normal Super+Alt                       $i toggle-focused-tags $tags
    riverctl map normal Super+Shift+Alt                 $i toggle-view-tags $tags
done
all_tags=$(((1 << 9) - 1))
riverctl map normal Super                               0 set-focused-tags $all_tags
riverctl map normal Super+Shift                         0 set-view-tags $all_tags


#media keys
riverctl map -repeat normal Alt up                      spawn "pactl set-sink-volume @DEFAULT_SINK@ +5%"
riverctl map -repeat normal Alt down                    spawn "pactl set-sink-volume @DEFAULT_SINK@ -5%"
riverctl map -repeat normal Alt left                    spawn "pactl set-source-volume @DEFAULT_SOURCE@ -5%"
riverctl map -repeat normal Alt right                   spawn "pactl set-source-volume @DEFAULT_SOURCE@ +5%"
riverctl map normal Alt end                             spawn "pactl set-source-mute @DEFAULT_SOURCE@ toggle"
riverctl map normal Alt bracketleft                     spawn "sh ~/.local/bin/flip.sh"
            
riverctl map normal None XF86AudioMedia                 spawn 'playerctl -p mpd play-pause'
riverctl map normal None XF86AudioPlay                  spawn 'playerctl -p mpd play-pause'
riverctl map normal None XF86AudioPrev                  spawn 'playerctl -p mpd previous'
riverctl map normal None XF86AudioNext                  spawn 'playerctl -p mpd next'

riverctl map -repeat normal Super+Alt right             spawn 'brightnessctl s 3%+'
riverctl map -repeat normal Super+Alt left              spawn 'brightnessctl s 3%-'
riverctl map         normal Super+Alt up                spawn 'sh ~/.local/bin/gammastep.sh'
