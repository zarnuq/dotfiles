/*
 * i3_ipc.c - i3 IPC protocol implementation
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/stat.h>

#include "i3_ipc.h"
#include "bridge.h"

static char socket_path[256];

const char *
i3_ipc_get_socket_path(void)
{
	return socket_path;
}

int
i3_ipc_init(struct bridge_state *bridge)
{
	const char *runtime_dir = getenv("XDG_RUNTIME_DIR");
	if (!runtime_dir)
		runtime_dir = "/tmp";

	/* Create socket path compatible with Sway/i3 clients */
	snprintf(socket_path, sizeof(socket_path),
	         "%s/dwl-ipc.sock", runtime_dir);

	/* Remove old socket if it exists */
	unlink(socket_path);

	/* Create Unix socket */
	int sock_fd = socket(AF_UNIX, SOCK_STREAM, 0);
	if (sock_fd < 0) {
		perror("socket");
		return -1;
	}

	struct sockaddr_un addr = {0};
	addr.sun_family = AF_UNIX;
	strncpy(addr.sun_path, socket_path, sizeof(addr.sun_path) - 1);

	if (bind(sock_fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
		perror("bind");
		close(sock_fd);
		return -1;
	}

	if (listen(sock_fd, 5) < 0) {
		perror("listen");
		close(sock_fd);
		unlink(socket_path);
		return -1;
	}

	/* Set permissions */
	chmod(socket_path, 0600);

	bridge->i3_socket_fd = sock_fd;
	bridge->socket_path = strdup(socket_path);

	/* Set $SWAYSOCK for Noctalia */
	setenv("SWAYSOCK", socket_path, 1);
	setenv("I3SOCK", socket_path, 1);

	return 0;
}

void
i3_ipc_cleanup(struct bridge_state *bridge)
{
	if (bridge->i3_socket_fd >= 0) {
		close(bridge->i3_socket_fd);
		bridge->i3_socket_fd = -1;
	}

	if (bridge->socket_path) {
		unlink(bridge->socket_path);
	}
}

int
i3_ipc_send_reply(int fd, uint32_t message_type, const char *payload)
{
	struct i3_ipc_header hdr;
	memcpy(hdr.magic, I3_IPC_MAGIC, I3_IPC_MAGIC_LEN);
	hdr.length = payload ? strlen(payload) : 0;
	hdr.type = message_type;

	if (write(fd, &hdr, sizeof(hdr)) != sizeof(hdr))
		return -1;

	if (hdr.length > 0 && payload) {
		if (write(fd, payload, hdr.length) != (ssize_t)hdr.length)
			return -1;
	}

	return 0;
}

int
i3_ipc_send_event(struct i3_subscriber *sub, uint32_t event_type,
                  const char *payload)
{
	return i3_ipc_send_reply(sub->fd, event_type, payload);
}

int
i3_ipc_add_subscriber(struct bridge_state *bridge, int fd)
{
	if (bridge->num_subscribers >= MAX_SUBSCRIBERS) {
		close(fd);
		return -1;
	}

	struct i3_subscriber *sub = calloc(1, sizeof(struct i3_subscriber));
	if (!sub) {
		close(fd);
		return -1;
	}

	sub->fd = fd;
	sub->subscribed_events = 0;
	bridge->subscribers[bridge->num_subscribers++] = sub;

	return 0;
}

void
i3_ipc_remove_subscriber(struct bridge_state *bridge, struct i3_subscriber *sub)
{
	for (int i = 0; i < bridge->num_subscribers; i++) {
		if (bridge->subscribers[i] == sub) {
			/* Shift remaining subscribers */
			for (int j = i; j < bridge->num_subscribers - 1; j++)
				bridge->subscribers[j] = bridge->subscribers[j + 1];
			bridge->num_subscribers--;

			close(sub->fd);
			free(sub);
			break;
		}
	}
}

