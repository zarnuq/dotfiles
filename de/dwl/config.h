/* Taken from https://github.com/djpohly/dwl/issues/466 */
#define COLOR(hex)    { ((hex >> 24) & 0xFF) / 255.0f, \
                        ((hex >> 16) & 0xFF) / 255.0f, \
                        ((hex >> 8) & 0xFF) / 255.0f, \
                        (hex & 0xFF) / 255.0f }
/* appearance */
static const int sloppyfocus               = 1;  /* focus follows mouse */
static const int bypass_surface_visibility = 0;  /* 1 means idle inhibitors will disable idle tracking even if it's surface isn't visible  */
static const unsigned int borderpx         = 1;  /* border pixel of windows */
static const float rootcolor[]             = COLOR(0x222222ff);
static const float bordercolor[]           = COLOR(0x444444ff);
static const float focuscolor[]            = COLOR(0x005577ff);
static const float urgentcolor[]           = COLOR(0xff0000ff);
/* This conforms to the xdg-protocol. Set the alpha to zero to restore the old behavior */
static const float fullscreen_bg[]         = {0.1f, 0.1f, 0.1f, 1.0f}; /* You can also use glsl colors */
static const char *cursor_theme            = "Bibata-Modern-Classic";
static const char cursor_size[]            = "24"; /* Make sure it's a valid integer, otherwise things will break */

/* tagging - TAGCOUNT must be no greater than 31 */
#define TAGCOUNT (9)

/* logging */
static int log_level = WLR_ERROR;

/* Autostart */
static const char *const autostart[] = {
    "sh", "/home/miles/dwl/autostart.sh", NULL,
    NULL /* terminate */
};


/* NOTE: ALWAYS keep a rule declared even if you don't use rules (e.g leave at least one example) */
static const Rule rules[] = {
	/* app_id             title       tags mask     isfloating   monitor */
	/* examples: */
	{ "Gimp_EXAMPLE",     NULL,       0,            1,           -1 }, /* Start on currently visible tags floating, not tiled */
	{ "firefox_EXAMPLE",  NULL,       1 << 8,       0,           -1 }, /* Start on ONLY tag "9" */
};

/* layout(s) */
static const Layout layouts[] = {
	/* symbol     arrange function */
	{ "[]=",      tile },
	{ "><>",      NULL },    /* no layout function means floating behavior */
	{ "[M]",      monocle },
};

/* monitors */
/* (x=-1, y=-1) is reserved as an "autoconfigure" monitor position indicator
 * WARNING: negative values other than (-1, -1) cause problems with Xwayland clients
 * https://gitlab.freedesktop.org/xorg/xserver/-/issues/899
*/
/* NOTE: ALWAYS add a fallback rule, even if you are completely sure it won't be used */

static const MonitorRule monrules[] = {
	/* name        mfact  nmaster scale layout       rotate/reflect              x     y  resx   resy   rate  mode   adaptive*/
  { "HDMI-A-1",  0.55f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL, 0,    0, 2560,  1440,  0.0f, 0,     1},
  { "DP-2",      0.55f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL, 2560, 0, 3440,  1440,  0.0f, 1,     1},
  { "DP-1",      0.55f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_270,    6000, 0, 1920,  1080,  0.0f, 2,     1},
	{ NULL,        0.55f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL, -1,  -1, 0,     0,     0.0f, 0,     1},
};

/* keyboard */
static const struct xkb_rule_names xkb_rules = {
	/* can specify fields: rules, model, layout, variant, options */
	/* example:
	.options = "ctrl:nocaps",
	*/
	.options = NULL,
};

static const int repeat_rate = 50;
static const int repeat_delay = 300;

/* Trackpad */
static const int tap_to_click = 1;
static const int tap_and_drag = 1;
static const int drag_lock = 1;
static const int natural_scrolling = 0;
static const int disable_while_typing = 1;
static const int left_handed = 0;
static const int middle_button_emulation = 0;
/* You can choose between:
LIBINPUT_CONFIG_SCROLL_NO_SCROLL
LIBINPUT_CONFIG_SCROLL_2FG
LIBINPUT_CONFIG_SCROLL_EDGE
LIBINPUT_CONFIG_SCROLL_ON_BUTTON_DOWN
*/
static const enum libinput_config_scroll_method scroll_method = LIBINPUT_CONFIG_SCROLL_2FG;

