/*
 * bridge.c - Core bridge logic and state management
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <poll.h>
#include <unistd.h>
#include <errno.h>
#include <sys/socket.h>
#include <wayland-client.h>

#include "bridge.h"
#include "i3_ipc.h"
#include "dwl_ipc.h"

struct bridge_state *
bridge_init(void)
{
	struct bridge_state *bridge = calloc(1, sizeof(struct bridge_state));
	if (!bridge)
		return NULL;

	bridge->i3_socket_fd = -1;
	return bridge;
}

void
bridge_destroy(struct bridge_state *bridge)
{
	if (!bridge)
		return;

	/* Clean up monitors */
	for (int i = 0; i < bridge->num_monitors; i++) {
		struct dwl_monitor *mon = bridge->monitors[i];
		if (mon) {
			free(mon->name);
			free(mon->layout_symbol);
			free(mon->title);
			free(mon->appid);
			free(mon);
		}
	}

	/* Clean up subscribers */
	for (int i = 0; i < bridge->num_subscribers; i++) {
		struct i3_subscriber *sub = bridge->subscribers[i];
		if (sub) {
			if (sub->fd >= 0)
				close(sub->fd);
			free(sub);
		}
	}

	free(bridge->socket_path);
	free(bridge);
}

int
bridge_poll(struct bridge_state *bridge)
{
	struct pollfd fds[MAX_SUBSCRIBERS + 2];
	int nfds = 0;

	/* Add Wayland display fd */
	fds[nfds].fd = wl_display_get_fd(bridge->display);
	fds[nfds].events = POLLIN;
	nfds++;

	/* Add i3 IPC server socket */
	if (bridge->i3_socket_fd >= 0) {
		fds[nfds].fd = bridge->i3_socket_fd;
		fds[nfds].events = POLLIN;
		nfds++;
	}

	/* Add all subscriber connections */
	/* Save count to avoid processing subscribers added during this poll */
	int num_subs_to_poll = bridge->num_subscribers;
	for (int i = 0; i < num_subs_to_poll; i++) {
		fds[nfds].fd = bridge->subscribers[i]->fd;
		fds[nfds].events = POLLIN;
		nfds++;
	}

	/* Poll with 100ms timeout */
	int ret = poll(fds, nfds, 100);
	if (ret < 0)
		return -1;

	int idx = 0;

	/* Check Wayland events */
	if (fds[idx].revents & POLLIN) {
		wl_display_dispatch(bridge->display);
	}
	idx++;

	/* Check for new i3 IPC connections */
	if (bridge->i3_socket_fd >= 0 && (fds[idx].revents & POLLIN)) {
		int client_fd = accept(bridge->i3_socket_fd, NULL, NULL);
		if (client_fd >= 0) {
			fprintf(stderr, "dwl-i3-bridge: Accepted new client (fd=%d)\n", client_fd);
			i3_ipc_add_subscriber(bridge, client_fd);
		} else {
			fprintf(stderr, "dwl-i3-bridge: Failed to accept client: %s\n", strerror(errno));
		}
	}
	if (bridge->i3_socket_fd >= 0)
		idx++;

	/* Check subscriber connections for data */
	/* Only process subscribers that were in the poll fds array */
	for (int i = num_subs_to_poll - 1; i >= 0; i--) {
		struct i3_subscriber *sub = bridge->subscribers[i];
		int sub_idx = idx + i;

		if (fds[sub_idx].revents & (POLLHUP | POLLERR)) {
			/* Client disconnected */
			fprintf(stderr, "dwl-i3-bridge: Client fd=%d disconnected\n", sub->fd);
			i3_ipc_remove_subscriber(bridge, sub);
			continue;
		}

		if (fds[sub_idx].revents & POLLIN) {
			/* Read i3 IPC message */
			struct i3_ipc_header hdr;
			ssize_t n = read(sub->fd, &hdr, sizeof(hdr));
			if (n != sizeof(hdr)) {
				fprintf(stderr, "dwl-i3-bridge: Failed to read header from fd=%d (got %zd bytes)\n", sub->fd, n);
				i3_ipc_remove_subscriber(bridge, sub);
				continue;
			}

			/* Verify magic */
			if (memcmp(hdr.magic, I3_IPC_MAGIC, I3_IPC_MAGIC_LEN) != 0) {
				i3_ipc_remove_subscriber(bridge, sub);
				continue;
			}

			/* Read payload */
			char *payload = NULL;
			if (hdr.length > 0) {
				payload = malloc(hdr.length + 1);
				if (!payload) {
					i3_ipc_remove_subscriber(bridge, sub);
					continue;
				}
				n = read(sub->fd, payload, hdr.length);
				if (n != (ssize_t)hdr.length) {
					free(payload);
					i3_ipc_remove_subscriber(bridge, sub);
					continue;
				}
				payload[hdr.length] = '\0';
			}

			/* Handle message */
			fprintf(stderr, "dwl-i3-bridge: Handling message type %u from fd=%d\n", hdr.type, sub->fd);
			i3_ipc_handle_message(bridge, sub, hdr.type, payload, hdr.length);
			free(payload);
		}
	}

	return 0;
}

