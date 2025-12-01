static char delim[] = "|";
static unsigned int delimLen = 1;

static const Block blocks[] = {
	/* Icon	Command					Interval	Signal */
	{ "",	"$HOME/.local/src/someblocks/blocks/audio.sh",			60,		1 },
	{ "",	"pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -o '[0-9]\\+%' | head -1",	1,	1 },
	{ "",	"$HOME/.local/src/someblocks/blocks/mic.sh",			1,		2 },
	{ " ",	"top -bn1 | grep 'Cpu(s)' | awk '{print int($2 + $4)\"%\"}'",	5,	0 },
	{ " ",	"free -m | awk '/Mem:/ { print $3\"MB\" }'",	5,	0 },
	{ " ",	"date '+%a %m/%d %I:%M %p'",		1,		0 },
	{ "",	"$HOME/.local/src/someblocks/blocks/battery.sh",			30,		0 },
};
