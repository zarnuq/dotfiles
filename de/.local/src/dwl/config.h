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
    "dunst",                                              NULL,
    "copyq",                                              NULL,
    "dwlb",                                               NULL,
    "swww-daemon",                                        NULL,
    "sh", "-c", "someblocks -p | dwlb -status-stdin all", NULL,
    "easyeffects", "--gapplication-service",              NULL,
    "xremap", "~/.config/xremap/config.yml",              NULL,
    "gammastep", "-O", "4000:4000",                       NULL,
    "nm-applet",                                          NULL,
    "kitty", "--class", "rmpc", "rmpc",                   NULL,
    NULL 
};

static const Env envs[] = {
    { "XDG_CURRENT_DESKTOP",  "sway" },
    { "XDG_SESSION_TYPE",     "wayland" },
    { "QT_QPA_PLATFORMTHEME", "qt6ct" },
    { "QT_STYLE_OVERRIDE",    "kvantum" },
    { "WAYLAND_DISPLAY",      "wayland-0" },
};

static const Rule rules[] = {
    /* app_id        title   tags mask   switchtotag   isfloating   monitor   x     y     width   height */
    { "rmpc",        NULL,   0,          0,            0,           2,        0,    0,    0,      0   },
    { "zen",         NULL,   1 << 2,     1,            0,          -1,        0,    0,    0,      0   },
    { "^steam",      NULL,   1 << 4,     0,            0,          -1,        0,    0,    0,      0   },
    { "^float",      NULL,   0,          0,            1,          -1,        0.25, 0.25, 0.5,    0.5 },
    { "pavucontrol", NULL,   0,          0,            1,          -1,        0.25, 0.25, 0.5,    0.5 },
};

static const Layout layouts[] = {
    /* symbol  |  arrange function */
    { "[]=",      tile },
    { "><>",      NULL }, 
    { "[M]",      monocle },
};