/* You can choose between:
LIBINPUT_CONFIG_CLICK_METHOD_NONE
LIBINPUT_CONFIG_CLICK_METHOD_BUTTON_AREAS
LIBINPUT_CONFIG_CLICK_METHOD_CLICKFINGER
*/
static const enum libinput_config_click_method click_method = LIBINPUT_CONFIG_CLICK_METHOD_BUTTON_AREAS;

/* You can choose between:
LIBINPUT_CONFIG_SEND_EVENTS_ENABLED
LIBINPUT_CONFIG_SEND_EVENTS_DISABLED
LIBINPUT_CONFIG_SEND_EVENTS_DISABLED_ON_EXTERNAL_MOUSE
*/
static const uint32_t send_events_mode = LIBINPUT_CONFIG_SEND_EVENTS_ENABLED;

/* You can choose between:
LIBINPUT_CONFIG_ACCEL_PROFILE_FLAT
LIBINPUT_CONFIG_ACCEL_PROFILE_ADAPTIVE
*/
static const enum libinput_config_accel_profile accel_profile = LIBINPUT_CONFIG_ACCEL_PROFILE_ADAPTIVE;
static const double accel_speed = 0.0;

/* You can choose between:
LIBINPUT_CONFIG_TAP_MAP_LRM -- 1/2/3 finger tap maps to left/right/middle
LIBINPUT_CONFIG_TAP_MAP_LMR -- 1/2/3 finger tap maps to left/middle/right
*/
static const enum libinput_config_tap_button_map button_map = LIBINPUT_CONFIG_TAP_MAP_LRM;

/* If you want to use the windows key for MODKEY, use WLR_MODIFIER_LOGO */
#define MODKEY WLR_MODIFIER_LOGO

#define TAGKEYS(KEY,SKEY,TAG) \
	{ MODKEY,                    KEY,            view,            {.ui = 1 << TAG} }, \
	{ MODKEY|WLR_MODIFIER_CTRL,  KEY,            toggleview,      {.ui = 1 << TAG} }, \
	{ MODKEY|WLR_MODIFIER_SHIFT, SKEY,           tag,             {.ui = 1 << TAG} }, \
	{ MODKEY|WLR_MODIFIER_CTRL|WLR_MODIFIER_SHIFT,SKEY,toggletag, {.ui = 1 << TAG} }

/* helper for spawning shell commands in the pre dwm-5.0 fashion */
#define SHCMD(cmd) { .v = (const char*[]){ "/bin/sh", "-c", cmd, NULL } }

/* commands */
static const char *lockscreen[]        = { "swaylock", NULL };
static const char *term[]   = { "kitty", "-e", "tmux", NULL };
static const char *term2[]     = { "wezterm", NULL };
static const char *menu[]       = { "env", "QT_QPA_PLATFORMTHEME=qt6ct", "QT_STYLE_OVERRIDE=kvantum", "rofi", "-show", "drun", "-show-icons", NULL };
static const char *emacs[] = { "kitty", "sh", "-c", "emacsclient -t", NULL };
static const char *legcord[]     = { "legcord", NULL };
static const char *rmpc[]        = { "kitty", "-e", "rmpc", NULL };
static const char *browser[]         = { "zen-browser", NULL };
static const char *browser2[]       = { "brave", NULL };
static const char *pavuc[] = { "pavucontrol", NULL };
static const char *sspart[]      = { "sh", "-c", "grim -g \"$(slurp)\"", NULL };
static const char *ssmain[]        = { "grim", "-o", "DP-2", NULL };
static const char *steam[]       = { "steam", NULL };
static const char *bkmrk[]       = { "sh", "-c", "wtype \"$(grep -v '^#' ~/.local/bin/bkmrk.txt | rofi -dmenu | cut -d' ' -f1; sleep .5)\"", NULL };


