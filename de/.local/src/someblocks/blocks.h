static char delim[] = "|";
static unsigned int delimLen = 1;

static const Block blocks[] = {
	/* Icon	Command					Interval	Signal */
    { "", "~/.local/src/someblocks/blocks/ip.sh",30,0},
	{ "",	"$HOME/.local/src/someblocks/blocks/audio.sh",60,1},
	{ "",	"pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -o '[0-9]\\+%' | head -1",1,1},
	{ "",	"$HOME/.local/src/someblocks/blocks/mic.sh",1,2},
	{ "",	"date '+%a %m/%d %I:%M %p'",1,0},
	{ "",	"$HOME/.local/src/someblocks/blocks/battery.sh",30,0},
};
