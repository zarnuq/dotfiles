/*
 * dwl_ipc.c - DWL Wayland IPC client
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wayland-client.h>

#include "dwl_ipc.h"
#include "bridge.h"
#include "dwl-ipc-unstable-v2-client-protocol.h"

/* Wayland registry listener */
static void
registry_handle_global(void *data, struct wl_registry *registry,
                       uint32_t name, const char *interface, uint32_t version)
{
	struct bridge_state *bridge = data;

	if (strcmp(interface, zdwl_ipc_manager_v2_interface.name) == 0) {
		bridge->dwl_manager = wl_registry_bind(registry, name,
		    &zdwl_ipc_manager_v2_interface, 2);
		fprintf(stderr, "dwl-i3-bridge: Found DWL IPC manager\n");
	} else if (strcmp(interface, wl_output_interface.name) == 0) {
		struct wl_output *output = wl_registry_bind(registry, name,
		    &wl_output_interface, 1);
		struct dwl_monitor *mon = bridge_add_monitor(bridge, output);

		/* Get DWL IPC output interface */
		if (bridge->dwl_manager && mon) {
			struct zdwl_ipc_manager_v2 *manager = bridge->dwl_manager;
			mon->dwl_output = zdwl_ipc_manager_v2_get_output(manager, output);
		}
	}
}

static void
registry_handle_global_remove(void *data, struct wl_registry *registry,
                               uint32_t name)
{
	/* TODO: Handle output removal */
}

static const struct wl_registry_listener registry_listener = {
	.global = registry_handle_global,
	.global_remove = registry_handle_global_remove,
};

/* DWL IPC manager listeners */
static void
dwl_ipc_manager_handle_tags(void *data, struct zdwl_ipc_manager_v2 *manager,
                             uint32_t amount)
{
	fprintf(stderr, "dwl-i3-bridge: DWL has %u tags\n", amount);
}

static void
dwl_ipc_manager_handle_layout(void *data, struct zdwl_ipc_manager_v2 *manager,
                               const char *name)
{
	fprintf(stderr, "dwl-i3-bridge: DWL layout: %s\n", name);
}

static const struct zdwl_ipc_manager_v2_listener dwl_manager_listener = {
	.tags = dwl_ipc_manager_handle_tags,
	.layout = dwl_ipc_manager_handle_layout,
};

/* DWL IPC output listeners */
static void
dwl_output_handle_active(void *data, struct zdwl_ipc_output_v2 *output,
                         uint32_t active)
{
	struct dwl_monitor *mon = data;
	mon->is_focused = (active != 0);

	if (active)
		mon->bridge->focused_monitor = mon;
}

static void
dwl_output_handle_tag(void *data, struct zdwl_ipc_output_v2 *output,
                      uint32_t tag, uint32_t state, uint32_t clients,
                      uint32_t focused)
{
	struct dwl_monitor *mon = data;

	if (tag >= MAX_TAGS)
		return;

	mon->tag_state[tag].num_clients = clients;
	mon->tag_state[tag].has_focused = (focused != 0);
	mon->tag_state[tag].is_active = (state & ZDWL_IPC_OUTPUT_V2_TAG_STATE_ACTIVE);
	mon->tag_state[tag].is_urgent = (state & ZDWL_IPC_OUTPUT_V2_TAG_STATE_URGENT);

	if (mon->tag_state[tag].is_active) {
		mon->active_tags |= (1 << tag);
	}
}

static void
dwl_output_handle_layout(void *data, struct zdwl_ipc_output_v2 *output,
                         uint32_t layout)
{
	struct dwl_monitor *mon = data;
	mon->layout_idx = layout;
}

static void
dwl_output_handle_title(void *data, struct zdwl_ipc_output_v2 *output,
                        const char *title)
{
	struct dwl_monitor *mon = data;
	free(mon->title);
	mon->title = title ? strdup(title) : NULL;
}