static const char *volupcmd[]     = { "pactl", "set-sink-volume", "@DEFAULT_SINK@", "+5%", NULL };
static const char *voldowncmd[]   = { "pactl", "set-sink-volume", "@DEFAULT_SINK@", "-5%", NULL };
static const char *micdowncmd[]   = { "pactl", "set-source-volume", "@DEFAULT_SOURCE@", "-5%", NULL };
static const char *micupcmd[]     = { "pactl", "set-source-volume", "@DEFAULT_SOURCE@", "+5%", NULL };
static const char *mutemiccmd[]   = { "pactl", "set-source-mute", "@DEFAULT_SOURCE@", "toggle", NULL };
static const char *flipcmd[]      = { "sh", "/home/miles/.local/bin/flip.sh", NULL };

static const char *mediaplaypausecmd[] = { "playerctl", "-p", "mpd", "play-pause", NULL };
static const char *mediaprevcmd[]      = { "playerctl", "-p", "mpd", "previous", NULL };
static const char *medianextcmd[]      = { "playerctl", "-p", "mpd", "next", NULL };
static const char *gammastepcmd[] = { "sh", "/home/yourusername/.local/bin/gammastep.sh", NULL };


static const Key keys[] = {
  { MODKEY,                       XKB_KEY_p,                   spawn,            {.v = lockscreen} },
	{ MODKEY|WLR_MODIFIER_SHIFT,    XKB_KEY_P,                   quit,             {0} },
  { MODKEY,                       XKB_KEY_Tab,                 spawn,            {.v = term} },
  { MODKEY|WLR_MODIFIER_SHIFT,    XKB_KEY_Tab,                 spawn,            {.v = term2} },
  { MODKEY,                       XKB_KEY_space,               spawn,            {.v = menu} },
  { MODKEY,                       XKB_KEY_BackSpace,           spawn,            {.v = emacs} },
  { MODKEY,                       XKB_KEY_w,                   spawn,            {.v = legcord} },
  { MODKEY,                       XKB_KEY_r,                   spawn,            {.v = rmpc} },
  { MODKEY,                       XKB_KEY_t,                   spawn,            {.v = browser} },
  { MODKEY|WLR_MODIFIER_SHIFT,    XKB_KEY_t,                   spawn,            {.v = browser2} },
  { MODKEY,                       XKB_KEY_a,                   spawn,            {.v = pavuc} },
  { MODKEY,                       XKB_KEY_s,                   spawn,            {.v = sspart} },
  { MODKEY|WLR_MODIFIER_SHIFT,    XKB_KEY_s,                   spawn,            {.v = ssmain} },
  { MODKEY,                       XKB_KEY_d,                   spawn,            {.v = steam} },
  { MODKEY,                       XKB_KEY_b,                   spawn,            {.v = bkmrk} },
	{ MODKEY,                       XKB_KEY_j,                   focusstack,       {.i = +1} },
	{ MODKEY,                       XKB_KEY_k,                   focusstack,       {.i = -1} },
	{ MODKEY,                       XKB_KEY_i,                   incnmaster,       {.i = +1} },
	{ MODKEY,                       XKB_KEY_d,                   incnmaster,       {.i = -1} },
	{ MODKEY,                       XKB_KEY_h,                   setmfact,         {.f = -0.05f} },
	{ MODKEY,                       XKB_KEY_l,                   setmfact,         {.f = +0.05f} },
	{ MODKEY,                       XKB_KEY_Return,              zoom,             {0} },
	{ MODKEY|WLR_MODIFIER_SHIFT,    XKB_KEY_Q,                   killclient,       {0} },
	{ MODKEY|WLR_MODIFIER_SHIFT,    XKB_KEY_space,               view,             {0} },
	{ MODKEY,                       XKB_KEY_f,                   togglefloating,   {0} },
  //{ MODKEY,                       XKB_KEY_t,                 setlayout,        {.v = &layouts[0]} },
	//{ MODKEY,                       XKB_KEY_f,                   setlayout,        {.v = &layouts[1]} },
	//{ MODKEY,                       XKB_KEY_m,                   setlayout,        {.v = &layouts[2]} },
	{ MODKEY,                       XKB_KEY_f,                   togglefullscreen, {0} },
	{ MODKEY,                       XKB_KEY_0,                   view,             {.ui = ~0} },
	{ MODKEY|WLR_MODIFIER_SHIFT,    XKB_KEY_parenright,          tag,              {.ui = ~0} },
	{ MODKEY,                       XKB_KEY_comma,               focusmon,         {.i = WLR_DIRECTION_LEFT} },
	{ MODKEY,                       XKB_KEY_period,              focusmon,         {.i = WLR_DIRECTION_RIGHT} },
	{ MODKEY|WLR_MODIFIER_SHIFT,    XKB_KEY_less,                tagmon,           {.i = WLR_DIRECTION_LEFT} },
	{ MODKEY|WLR_MODIFIER_SHIFT,    XKB_KEY_greater,             tagmon,           {.i = WLR_DIRECTION_RIGHT} },

  { WLR_MODIFIER_ALT,             XKB_KEY_Up,                  spawn,            {.v = volupcmd } },
  { WLR_MODIFIER_ALT,             XKB_KEY_Down,                spawn,            {.v = voldowncmd } },
  { WLR_MODIFIER_ALT,             XKB_KEY_Left,                spawn,            {.v = micdowncmd } },
  { WLR_MODIFIER_ALT,             XKB_KEY_Right,               spawn,            {.v = micupcmd } },
  { WLR_MODIFIER_ALT,             XKB_KEY_End,                 spawn,            {.v = mutemiccmd } },
  { WLR_MODIFIER_ALT,             XKB_KEY_bracketleft,         spawn,            {.v = flipcmd } },
  { WLR_MODIFIER_ALT|MODKEY,      XKB_KEY_Up,                  spawn,            {.v = gammastepcmd } },

  { 0,                            XKB_KEY_XF86AudioMedia,      spawn,            {.v = mediaplaypausecmd } },
  { 0,                            XKB_KEY_XF86AudioPlay,       spawn,            {.v = mediaplaypausecmd } },
  { 0,                            XKB_KEY_XF86AudioPrev,       spawn,            {.v = mediaprevcmd } },
  { 0,                            XKB_KEY_XF86AudioNext,       spawn,            {.v = medianextcmd } },


	TAGKEYS(          XKB_KEY_1, XKB_KEY_exclam,                     0),
	TAGKEYS(          XKB_KEY_2, XKB_KEY_at,                         1),
	TAGKEYS(          XKB_KEY_3, XKB_KEY_numbersign,                 2),
	TAGKEYS(          XKB_KEY_4, XKB_KEY_dollar,                     3),
	TAGKEYS(          XKB_KEY_5, XKB_KEY_percent,                    4),
	TAGKEYS(          XKB_KEY_6, XKB_KEY_asciicircum,                5),
	TAGKEYS(          XKB_KEY_7, XKB_KEY_ampersand,                  6),
	TAGKEYS(          XKB_KEY_8, XKB_KEY_asterisk,                   7),
	TAGKEYS(          XKB_KEY_9, XKB_KEY_parenleft,                  8),

	/* Ctrl-Alt-Backspace and Ctrl-Alt-Fx used to be handled by X server */
	{ WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT,XKB_KEY_Terminate_Server, quit, {0} },
	/* Ctrl-Alt-Fx is used to switch to another VT, if you don't know what a VT is
	 * do not remove them.
	 */
#define CHVT(n) { WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT,XKB_KEY_XF86Switch_VT_##n, chvt, {.ui = (n)} }
	CHVT(1), CHVT(2), CHVT(3), CHVT(4), CHVT(5), CHVT(6),
	CHVT(7), CHVT(8), CHVT(9), CHVT(10), CHVT(11), CHVT(12),
};

static const Button buttons[] = {
	{ MODKEY, BTN_LEFT,   moveresize,     {.ui = CurMove} },
	{ MODKEY, BTN_MIDDLE, togglefloating, {0} },
	{ MODKEY, BTN_RIGHT,  moveresize,     {.ui = CurResize} },
};
