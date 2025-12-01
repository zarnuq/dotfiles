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
    "sh", "-c", "someblocks -p | dwlb -status-stdin all", NULL,
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
    { "rmpc",   NULL,   0,          0,            0,           2,        0,    0,    0,      0       },
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
    { "DP-3",      0.55f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL, 0,    0, 3440,  1440,  0.0f, 1,     0},
    { "DP-2",      0.55f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL, 3440, 0, 3440,  1440,  0.0f, 1,     0},
    { "DP-1",      0.55f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_270,    6880, 0, 1920,  1080,  0.0f, 2,     0},
    { NULL,        0.55f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL, -1,  -1, 0,     0,     0.0f, 0,     0},
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
#define SPAWN1(key, mod, ...) {1, {{mod, K(key)}}, spawn, {.v = (const char*[]){ __VA_ARGS__, NULL }}}  /* Single key spawn */
#define SPAWN2(k1, m1, k2, m2, ...) {2, {{m1, K(k1)}, {m2, K(k2)}}, spawn, {.v = (const char*[]){ __VA_ARGS__, NULL }}}  /* Two key chord */
#define TAG(KEY,SKEY,TAG) \
    {1,{{MOD,           K(KEY)}},  view,       {.ui = 1 << TAG} }, \
    {1,{{MOD|CTRL,      K(KEY)}},  toggleview, {.ui = 1 << TAG} }, \
    {1,{{MOD|SHIFT,     K(SKEY)}}, tag,        {.ui = 1 << TAG} }, \
    {1,{{MOD|CTRL|SHIFT,K(SKEY)}}, toggletag,  {.ui = 1 << TAG} }  /* Workspace switching */
#define MOVE(key1, key2, key3, key4, dist) \
    {1, {{MOD, K(key1)}}, moveresizekb, {.v = (int []){0, -dist, 0, 0}}}, \
    {1, {{MOD, K(key2)}}, moveresizekb, {.v = (int []){dist, 0, 0, 0}}}, \
    {1, {{MOD, K(key3)}}, moveresizekb, {.v = (int []){0, dist, 0, 0}}}, \
    {1, {{MOD, K(key4)}}, moveresizekb, {.v = (int []){-dist, 0, 0, 0}}}
#define RESIZE(key1, key2, key3, key4, dist) \
    {1, {{MOD|SHIFT, K(key1)}}, moveresizekb, {.v = (int []){0, 0, 0, -dist}}}, \
    {1, {{MOD|SHIFT, K(key2)}}, moveresizekb, {.v = (int []){0, 0, dist, 0}}}, \
    {1, {{MOD|SHIFT, K(key3)}}, moveresizekb, {.v = (int []){0, 0, 0, dist}}}, \
    {1, {{MOD|SHIFT, K(key4)}}, moveresizekb, {.v = (int []){0, 0, -dist, 0}}}
#define STACK(key1, mod1, key2, mod2) \
    {1, {{mod1, K(key1)}}, focusstack, {.i = +1}}, \
    {1, {{mod2, K(key2)}}, focusstack, {.i = -1}}
#define MFACT(key1, mod1, key2, mod2) \
    {1, {{mod1, K(key1)}}, setmfact, {.f = -0.05f}}, \
    {1, {{mod2, K(key2)}}, setmfact, {.f = +0.05f}}
#define MASTER(key1, mod1, key2, mod2) \
    {1, {{mod1, K(key1)}}, incnmaster, {.i = -1}}, \
    {1, {{mod2, K(key2)}}, incnmaster, {.i = +1}}
#define FOCUSMON(key1, mod1, key2, mod2) \
    {1, {{mod1, K(key1)}}, focusmon, {.i = WLR_DIRECTION_LEFT}}, \
    {1, {{mod2, K(key2)}}, focusmon, {.i = WLR_DIRECTION_RIGHT}}
#define TAGMON(key1, mod1, key2, mod2) \
    {1, {{mod1, K(key1)}}, tagmon, {.i = WLR_DIRECTION_LEFT}}, \
    {1, {{mod2, K(key2)}}, tagmon, {.i = WLR_DIRECTION_RIGHT}}
#define LAYOUT(key, mod, idx) {1, {{mod, K(key)}}, setlayout, {.v = &layouts[idx]}}  /* Switch layout */
#define ACTION(key, mod, func) {1, {{mod, K(key)}}, func, {0}}
#define CHVT(n) { 1, {{CTRL|ALT,XKB_KEY_XF86Switch_VT_##n}}, chvt, {.ui = (n)} }  /* Virtual terminal */

