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
	/* app_id | title | tags mask | switchtotag | isfloating | monitor */
  { "rmpc",   NULL,   0,          0,            0,           1},
  { "zen",    NULL,   1 << 2,     1,            0,          -1},
  { "^steam", NULL,   1 << 4,     0,            0,          -1},
};

static const Layout layouts[] = {
	/* symbol  |  arrange function */
	{ "[]=",      tile },
	{ "><>",      NULL }, 
	{ "[M]",      monocle },
};

static const MonitorRule monrules[] = {
	/* name        mfact  nmaster scale layout       rotate/reflect              x     y  resx   resy   rate  mode   adaptive*/
  { "eDP-1",     0.55f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL,  -1, -1, 1920,  1200,  0.0f, 0,     0},
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
	{ 1,{{MOD,           KEY}},  view,       {.ui = 1 << TAG} }, \
	{ 1,{{MOD|CTRL,      KEY}},  toggleview, {.ui = 1 << TAG} }, \
	{ 1,{{MOD|SHIFT,    SKEY}}, tag,        {.ui = 1 << TAG} }, \
	{ 1,{{MOD|CTRL|SHIFT,SKEY}}, toggletag,  {.ui = 1 << TAG} }
#define SHCMD(cmd) { .v = (const char*[]){ "/bin/sh", "-c", cmd, NULL } }

/* commands */
static const char *lockscreen[]   = { "swaylock", NULL };
static const char *termcmd[]      = { "kitty", NULL };
static const char *term2[]        = { "wezterm", NULL };
static const char *menucmd[]      = { "rofi", "-show", "drun", "-show-icons", NULL };
static const char *emacs[]        = { "kitty", "sh", "-c", "emacsclient -t", NULL };
static const char *legcord[]      = { "legcord", NULL };
static const char *rmpc[]         = { "kitty", "--class", "rmpc", "rmpc", NULL };
static const char *browser[]      = { "zen-browser", NULL };
static const char *browser2[]     = { "brave", NULL };
static const char *pavuc[]        = { "pavucontrol", NULL };
static const char *runbar[]       = { "sh", "/home/miles/.local/bin/runbar.sh", NULL };
static const char *brightup[]     = { "sh", "-c","brightnessctl s 5%+", NULL };
static const char *brightdown[]   = { "sh", "-c","brightnessctl s 5%-", NULL };
static const char *screenshotmain[]={ "sh", "-c","grim -o DP-2 && notify-send 'Screenshot' 'Fullscreen saved!'", NULL };
static const char *screenshot[]   = { "sh", "-c","grim -g \"$(slurp)\" && notify-send 'Screenshot' 'Section saved!'", NULL };
static const char *steam[]        = { "steam", NULL };
static const char *bgcmd[]        = { "kitty", "-e", "yazi", "/home/miles/Pictures/bgs", NULL };
static const char *randbgcmd[]    = {"sh", "-c","swww img \"$(find ~/Pictures/bgs -type f \\( -iname '*.jpg' -o -iname '*.png' \\) | shuf -n1)\" --transition-fps 144 --transition-type top --transition-duration 1",NULL};

static const char *volupcmd[]     = { "sh", "-c", "pactl set-sink-volume @DEFAULT_SINK@ +5% && pkill -f 'sleep 60'", NULL };
static const char *voldowncmd[]   = { "sh", "-c", "pactl set-sink-volume @DEFAULT_SINK@ -5% && pkill -f 'sleep 60'", NULL };
static const char *micdowncmd[]   = { "sh", "-c", "pactl set-source-volume @DEFAULT_SOURCE@ -5% && pkill -f 'sleep 60'", NULL };
static const char *micupcmd[]     = { "sh", "-c", "pactl set-source-volume @DEFAULT_SOURCE@ +5% && pkill -f 'sleep 60'", NULL };
static const char *mutemiccmd[]   = { "sh", "-c", "pactl set-source-mute @DEFAULT_SOURCE@ toggle && pkill -f 'sleep 60'", NULL };
static const char *flipcmd[]      = { "sh", "-c", "/home/miles/.local/bin/flip.sh && touch /tmp/update_audio && pkill -f 'sleep 60'", NULL };
static const char *mediatoggle[]  = { "playerctl", "-p", "mpd", "play-pause", NULL };
static const char *mediaprevcmd[] = { "playerctl", "-p", "mpd", "previous", NULL };
static const char *medianextcmd[] = { "playerctl", "-p", "mpd", "next", NULL };
static const char *gammastepcmd[] = { "sh", "/home/miles/.local/bin/gammastep.sh", NULL };

static const Keychord keychords[] = {
  {1,    {{MOD,                 XKB_KEY_p}},              spawn,            {.v = lockscreen}},
	{1,    {{MOD|SHIFT,           XKB_KEY_P}},              quit,             {0}},
	{1,    {{MOD|SHIFT,           XKB_KEY_Q}},              killclient,       {0}},
  {1,    {{MOD,                 XKB_KEY_Tab}},            spawn,            {.v = termcmd}},
  {1,    {{MOD|SHIFT,           XKB_KEY_Tab}},            spawn,            {.v = term2}},
  {1,    {{MOD,                 XKB_KEY_space}},          spawn,            {.v = menucmd}},
  {1,    {{MOD,                 XKB_KEY_BackSpace}},      spawn,            {.v = emacs}},
  {1,    {{MOD,                 XKB_KEY_w}},              spawn,            {.v = rmpc}},
  {1,    {{MOD,                 XKB_KEY_t}},              spawn,            {.v = browser}},
  {2,    {{MOD,XKB_KEY_r},  {0, XKB_KEY_d}},              spawn,            {.v = legcord} },
  {2,    {{MOD,XKB_KEY_r},  {0, XKB_KEY_b}},              spawn,            {.v = browser2} },
  {2,    {{MOD,XKB_KEY_r},  {0, XKB_KEY_a}},              spawn,            {.v = pavuc} },
  {2,    {{MOD,XKB_KEY_r},  {0, XKB_KEY_s}},              spawn,            {.v = steam} },
  {2,    {{MOD,XKB_KEY_r},  {0, XKB_KEY_w}},              spawn,            {.v = runbar} },
  {2,    {{MOD,XKB_KEY_s},  {0, XKB_KEY_d}},              spawn,            {.v = screenshot} },
  {2,    {{MOD,XKB_KEY_s},  {0, XKB_KEY_f}},              spawn,            {.v = screenshotmain} },
  {1,    {{MOD|SHIFT,           XKB_KEY_B}},              spawn,            {.v = bgcmd}},
  {1,    {{MOD,                 XKB_KEY_b}},              spawn,            {.v = randbgcmd}},
	{1,    {{MOD,                 XKB_KEY_j}},              focusstack,       {.i = +1}},
	{1,    {{MOD,                 XKB_KEY_k}},              focusstack,       {.i = -1}},
	{1,    {{MOD,                 XKB_KEY_n}},              incnmaster,       {.i = +1}},
	{1,    {{MOD,                 XKB_KEY_m}},              incnmaster,       {.i = -1}},
	{1,    {{MOD,                 XKB_KEY_h}},              setmfact,         {.f = -0.05f}},
	{1,    {{MOD,                 XKB_KEY_l}},              setmfact,         {.f = +0.05f}},
	{1,    {{MOD,                 XKB_KEY_Return}},         zoom,             {0}},
	{1,    {{MOD|SHIFT,           XKB_KEY_space}},          view,             {0}},
	{1,    {{MOD,                 XKB_KEY_f}},              togglefloating,   {0}},
	{1,    {{MOD|SHIFT,           XKB_KEY_F}},              togglefullscreen, {0}},
	{1,    {{MOD,                 XKB_KEY_0}},              view,             {.ui = ~0}},
	{1,    {{MOD|SHIFT,           XKB_KEY_parenright}},     tag,              {.ui = ~0}},
	{1,    {{MOD,                 XKB_KEY_comma}},          focusmon,         {.i = WLR_DIRECTION_LEFT}},
	{1,    {{MOD,                 XKB_KEY_period}},         focusmon,         {.i = WLR_DIRECTION_RIGHT}},
	{1,    {{MOD|SHIFT,           XKB_KEY_less}},           tagmon,           {.i = WLR_DIRECTION_LEFT}},
	{1,    {{MOD|SHIFT,           XKB_KEY_greater}},        tagmon,           {.i = WLR_DIRECTION_RIGHT}},
	{1,    {{MOD,                 XKB_KEY_Down}},           moveresizekb,     {.v = (int []){0,40,0,0}}},
	{1,    {{MOD,                 XKB_KEY_Up}},             moveresizekb,     {.v = (int []){0,-40,0,0}}},
	{1,    {{MOD,                 XKB_KEY_Right}},          moveresizekb,     {.v = (int []){40,0,0,0}}},
	{1,    {{MOD,                 XKB_KEY_Left}},           moveresizekb,     {.v = (int []){-40,0,0,0}}},
	{1,    {{MOD|SHIFT,           XKB_KEY_Down}},           moveresizekb,     {.v = (int []){0,0,0,40}}},
	{1,    {{MOD|SHIFT,           XKB_KEY_Up}},             moveresizekb,     {.v = (int []){0,0,0,-40}}},
	{1,    {{MOD|SHIFT,           XKB_KEY_Right}},          moveresizekb,     {.v = (int []){0,0,40,0}}},
	{1,    {{MOD|SHIFT,           XKB_KEY_Left}},           moveresizekb,     {.v = (int []){0,0,-40,0}}},
  {1,    {{ALT,                 XKB_KEY_Up}},             spawn,            {.v = volupcmd}},
  {1,    {{ALT,                 XKB_KEY_Down}},           spawn,            {.v = voldowncmd}},
  {1,    {{ALT,                 XKB_KEY_Left}},           spawn,            {.v = micdowncmd}},
  {1,    {{ALT,                 XKB_KEY_Right}},          spawn,            {.v = micupcmd}},
  {1,    {{ALT,                 XKB_KEY_End}},            spawn,            {.v = mutemiccmd}},
  {1,    {{ALT,                 XKB_KEY_bracketleft}},    spawn,            {.v = flipcmd}},
  {1,    {{MOD|ALT,             XKB_KEY_Left}},           spawn,            {.v = brightdown}},
  {1,    {{MOD|ALT,             XKB_KEY_Right}},          spawn,            {.v = brightup}},
  {1,    {{MOD|ALT,             XKB_KEY_Up}},             spawn,            {.v = gammastepcmd}},
  {1,    {{MOD|CTRL,            XKB_KEY_y}},              setlayout,        {.v = &layouts[0]}},
	{1,    {{MOD|CTRL,            XKB_KEY_u}},              setlayout,        {.v = &layouts[1]}},
	{1,    {{MOD|CTRL,            XKB_KEY_i}},              setlayout,        {.v = &layouts[2]}},
  {1,    {{0,                   XKB_KEY_XF86AudioMedia}}, spawn,            {.v = mediatoggle}},
  {1,    {{0,                   XKB_KEY_XF86AudioPlay}},  spawn,            {.v = mediatoggle}},
  {1,    {{0,                   XKB_KEY_XF86AudioPrev}},  spawn,            {.v = mediaprevcmd}},
  {1,    {{0,                   XKB_KEY_XF86AudioNext}},  spawn,            {.v = medianextcmd}},
	TAGKEYS(XKB_KEY_1, XKB_KEY_exclam,     0),
	TAGKEYS(XKB_KEY_2, XKB_KEY_at,         1),
	TAGKEYS(XKB_KEY_3, XKB_KEY_numbersign, 2),
	TAGKEYS(XKB_KEY_4, XKB_KEY_dollar,     3),
	TAGKEYS(XKB_KEY_5, XKB_KEY_percent,    4),
	TAGKEYS(XKB_KEY_6, XKB_KEY_asciicircum,5),
	TAGKEYS(XKB_KEY_7, XKB_KEY_ampersand,  6),
	TAGKEYS(XKB_KEY_8, XKB_KEY_asterisk,   7),
	TAGKEYS(XKB_KEY_9, XKB_KEY_parenleft,  8),
#define CHVT(n) { 1, {{CTRL|ALT,XKB_KEY_XF86Switch_VT_##n}}, chvt, {.ui = (n)} }
 	CHVT(1), CHVT(2), CHVT(3), CHVT(4), CHVT(5), CHVT(6),
 	CHVT(7), CHVT(8), CHVT(9), CHVT(10), CHVT(11), CHVT(12),
	{ 1, {{CTRL|ALT, XKB_KEY_Terminate_Server}}, quit,{0} },

};

static const Button buttons[] = {
	{ MOD, BTN_LEFT,   moveresize,     {.ui = CurMove} },
	{ MOD, BTN_MIDDLE, togglefloating, {0} },
	{ MOD, BTN_RIGHT,  moveresize,     {.ui = CurResize} },
};
