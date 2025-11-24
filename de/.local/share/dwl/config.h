#define COLOR(hex)    { ((hex >> 24) & 0xFF) / 255.0f, \
    ((hex >> 16) & 0xFF) / 255.0f, \
    ((hex >> 8) & 0xFF) / 255.0f, \
    (hex & 0xFF) / 255.0f }
static const int sloppyfocus               = 1;  /* focus follows mouse */
static const int bypass_surface_visibility = 0;  /* 1 means idle inhibitors will disable idle tracking even if it's surface isn't visible  */
static const unsigned int borderpx         = 1;  /* border pixel of windows */
static const float rootcolor[]             = COLOR(0x1e1e2eff);
static const float bordercolor[]           = COLOR(0x1e1e2eff);
static const float focuscolor[]            = COLOR(0xcba6f7ff);
static const float urgentcolor[]           = COLOR(0xff0000ff);
static const float fullscreen_bg[]         = {0.1f, 0.1f, 0.1f, 1.0f}; /* You can also use glsl colors */
static const int respect_monitor_reserved_area = 0;  /* 1 to monitor center while respecting the monitor's reserved area, 0 to monitor center */
static const char *cursor_theme            = "Bibata-Modern-Classic";
static const char cursor_size[]            = "24";
#define TAGCOUNT (9)
static int log_level = WLR_ERROR;

static const char *const autostart[] = {
    "dunst",                                                              NULL,
    "copyq",                                                              NULL,
    "dwlb",                                                               NULL,
    "swww-daemon",                                                        NULL,
    "sh", "-c", "~/.local/share/dwlb/status.sh | dwlb -status-stdin all", NULL,
    "sh", "-c", "~/.local/bin/screenshare.sh",                            NULL,
    "easyeffects", "--gapplication-service",                              NULL,
    "xremap", "~/.config/xremap/config.yml",                              NULL,
    "gammastep", "-O", "4000:4000",                                       NULL,
    "kitty", "--class", "rmpc", "rmpc",                                   NULL,
    NULL 
};

static const Env envs[] = {
    { "XDG_CURRENT_DESKTOP",  "wlroots" },
    { "XDG_CURRENT_DESKTOP",  "sway" },
    { "XDG_SESSION_DESKTOP",  "sway" },
    { "XDG_SESSION_TYPE",     "wayland" },
    { "QT_QPA_PLATFORMTHEME", "qt6ct" },
    { "QT_STYLE_OVERRIDE",    "kvantum" },
};

static const Rule rules[] = {
    /* app_id | title | tags mask | switchtotag | isfloating | monitor | x |   y |   width | height */
    { "rmpc",   NULL,   0,          0,            0,           1,        0,    0,    0,      0       },
    { "zen",    NULL,   1 << 2,     1,            0,          -1,        0,    0,    0,      0       },
    { "^steam", NULL,   1 << 4,     0,            0,          -1,        0,    0,    0,      0       },
    { "^float", NULL,   0,          0,            1,          -1,        0.25, 0.25, 0.5,    0.5},
};

static const Layout layouts[] = {
    /* symbol  |  arrange function */
    { "[]=",      tile },
    { "><>",      NULL }, 
    { "[M]",      monocle },
};

static const MonitorRule monrules[] = {
    /* name        mfact  nmaster scale layout       rotate/reflect              x     y  resx   resy   rate  mode   adaptive*/
    { "eDP-1",     0.55f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL, 1,   -1, 1920,  1200,  0.0f, 0,     0},
    { "HDMI-A-1",  0.55f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL, 0,    0, 2560,  1440,  0.0f, 0,     1},
    { "DP-2",      0.55f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL, 2560, 0, 3440,  1440,  0.0f, 1,     1},
    { "DP-1",      0.55f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_270,    6000, 0, 1920,  1080,  0.0f, 2,     1},
    { NULL,        0.55f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL, -1,  -1, 0,     0,     0.0f, 0,     1},
};