char *
i3_ipc_gen_workspaces_json(struct bridge_state *bridge)
{
	static char json[8192];
	char *p = json;
	int len = sizeof(json);
	int n;

	n = snprintf(p, len, "[");
	p += n; len -= n;

	/* Generate workspace for each tag */
	for (int tag = 0; tag < MAX_TAGS; tag++) {
		uint32_t tag_bit = (1 << tag);
		int ws_num = tag + 1;

		/* Find which monitor has this tag active */
		struct dwl_monitor *active_mon = NULL;
		int is_visible = 0;
		int is_focused = 0;
		int is_urgent = 0;
		int num_clients = 0;

		for (int m = 0; m < bridge->num_monitors; m++) {
			struct dwl_monitor *mon = bridge->monitors[m];
			if (mon->tag_state[tag].is_active) {
				active_mon = mon;
				is_visible = 1;
				is_focused = mon->is_focused;
				is_urgent = mon->tag_state[tag].is_urgent;
				num_clients = mon->tag_state[tag].num_clients;
				break;
			}
		}

		const char *output = (active_mon && active_mon->name) ? active_mon->name : "unknown";

		if (tag > 0) {
			n = snprintf(p, len, ",");
			p += n; len -= n;
		}

		n = snprintf(p, len,
		    "{\"num\":%d,"
		    "\"name\":\"%d\","
		    "\"visible\":%s,"
		    "\"focused\":%s,"
		    "\"urgent\":%s,"
		    "\"rect\":{\"x\":0,\"y\":0,\"width\":1920,\"height\":1080},"
		    "\"output\":\"%s\"}",
		    ws_num, ws_num,
		    is_visible ? "true" : "false",
		    is_focused ? "true" : "false",
		    is_urgent ? "true" : "false",
		    output);
		p += n; len -= n;
	}

	n = snprintf(p, len, "]");

	return json;
}

char *
i3_ipc_gen_outputs_json(struct bridge_state *bridge)
{
	static char json[4096];
	char *p = json;
	int len = sizeof(json);
	int n;

	n = snprintf(p, len, "[");
	p += n; len -= n;

	for (int i = 0; i < bridge->num_monitors; i++) {
		struct dwl_monitor *mon = bridge->monitors[i];

		if (i > 0) {
			n = snprintf(p, len, ",");
			p += n; len -= n;
		}

		n = snprintf(p, len,
		    "{\"name\":\"%s\","
		    "\"active\":%s,"
		    "\"primary\":false,"
		    "\"rect\":{\"x\":0,\"y\":0,\"width\":1920,\"height\":1080},"
		    "\"current_workspace\":\"%d\"}",
		    mon->name ? mon->name : "unknown",
		    mon->is_focused ? "true" : "false",
		    tag_to_workspace_num(mon->active_tags));
		p += n; len -= n;
	}

	n = snprintf(p, len, "]");

	return json;
}

char *
i3_ipc_gen_version_json(void)
{
	static char json[256];
	snprintf(json, sizeof(json),
	    "{\"major\":4,"
	    "\"minor\":20,"
	    "\"patch\":0,"
	    "\"human_readable\":\"4.20 (dwl-i3-bridge)\","
	    "\"loaded_config_file_name\":\"dwl\"}");
	return json;
}

char *
i3_ipc_gen_tree_json(struct bridge_state *bridge)
{
	/* Simplified tree structure */
	static char json[4096];
	snprintf(json, sizeof(json),
	    "{\"id\":1,"
	    "\"type\":\"root\","
	    "\"nodes\":[]}");
	return json;
}

char *
i3_ipc_gen_inputs_json(void)
{
	/* Return empty inputs array - DWL doesn't expose input device info */
	static char json[64];
	snprintf(json, sizeof(json), "[]");
	return json;
}

int
i3_ipc_handle_message(struct bridge_state *bridge, struct i3_subscriber *sub,
                      uint32_t message_type, const char *payload,
                      uint32_t payload_len)
{
	char *response = NULL;

	switch (message_type) {
	case I3_IPC_MESSAGE_TYPE_GET_WORKSPACES:
		response = i3_ipc_gen_workspaces_json(bridge);
		break;

	case I3_IPC_MESSAGE_TYPE_GET_OUTPUTS:
		response = i3_ipc_gen_outputs_json(bridge);
		break;

	case I3_IPC_MESSAGE_TYPE_GET_VERSION:
		response = i3_ipc_gen_version_json();
		break;

	case I3_IPC_MESSAGE_TYPE_GET_TREE:
		response = i3_ipc_gen_tree_json(bridge);
		break;

	case I3_IPC_MESSAGE_TYPE_GET_INPUTS:
		response = i3_ipc_gen_inputs_json();
		break;

	case I3_IPC_MESSAGE_TYPE_SUBSCRIBE:
		/* Parse subscription payload */
		if (payload && strstr(payload, "workspace"))
			sub->subscribed_events |= I3_IPC_EVENT_WORKSPACE;
		if (payload && strstr(payload, "window"))
			sub->subscribed_events |= I3_IPC_EVENT_WINDOW;
		if (payload && strstr(payload, "output"))
			sub->subscribed_events |= I3_IPC_EVENT_OUTPUT;

		response = "{\"success\":true}";
		break;

	case I3_IPC_MESSAGE_TYPE_RUN_COMMAND:
		/* Commands not implemented yet */
		response = "[{\"success\":false}]";
		break;

	default:
		response = "{\"success\":false}";
		break;
	}

	if (response)
		return i3_ipc_send_reply(sub->fd, message_type, response);

	return 0;
}
