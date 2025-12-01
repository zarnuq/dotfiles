#define HEX_COLOR(hex)				\
	{ .red   = ((hex >> 24) & 0xff) * 257,	\
	  .green = ((hex >> 16) & 0xff) * 257,	\
	  .blue  = ((hex >> 8) & 0xff) * 257,	\
	  .alpha = (hex & 0xff) * 257 }

// use ipc functionality
static bool ipc = true;
// initially hide all bars
static bool hidden = false;
// initially draw all bars at the bottom
static bool bottom = false;
// hide vacant tags
static bool hide_vacant = true;
// vertical pixel padding above and below text
static uint32_t vertical_padding = 0;
// allow in-line color commands in status text
static bool status_commands = true;
// center title text
static bool center_title = false;
// use title space as status text element
static bool custom_title = false;
// title color use active colors
static bool active_color_title = true;
// scale
static uint32_t buffer_scale = 1;
// font
static char *fontstr = "JetBrainsMono Nerd Font:size=11";
// tag names
static char *tags_names[] = { "1", "2", "3", "4", "5", "6", "7", "8", "9" };

// set 16-bit colors for bar
// use either pixman_color_t struct or HEX_COLOR macro for 8-bit colors
static pixman_color_t active_fg_color =          HEX_COLOR(0xffffffff); // #cdd6f4
static pixman_color_t active_bg_color =          HEX_COLOR(0xcba6f7ff); // #cba6f7
static pixman_color_t occupied_fg_color =        HEX_COLOR(0x7f849cff); // #7f849c
static pixman_color_t occupied_bg_color =        HEX_COLOR(0x313244ff); // #313244
static pixman_color_t inactive_fg_color =        HEX_COLOR(0x7f849cff); // #7f849c
static pixman_color_t inactive_bg_color =        HEX_COLOR(0x313244ff); // #313244
static pixman_color_t urgent_fg_color =          HEX_COLOR(0x11111bff); // #11111b
static pixman_color_t urgent_bg_color =          HEX_COLOR(0xf38ba8ff); // #f38ba8
static pixman_color_t middle_bg_color =          HEX_COLOR(0x313244ff); // #313244
static pixman_color_t middle_bg_color_selected = HEX_COLOR(0xcba6f7ff); // #cba6f7