struct dwl_monitor *
bridge_add_monitor(struct bridge_state *bridge, struct wl_output *output)
{
	if (bridge->num_monitors >= MAX_MONITORS)
		return NULL;

	struct dwl_monitor *mon = calloc(1, sizeof(struct dwl_monitor));
	if (!mon)
		return NULL;

	mon->wl_output = output;
	mon->bridge = bridge;
	bridge->monitors[bridge->num_monitors++] = mon;

	return mon;
}

void
bridge_remove_monitor(struct bridge_state *bridge, struct dwl_monitor *monitor)
{
	for (int i = 0; i < bridge->num_monitors; i++) {
		if (bridge->monitors[i] == monitor) {
			/* Shift remaining monitors */
			for (int j = i; j < bridge->num_monitors - 1; j++)
				bridge->monitors[j] = bridge->monitors[j + 1];
			bridge->num_monitors--;

			free(monitor->name);
			free(monitor->layout_symbol);
			free(monitor->title);
			free(monitor->appid);
			free(monitor);
			break;
		}
	}
}

struct dwl_monitor *
bridge_find_monitor_by_output(struct bridge_state *bridge, struct wl_output *output)
{
	for (int i = 0; i < bridge->num_monitors; i++) {
		if (bridge->monitors[i]->wl_output == output)
			return bridge->monitors[i];
	}
	return NULL;
}

void
bridge_broadcast_workspace_event(struct bridge_state *bridge, const char *change)
{
	static char json[2048];

	/* Find the focused workspace */
	int focused_ws = 1;
	const char *output = "unknown";

	if (bridge->focused_monitor) {
		focused_ws = tag_to_workspace_num(bridge->focused_monitor->active_tags);
		output = bridge->focused_monitor->name;
	}

	snprintf(json, sizeof(json),
	    "{\"change\":\"%s\","
	    "\"current\":{\"num\":%d,\"name\":\"%d\",\"focused\":true,\"output\":\"%s\"}}",
	    change, focused_ws, focused_ws, output);

	/* Send to all subscribed clients */
	for (int i = 0; i < bridge->num_subscribers; i++) {
		struct i3_subscriber *sub = bridge->subscribers[i];
		if (sub->subscribed_events & I3_IPC_EVENT_WORKSPACE) {
			i3_ipc_send_event(sub, I3_IPC_EVENT_WORKSPACE, json);
		}
	}
}

void
bridge_broadcast_window_event(struct bridge_state *bridge, const char *change)
{
	static char json[2048];

	/* Simple window event */
	snprintf(json, sizeof(json),
	    "{\"change\":\"%s\",\"container\":{}}",
	    change);

	/* Send to all subscribed clients */
	for (int i = 0; i < bridge->num_subscribers; i++) {
		struct i3_subscriber *sub = bridge->subscribers[i];
		if (sub->subscribed_events & I3_IPC_EVENT_WINDOW) {
			i3_ipc_send_event(sub, I3_IPC_EVENT_WINDOW, json);
		}
	}
}

int
tag_to_workspace_num(uint32_t tag_bit)
{
	/* Convert tag bitmask to workspace number (1-9) */
	for (int i = 0; i < MAX_TAGS; i++) {
		if (tag_bit & (1 << i))
			return i + 1;
	}
	return 1;
}

const char *
tag_to_workspace_name(uint32_t tag_bit)
{
	static char name[32];
	snprintf(name, sizeof(name), "%d", tag_to_workspace_num(tag_bit));
	return name;
}