static const Keychord keychords[] = {

/* Spawning commands */
    /*      key        mod        cmd args... */
    SPAWN1( p,         MOD,       "swaylock"),
    SPAWN1( Tab,       MOD,       "kitty"),
    SPAWN1( space,     MOD,       "rofi", "-show", "drun", "-show-icons"),
    SPAWN1( BackSpace, MOD,       "kitty", "--class", "float"),
    SPAWN1( w,         MOD,       "kitty", "--class", "rmpc", "rmpc"),
    SPAWN1( W,         MOD|SHIFT, "rmpc rescan"),
    SPAWN1( t,         MOD,       "zen-browser"),
    SPAWN1( B,         MOD|SHIFT, "kitty", "-e", "yazi", "$HOME/Pictures/bgs"),
    SPAWN1( b,         MOD,       "/bin/sh", "-c", "swww img \"$(find $HOME/Pictures/bgs -type f \\( -iname '*.jpg' -o -iname '*.png' \\) | shuf -n1)\" --transition-fps 144 --transition-type top --transition-duration 1"),
    /*      key   mod2   key2   mod2   cmd args... */
    SPAWN2( r,    MOD,   d,     0,     "legcord"),
    SPAWN2( r,    MOD,   b,     0,     "brave"),
    SPAWN2( r,    MOD,   a,     0,     "pavucontrol"),
    SPAWN2( r,    MOD,   s,     0,     "steam"),
    SPAWN2( r,    MOD,   w,     0,     "/bin/sh", "-c", "$HOME/.local/bin/runbar.sh"),
    SPAWN2( s,    MOD,   d,     0,     "/bin/sh", "-c", "$HOME/.local/bin/screenshot.sh && notify-send 'Screenshot' 'Section saved!'"),
    SPAWN2( s,    MOD,   f,     0,     "/bin/sh", "-c", "$HOME/.local/bin/screenshotmain.sh && notify-send 'Screenshot' 'Fullscreen saved!'"),
    
/* Media controls */
    /*      key   mod   key2   mod2   cmd args... */
    SPAWN2( q,    MOD,  1,     0,     "easyeffects", "-l", "EQ"),
    SPAWN2( q,    MOD,  2,     0,     "easyeffects", "-l", "None"),
    /*      key              mod   cmd args... */
    SPAWN1( XF86AudioPlay,   0,    "playerctl", "-p", "mpd", "play-pause"),
    SPAWN1( XF86AudioPrev,   0,    "playerctl", "-p", "mpd", "previous"),
    SPAWN1( XF86AudioNext,   0,    "playerctl", "-p", "mpd", "next"),
    SPAWN1( Up,          ALT,  "/bin/sh", "-c", "pactl set-sink-volume @DEFAULT_SINK@ +5% && kill -35 $(pidof someblocks)"),
    SPAWN1( Down,        ALT,  "/bin/sh", "-c", "pactl set-sink-volume @DEFAULT_SINK@ -5% && kill -35 $(pidof someblocks)"),
    SPAWN1( Left,        ALT,  "/bin/sh", "-c", "pactl set-source-volume @DEFAULT_SOURCE@ -5% && kill -36 $(pidof someblocks)"),
    SPAWN1( Right,       ALT,  "/bin/sh", "-c", "pactl set-source-volume @DEFAULT_SOURCE@ +5% && kill -36 $(pidof someblocks)"),
    SPAWN1( End,         ALT,  "/bin/sh", "-c", "pactl set-source-mute @DEFAULT_SOURCE@ toggle && kill -36 $(pidof someblocks)"),
    SPAWN1( bracketleft, ALT,  "/bin/sh", "-c", "$HOME/.local/bin/flip.sh && touch /tmp/update_audio && kill -35 $(pidof someblocks)"),
    
/* Brightness control */
    /*      key    mod      cmd args... */
    SPAWN1( Left,  MOD|ALT, "brightnessctl", "s", "5%-"),
    SPAWN1( Right, MOD|ALT, "brightnessctl", "s", "5%+"),
    SPAWN1( Up,    MOD|ALT, "/bin/sh", "-c", "$HOME/.local/bin/gammastep.sh"),
    
/* Window management */
    /*      key      mod            function */
    ACTION( P,       MOD|SHIFT,     quit),
    ACTION( Q,       MOD|SHIFT,     killclient),
    ACTION( Return,  MOD,           zoom),
    ACTION( space,   MOD|SHIFT,     view),
    ACTION( f,       MOD,           togglefloating),
    ACTION( F,       MOD|SHIFT,     togglefullscreen),
    
/* Focus/Master Management */
    /*          decrease_key   decrease_mod   increase_key  increase_mod */
    STACK(      j,             MOD,           k,            MOD),
    MFACT(      h,             MOD,           l,            MOD),
    MASTER(     m,             MOD,           n,            MOD),
    FOCUSMON(   comma,         MOD,           period,       MOD),
    TAGMON(     less,          MOD|SHIFT,     greater,      MOD|SHIFT),
    MOVE(   Up, Left, Down, Right, 40),
    RESIZE( Up, Left, Down, Right, 40),
    
/* Tag management */
    /*   key  shift_key   tag_number */
    TAG( 1,   exclam,     0),
    TAG( 2,   at,         1),
    TAG( 3,   numbersign, 2),
    TAG( 4,   dollar,     3),
    TAG( 5,   percent,    4),
    TAG( 6,   asciicircum,5),
    TAG( 7,   ampersand,  6),
    TAG( 8,   asterisk,   7),
    TAG( 9,   parenleft,  8),
    LAYOUT(y, MOD|CTRL,   0),
    LAYOUT(u, MOD|CTRL,   1),
    LAYOUT(i, MOD|CTRL,   2),
    {1,{{MOD,K(0)}},view,{.ui = ~0}},
    {1,{{MOD|SHIFT,K(parenright)}},tag,{.ui = ~0}},
    CHVT(1),CHVT(2),CHVT(3),CHVT(4),CHVT(5),CHVT(6),CHVT(7),CHVT(8),CHVT(9),CHVT(10),CHVT(11),CHVT(12),
};

static const Button buttons[] = {
    { MOD, BTN_LEFT,   moveresize,     {.ui = CurMove} },
    { MOD, BTN_MIDDLE, togglefloating, {0} },
    { MOD, BTN_RIGHT,  moveresize,     {.ui = CurResize} },
};