static void
dwl_output_handle_appid(void *data, struct zdwl_ipc_output_v2 *output,
                        const char *appid)
{
	struct dwl_monitor *mon = data;
	free(mon->appid);
	mon->appid = appid ? strdup(appid) : NULL;
}

static void
dwl_output_handle_layout_symbol(void *data, struct zdwl_ipc_output_v2 *output,
                                 const char *layout)
{
	struct dwl_monitor *mon = data;
	free(mon->layout_symbol);
	mon->layout_symbol = layout ? strdup(layout) : NULL;
}

static void
dwl_output_handle_frame(void *data, struct zdwl_ipc_output_v2 *output)
{
	struct dwl_monitor *mon = data;

	/* Frame marks end of atomic update - broadcast workspace event */
	bridge_broadcast_workspace_event(mon->bridge, "focus");
}

static void
dwl_output_handle_fullscreen(void *data, struct zdwl_ipc_output_v2 *output,
                              uint32_t is_fullscreen)
{
	struct dwl_monitor *mon = data;
	mon->is_fullscreen = (is_fullscreen != 0);
}

static void
dwl_output_handle_floating(void *data, struct zdwl_ipc_output_v2 *output,
                            uint32_t is_floating)
{
	struct dwl_monitor *mon = data;
	mon->is_floating = (is_floating != 0);
}

static void
dwl_output_handle_toggle_visibility(void *data, struct zdwl_ipc_output_v2 *output)
{
	/* Bar visibility toggle - not needed for bridge */
}

static const struct zdwl_ipc_output_v2_listener dwl_output_listener = {
	.active = dwl_output_handle_active,
	.tag = dwl_output_handle_tag,
	.layout = dwl_output_handle_layout,
	.title = dwl_output_handle_title,
	.appid = dwl_output_handle_appid,
	.layout_symbol = dwl_output_handle_layout_symbol,
	.frame = dwl_output_handle_frame,
	.fullscreen = dwl_output_handle_fullscreen,
	.floating = dwl_output_handle_floating,
	.toggle_visibility = dwl_output_handle_toggle_visibility,
};

int
dwl_ipc_init(struct bridge_state *bridge)
{
	bridge->display = wl_display_connect(NULL);
	if (!bridge->display) {
		fprintf(stderr, "dwl-i3-bridge: Failed to connect to Wayland display\n");
		return -1;
	}

	bridge->registry = wl_display_get_registry(bridge->display);
	wl_registry_add_listener(bridge->registry, &registry_listener, bridge);

	/* Roundtrip to get globals */
	wl_display_roundtrip(bridge->display);

	if (!bridge->dwl_manager) {
		fprintf(stderr, "dwl-i3-bridge: DWL IPC manager not found\n");
		return -1;
	}

	/* Add listener to DWL manager */
	struct zdwl_ipc_manager_v2 *manager = bridge->dwl_manager;
	zdwl_ipc_manager_v2_add_listener(manager, &dwl_manager_listener, bridge);

	/* Add listeners to all output interfaces */
	for (int i = 0; i < bridge->num_monitors; i++) {
		struct dwl_monitor *mon = bridge->monitors[i];
		if (mon->dwl_output) {
			struct zdwl_ipc_output_v2 *output = mon->dwl_output;
			zdwl_ipc_output_v2_add_listener(output, &dwl_output_listener, mon);
		}
	}

	/* Another roundtrip to get initial state */
	wl_display_roundtrip(bridge->display);

	return 0;
}

void
dwl_ipc_cleanup(struct bridge_state *bridge)
{
	if (bridge->dwl_manager) {
		struct zdwl_ipc_manager_v2 *manager = bridge->dwl_manager;
		zdwl_ipc_manager_v2_destroy(manager);
	}

	if (bridge->registry)
		wl_registry_destroy(bridge->registry);

	if (bridge->display) {
		wl_display_disconnect(bridge->display);
		bridge->display = NULL;
	}
}

int
dwl_ipc_dispatch(struct bridge_state *bridge, int timeout)
{
	wl_display_dispatch_pending(bridge->display);
	wl_display_flush(bridge->display);
	return 0;
}