static const MonitorRule monrules[] = {
    /* name     mfact  nmaster scale layout       rotate/reflect              x     y  resx   resy   rate  mode   adaptive*/
    { "eDP-1",  0.55f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL, -1,  -1, 1920,  1200,  0.0f, 0,     0},
    { "DP-3",   0.55f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL, 0,    0, 3440,  1440,  0.0f, 1,     0},
    { "DP-2",   0.55f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL, 3440, 0, 3440,  1440,  0.0f, 1,     0},
    { "DP-1",   0.55f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_270,    6880, 0, 1920,  1080,  0.0f, 2,     0},
    { NULL,     0.55f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL, -1,  -1, 0,     0,     0.0f, 0,     0},
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
#define K(k) XKB_KEY_##k /* Key name shorthand - prepends XKB_KEY_ */
#define SPAWN1(m1, k1, ...) {1, {{m1, K(k1)}}, spawn, {.v = (const char*[]){ __VA_ARGS__, NULL }}}  /* Single key spawn */
#define SPAWN2(m1, k1, m2, k2, ...) {2, {{m1, K(k1)}, {m2, K(k2)}}, spawn, {.v = (const char*[]){ __VA_ARGS__, NULL }}}  /* Two key chord */
#define TAG(KEY,SKEY,TAG) \
    {1,{{MOD,           K(KEY)}},  view,       {.ui = 1 << TAG} }, \
    {1,{{MOD|CTRL,      K(KEY)}},  toggleview, {.ui = 1 << TAG} }, \
    {1,{{MOD|SHIFT,     K(SKEY)}}, tag,        {.ui = 1 << TAG} }, \
    {1,{{MOD|CTRL|SHIFT,K(SKEY)}}, toggletag,  {.ui = 1 << TAG} }  /* Workspace switching */
#define MOVE(k1, k2, k3, k4, dist) \
    {1, {{MOD, K(k1)}}, moveresizekb, {.v = (int []){0, -dist, 0, 0}}}, \
    {1, {{MOD, K(k2)}}, moveresizekb, {.v = (int []){dist, 0, 0, 0}}}, \
    {1, {{MOD, K(k3)}}, moveresizekb, {.v = (int []){0, dist, 0, 0}}}, \
    {1, {{MOD, K(k4)}}, moveresizekb, {.v = (int []){-dist, 0, 0, 0}}}
#define RESIZE(k1, k2, k3, k4, dist) \
    {1, {{MOD|SHIFT, K(k1)}}, moveresizekb, {.v = (int []){0, 0, 0, -dist}}}, \
    {1, {{MOD|SHIFT, K(k2)}}, moveresizekb, {.v = (int []){0, 0, dist, 0}}}, \
    {1, {{MOD|SHIFT, K(k3)}}, moveresizekb, {.v = (int []){0, 0, 0, dist}}}, \
    {1, {{MOD|SHIFT, K(k4)}}, moveresizekb, {.v = (int []){0, 0, -dist, 0}}}
#define STACK(m1, k1, m2, k2) \
    {1, {{m1, K(k1)}}, focusstack, {.i = +1}}, \
    {1, {{m2, K(k2)}}, focusstack, {.i = -1}}
#define MFACT(m1, k1, m2, k2) \
    {1, {{m1, K(k1)}}, setmfact, {.f = -0.05f}}, \
    {1, {{m2, K(k2)}}, setmfact, {.f = +0.05f}}
#define MASTER(m1, k1, m2, k2) \
    {1, {{m1, K(k1)}}, incnmaster, {.i = -1}}, \
    {1, {{m2, K(k2)}}, incnmaster, {.i = +1}}
#define FOCUSMON(m1, k1, m2, k2) \
    {1, {{m1, K(k1)}}, focusmon, {.i = WLR_DIRECTION_LEFT}}, \
    {1, {{m2, K(k2)}}, focusmon, {.i = WLR_DIRECTION_RIGHT}}
#define TAGMON(m1, k1, m2, k2) \
    {1, {{m1, K(k1)}}, tagmon, {.i = WLR_DIRECTION_LEFT}}, \
    {1, {{m2, K(k2)}}, tagmon, {.i = WLR_DIRECTION_RIGHT}}
#define LAYOUT(m1, k1, idx) {1, {{m1, K(k1)}}, setlayout, {.v = &layouts[idx]}}  /* Switch layout */
#define ACTION(m1, k1, func) {1, {{m1, K(k1)}}, func, {0}}
#define CHVT(n) { 1, {{CTRL|ALT,XKB_KEY_XF86Switch_VT_##n}}, chvt, {.ui = (n)} }  /* Virtual terminal */

static const Keychord keychords[] = {

/* Spawning commands */
    /*     mod       key        cmd_args... */
    SPAWN1(MOD,      p,         "swaylock"),
    SPAWN1(MOD,      Tab,       "kitty"),
    SPAWN1(MOD,      space,     "rofi", "-show", "drun", "-show-icons"),
    SPAWN1(MOD,      BackSpace, "kitty", "--class", "float"),
    SPAWN1(MOD,      w,         "kitty", "--class", "rmpc", "rmpc"),
    SPAWN1(MOD|SHIFT,W,         "rmpc rescan"),
    SPAWN1(MOD,      t,         "zen-browser"),
    SPAWN1(MOD|SHIFT,B,         "kitty", "-e", "yazi", "$HOME/Pictures/bgs"),
    SPAWN1(MOD,      b,         "/bin/sh", "-c", "swww img \"$(find $HOME/Pictures/bgs -type f \\( -iname '*.jpg' -o -iname '*.png' \\) | shuf -n1)\" --transition-fps 144 --transition-type top --transition-duration 1"),
    SPAWN1(MOD,      e,         "/bin/sh", "-c", "$HOME/.local/bin/eww.sh open"),
    SPAWN1(MOD|SHIFT,E,         "/bin/sh", "-c", "$HOME/.local/bin/eww.sh close"),
    /*     mod2  key   mod2   key2      cmd_args... */
    SPAWN2(MOD,  r,    0,     d,        "legcord"),
    SPAWN2(MOD,  r,    0,     b,        "brave"),
    SPAWN2(MOD,  r,    0,     a,        "pavucontrol"),
    SPAWN2(MOD,  r,    0,     s,        "steam"),
    SPAWN2(MOD,  r,    0,     w,        "/bin/sh", "-c", "$HOME/.local/bin/runbar.sh"),
    SPAWN2(MOD,  s,    0,     d,        "/bin/sh", "-c", "$HOME/.local/bin/screenshot.sh section && notify-send 'Screenshot' 'Section saved!'"),
    SPAWN2(MOD,  s,    0,     1,        "/bin/sh", "-c", "$HOME/.local/bin/screenshot.sh DP-1 && notify-send 'Screenshot' 'Fullscreen saved!'"),
    SPAWN2(MOD,  s,    0,     2,        "/bin/sh", "-c", "$HOME/.local/bin/screenshot.sh DP-2 && notify-send 'Screenshot' 'Fullscreen saved!'"),
    SPAWN2(MOD,  s,    0,     3,        "/bin/sh", "-c", "$HOME/.local/bin/screenshot.sh DP-3 && notify-send 'Screenshot' 'Fullscreen saved!'"),
    
/* Media controls */
    /*     mod  key            cmd_args... */
    SPAWN1(0,   XF86AudioPlay, "playerctl", "-p", "mpd", "play-pause"),
    SPAWN1(0,   XF86AudioPrev, "playerctl", "-p", "mpd", "previous"),
    SPAWN1(0,   XF86AudioNext, "playerctl", "-p", "mpd", "next"),
    SPAWN1(ALT, Up,            "/bin/sh", "-c", "pactl set-sink-volume @DEFAULT_SINK@ +5% && kill -35 $(pidof someblocks)"),
    SPAWN1(ALT, Down,          "/bin/sh", "-c", "pactl set-sink-volume @DEFAULT_SINK@ -5% && kill -35 $(pidof someblocks)"),
    SPAWN1(ALT, Left,          "/bin/sh", "-c", "pactl set-source-volume @DEFAULT_SOURCE@ -5% && kill -36 $(pidof someblocks)"),
    SPAWN1(ALT, Right,         "/bin/sh", "-c", "pactl set-source-volume @DEFAULT_SOURCE@ +5% && kill -36 $(pidof someblocks)"),
    SPAWN1(ALT, End,           "/bin/sh", "-c", "pactl set-source-mute @DEFAULT_SOURCE@ toggle && kill -36 $(pidof someblocks)"),
    SPAWN1(ALT, bracketleft,   "/bin/sh", "-c", "$HOME/.local/bin/flip.sh && touch /tmp/update_audio && kill -35 $(pidof someblocks)"),
    /*     mod  key mod2 key2 cmd_args... */
    SPAWN2(MOD, q,  0,   1,   "easyeffects", "-l", "EQ"),
    SPAWN2(MOD, q,  0,   2,   "easyeffects", "-l", "None"),

/* Brightness control */
    /*     mod      key    cmd_args... */
    SPAWN1(MOD|ALT, Left,  "brightnessctl", "s", "5%-"),
    SPAWN1(MOD|ALT, Right, "brightnessctl", "s", "5%+"),
    SPAWN1(MOD|ALT, Up,    "/bin/sh", "-c", "$HOME/.local/bin/gammastep.sh"),
    
/* Window management */
    /*     mod         key          function */
    ACTION(MOD|SHIFT,  P,           quit),
    ACTION(MOD|SHIFT,  Q,           killclient),
    ACTION(MOD,        Return,      zoom),
    ACTION(MOD|SHIFT,  space,       view),
    ACTION(MOD,        f,           togglefloating),
    ACTION(MOD|SHIFT,  F,           togglefullscreen),
    
/* Focus/Master Management */
    /*        decrease_mod decrease_key increase_mod  increase_key  */
    STACK(    MOD,         j,           MOD,          k       ),
    MFACT(    MOD,         h,           MOD,          l       ),
    MASTER(   MOD,         m,           MOD,          n       ),
    FOCUSMON( MOD,         comma,       MOD,          period  ),
    TAGMON(   MOD|SHIFT,   less,        MOD|SHIFT,    greater ),
    MOVE(   Up, Right, Down, Left, 40),
    RESIZE( Up, Right, Down, Left, 40),
    
/* Tag management */
    /*  key  shift_key   tag_number */
    TAG(1,   exclam,     0),
    TAG(2,   at,         1),
    TAG(3,   numbersign, 2),
    TAG(4,   dollar,     3),
    TAG(5,   percent,    4),
    TAG(6,   asciicircum,5),
    TAG(7,   ampersand,  6),
    TAG(8,   asterisk,   7),
    TAG(9,   parenleft,  8),
    LAYOUT(MOD|CTRL,y,0),
    LAYOUT(MOD|CTRL,u,1),
    LAYOUT(MOD|CTRL,i,2),
    {1,{{MOD,K(0)}},view,{.ui = ~0}},
    {1,{{MOD|SHIFT,K(parenright)}},tag,{.ui = ~0}},
    CHVT(1),CHVT(2),CHVT(3),CHVT(4),CHVT(5),CHVT(6),CHVT(7),CHVT(8),CHVT(9),CHVT(10),CHVT(11),CHVT(12),
};

static const Button buttons[] = {
    { MOD, BTN_LEFT,   moveresize,     {.ui = CurMove} },
    { MOD, BTN_MIDDLE, togglefloating, {0} },
    { MOD, BTN_RIGHT,  moveresize,     {.ui = CurResize} },
};