static const struct xkb_rule_names xkb_rules = {
    .options = NULL,
};

static const int repeat_rate = 50;
static const int repeat_delay = 300;
static const int tap_to_click = 1;
static const int tap_and_drag = 1;
static const int drag_lock = 1;
static const int natural_scrolling = 0;
static const int disable_while_typing = 1;
static const int left_handed = 0;
static const int middle_button_emulation = 0;
static const enum libinput_config_scroll_method scroll_method = LIBINPUT_CONFIG_SCROLL_2FG;
static const enum libinput_config_click_method click_method = LIBINPUT_CONFIG_CLICK_METHOD_BUTTON_AREAS;
static const uint32_t send_events_mode = LIBINPUT_CONFIG_SEND_EVENTS_ENABLED;
static const enum libinput_config_accel_profile accel_profile = LIBINPUT_CONFIG_ACCEL_PROFILE_ADAPTIVE;
static const double accel_speed = 0.0;
static const enum libinput_config_tap_button_map button_map = LIBINPUT_CONFIG_TAP_MAP_LRM;

#define MOD     WLR_MODIFIER_LOGO
#define CTRL    WLR_MODIFIER_CTRL
#define SHIFT   WLR_MODIFIER_SHIFT
#define ALT     WLR_MODIFIER_ALT

#define TAGKEYS(KEY,SKEY,TAG) \
    {1,{{MOD,           KEY}},  view,       {.ui = 1 << TAG} }, \
    {1,{{MOD|CTRL,      KEY}},  toggleview, {.ui = 1 << TAG} }, \
    {1,{{MOD|SHIFT,     SKEY}}, tag,        {.ui = 1 << TAG} }, \
    {1,{{MOD|CTRL|SHIFT,SKEY}}, toggletag,  {.ui = 1 << TAG} }
#define MOVEKEYS(dist) \
    {1,{{MOD, XKB_KEY_Down}}, moveresizekb, {.v = (int []){0, dist, 0, 0}}}, \
    {1,{{MOD, XKB_KEY_Up}}, moveresizekb, {.v = (int []){0, -dist, 0, 0}}}, \
    {1,{{MOD, XKB_KEY_Right}}, moveresizekb, {.v = (int []){dist, 0, 0, 0}}}, \
    {1,{{MOD, XKB_KEY_Left}}, moveresizekb, {.v = (int []){-dist, 0, 0, 0}}}

#define RESIZEKEYS(dist) \
    {1,{{MOD|SHIFT, XKB_KEY_Down}}, moveresizekb, {.v = (int []){0, 0, 0, dist}}}, \
    {1,{{MOD|SHIFT, XKB_KEY_Up}}, moveresizekb, {.v = (int []){0, 0, 0, -dist}}}, \
    {1,{{MOD|SHIFT, XKB_KEY_Right}}, moveresizekb, {.v = (int []){0, 0, dist, 0}}}, \
    {1,{{MOD|SHIFT, XKB_KEY_Left}}, moveresizekb, {.v = (int []){0, 0, -dist, 0}}}
