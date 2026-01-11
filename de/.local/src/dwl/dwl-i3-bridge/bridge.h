/*
 * bridge.h - Translation layer between DWL and i3 concepts
 */

#ifndef BRIDGE_H
#define BRIDGE_H

#include <stdint.h>
#include <wayland-client.h>

#define MAX_MONITORS 8
#define MAX_TAGS 9
#define MAX_CLIENTS 256
#define MAX_SUBSCRIBERS 32

/* Forward declarations */
struct i3_subscriber;
struct dwl_monitor;

/* Bridge state */
struct bridge_state {
	/* Wayland connection */
	struct wl_display *display;
	struct wl_registry *registry;
	void *dwl_manager;  /* zdwl_ipc_manager_v2 */

	/* Monitors (outputs) */
	struct dwl_monitor *monitors[MAX_MONITORS];
	int num_monitors;
	struct dwl_monitor *focused_monitor;

	/* i3 IPC server */
	int i3_socket_fd;
	char *socket_path;

	/* Active i3 IPC clients */
	struct i3_subscriber *subscribers[MAX_SUBSCRIBERS];
	int num_subscribers;

	/* Event tracking */
	uint32_t active_tags;
	uint32_t urgent_tags;
};

/* Monitor state */
struct dwl_monitor {
	struct wl_output *wl_output;
	void *dwl_output;  /* zdwl_ipc_output_v2 */
	struct bridge_state *bridge;

	char *name;
	uint32_t tags;
	uint32_t active_tags;
	uint32_t urgent_tags;
	uint32_t layout_idx;
	char *layout_symbol;
	char *title;
	char *appid;
	int is_focused;
	int is_fullscreen;
	int is_floating;

	/* Tag state per workspace */
	struct {
		int num_clients;
		int has_focused;
		int is_active;
		int is_urgent;
	} tag_state[MAX_TAGS];
};

/* i3 IPC subscriber (client connection) */
struct i3_subscriber {
	int fd;
	uint32_t subscribed_events;
	char buffer[8192];
	size_t buffer_len;
};

/* Bridge lifecycle */
struct bridge_state *bridge_init(void);
void bridge_destroy(struct bridge_state *bridge);
int bridge_poll(struct bridge_state *bridge);

/* Monitor management */
struct dwl_monitor *bridge_add_monitor(struct bridge_state *bridge,
                                        struct wl_output *output);
void bridge_remove_monitor(struct bridge_state *bridge,
                           struct dwl_monitor *monitor);
struct dwl_monitor *bridge_find_monitor_by_output(struct bridge_state *bridge,
                                                   struct wl_output *output);

/* Event broadcasting to i3 clients */
void bridge_broadcast_workspace_event(struct bridge_state *bridge,
                                       const char *change);
void bridge_broadcast_window_event(struct bridge_state *bridge,
                                    const char *change);

/* Tag to workspace conversion */
int tag_to_workspace_num(uint32_t tag_bit);
const char *tag_to_workspace_name(uint32_t tag_bit);

#endif /* BRIDGE_H */