#define STACK(key, mod, dir) {1, {{mod, key}}, focusstack, {.i = dir}}
#define MASTER(key, mod, dir) {1, {{mod, key}}, incnmaster, {.i = dir}}
#define MFACT(key, mod, val) {1, {{mod, key}}, setmfact, {.f = val}}
#define FOCUSMON(key, mod, dir) {1, {{mod, key}}, focusmon, {.i = dir}}
#define TAGMON(key, mod, dir) {1, {{mod, key}}, tagmon, {.i = dir}}
#define LAYOUT(key, mod, idx) {1, {{mod, key}}, setlayout, {.v = &layouts[idx]}}
#define ACTION(key, mod, func, arg) {1, {{mod, key}}, func, arg}
#define CHVT(n) { 1, {{CTRL|ALT,XKB_KEY_XF86Switch_VT_##n}}, chvt, {.ui = (n)} }
#define SPAWN(key, mod, ...) {1, {{mod, key}}, spawn, {.v = (const char*[]){ __VA_ARGS__, NULL }}}
#define SPAWN2(k1, m1, k2, m2, ...) {2, {{m1, k1}, {m2, k2}}, spawn, {.v = (const char*[]){ __VA_ARGS__, NULL }}}
static const Keychord keychords[] = {

    /* Spawning commands */
    SPAWN(XKB_KEY_p, MOD, "swaylock"),
    SPAWN(XKB_KEY_Tab, MOD, "kitty"),
    SPAWN(XKB_KEY_space, MOD, "rofi", "-show", "drun", "-show-icons"),
    SPAWN(XKB_KEY_BackSpace, MOD, "kitty", "--class", "float"),
    SPAWN(XKB_KEY_w, MOD, "kitty", "--class", "rmpc", "rmpc"),
    SPAWN(XKB_KEY_t, MOD, "zen-browser"),
    SPAWN(XKB_KEY_B, MOD|SHIFT, "kitty", "-e", "yazi", "/home/miles/Pictures/bgs"),
    SPAWN(XKB_KEY_b, MOD, "/bin/sh", "-c", "swww img \"$(find ~/Pictures/bgs -type f \\( -iname '*.jpg' -o -iname '*.png' \\) | shuf -n1)\" --transition-fps 144 --transition-type top --transition-duration 1"),
    SPAWN2(XKB_KEY_r, MOD, XKB_KEY_d, 0, "legcord"),
    SPAWN2(XKB_KEY_r, MOD, XKB_KEY_b, 0, "brave"),
    SPAWN2(XKB_KEY_r, MOD, XKB_KEY_a, 0, "pavucontrol"),
    SPAWN2(XKB_KEY_r, MOD, XKB_KEY_s, 0, "steam"),
    SPAWN2(XKB_KEY_r, MOD, XKB_KEY_w, 0, "/home/miles/.local/bin/runbar.sh"),
    SPAWN2(XKB_KEY_s, MOD, XKB_KEY_d, 0, "/bin/sh", "-c", "/home/miles/.local/bin/screenshot.sh && notify-send 'Screenshot' 'Section saved!'"),
    SPAWN2(XKB_KEY_s, MOD, XKB_KEY_f, 0, "/bin/sh", "-c", "/home/miles/.local/bin/screenshotmain.sh && notify-send 'Screenshot' 'Fullscreen saved!'"),

    /* Media controls */
    SPAWN2(XKB_KEY_q, MOD, XKB_KEY_1, 0, "easyeffects", "-l", "EQ"),
    SPAWN2(XKB_KEY_q, MOD, XKB_KEY_2, 0, "easyeffects", "-l", "None"),
    SPAWN(XKB_KEY_XF86AudioPlay, 0, "playerctl", "-p", "mpd", "play-pause"),
    SPAWN(XKB_KEY_XF86AudioPrev, 0, "playerctl", "-p", "mpd", "previous"),
    SPAWN(XKB_KEY_XF86AudioNext, 0, "playerctl", "-p", "mpd", "next"),
    SPAWN(XKB_KEY_Up, ALT, "/bin/sh", "-c", "pactl set-sink-volume @DEFAULT_SINK@ +5% && pkill -f 'sleep 60'"),
    SPAWN(XKB_KEY_Down, ALT, "/bin/sh", "-c", "pactl set-sink-volume @DEFAULT_SINK@ -5% && pkill -f 'sleep 60'"),
    SPAWN(XKB_KEY_Left, ALT, "/bin/sh", "-c", "pactl set-source-volume @DEFAULT_SOURCE@ -5% && pkill -f 'sleep 60'"),
    SPAWN(XKB_KEY_Right, ALT, "/bin/sh", "-c", "pactl set-source-volume @DEFAULT_SOURCE@ +5% && pkill -f 'sleep 60'"),
    SPAWN(XKB_KEY_End, ALT, "/bin/sh", "-c", "pactl set-source-mute @DEFAULT_SOURCE@ toggle && pkill -f 'sleep 60'"),
    SPAWN(XKB_KEY_bracketleft, ALT, "/bin/sh", "-c", "/home/miles/.local/bin/flip.sh && touch /tmp/update_audio && pkill -f 'sleep 60'"),

    /* Brightness control */
    SPAWNC(XKB_KEY_Left, MOD|ALT, "brightnessctl", "s", "5%-"),
    SPAWNC(XKB_KEY_Right, MOD|ALT, "brightnessctl", "s", "5%+"),
    SPAWNC(XKB_KEY_Up, MOD|ALT, "sh", "/home/miles/.local/bin/gammastep.sh"),

    /* Window management */
    ACTION(XKB_KEY_P, MOD|SHIFT,     quit, {0}),
    ACTION(XKB_KEY_Q, MOD|SHIFT,     killclient, {0}),
    ACTION(XKB_KEY_Return, MOD,      zoom, {0}),
    ACTION(XKB_KEY_space, MOD|SHIFT, view, {0}),
    ACTION(XKB_KEY_f, MOD,           togglefloating, {0}),
    ACTION(XKB_KEY_F, MOD|SHIFT,     togglefullscreen, {0}),

    /* Focus/Master Management */
    STACK(XKB_KEY_j, MOD, +1),
    STACK(XKB_KEY_k, MOD, -1),
    MFACT(XKB_KEY_h, MOD, -0.05f),
    MFACT(XKB_KEY_l, MOD, +0.05f),
    MASTER(XKB_KEY_n, MOD, +1),
    MASTER(XKB_KEY_m, MOD, -1),

    /* Monitor focus/tagging */
    FOCUSMON(XKB_KEY_comma, MOD, WLR_DIRECTION_LEFT),
    FOCUSMON(XKB_KEY_period, MOD, WLR_DIRECTION_RIGHT),
    TAGMON(XKB_KEY_less, MOD|SHIFT, WLR_DIRECTION_LEFT),
    TAGMON(XKB_KEY_greater, MOD|SHIFT, WLR_DIRECTION_RIGHT),

    /* Floating Window movement */
    MOVEKEYS(40),
    RESIZEKEYS(40),

    /* Layout management */
    LAYOUT(XKB_KEY_y, MOD|CTRL, 0),
    LAYOUT(XKB_KEY_u, MOD|CTRL, 1),
    LAYOUT(XKB_KEY_i, MOD|CTRL, 2),

    /* Tag management */
    TAGKEYS(XKB_KEY_1, XKB_KEY_exclam,     0),
    TAGKEYS(XKB_KEY_2, XKB_KEY_at,         1),
    TAGKEYS(XKB_KEY_3, XKB_KEY_numbersign, 2),
    TAGKEYS(XKB_KEY_4, XKB_KEY_dollar,     3),
    TAGKEYS(XKB_KEY_5, XKB_KEY_percent,    4),
    TAGKEYS(XKB_KEY_6, XKB_KEY_asciicircum,5),
    TAGKEYS(XKB_KEY_7, XKB_KEY_ampersand,  6),
    TAGKEYS(XKB_KEY_8, XKB_KEY_asterisk,   7),
    TAGKEYS(XKB_KEY_9, XKB_KEY_parenleft,  8),
    {1,{{MOD,XKB_KEY_0}},view,{.ui = ~0}},
    {1,{{MOD|SHIFT,XKB_KEY_parenright}},tag,{.ui = ~0}},

    /* Virtual terminals */
    CHVT(1),CHVT(2),CHVT(3),CHVT(4),CHVT(5),CHVT(6),CHVT(7),CHVT(8),CHVT(9),CHVT(10),CHVT(11),CHVT(12),
};

static const Button buttons[] = {
    { MOD, BTN_LEFT,   moveresize,     {.ui = CurMove} },
    { MOD, BTN_MIDDLE, togglefloating, {0} },
    { MOD, BTN_RIGHT,  moveresize,     {.ui = CurResize} },
};
