/*
 * dwl-i3-bridge - i3 IPC compatibility layer for DWL
 *
 * This daemon bridges DWL's Wayland IPC protocol to i3's IPC protocol,
 * allowing tools like Noctalia Shell to work with DWL.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <errno.h>

#include "i3_ipc.h"
#include "dwl_ipc.h"
#include "bridge.h"

static volatile sig_atomic_t running = 1;

static void
handle_signal(int sig)
{
	(void)sig;  /* Unused */
	running = 0;
}

static void
setup_signals(void)
{
	struct sigaction sa = {0};
	sa.sa_handler = handle_signal;
	sigemptyset(&sa.sa_mask);
	sa.sa_flags = 0;

	sigaction(SIGINT, &sa, NULL);
	sigaction(SIGTERM, &sa, NULL);
}

int
main(int argc, char *argv[])
{
	(void)argc;  /* Unused */
	(void)argv;  /* Unused */

	fprintf(stderr, "dwl-i3-bridge: Starting DWL to i3 IPC bridge\n");

	setup_signals();

	/* Initialize bridge state */
	struct bridge_state *bridge = bridge_init();
	if (!bridge) {
		fprintf(stderr, "dwl-i3-bridge: Failed to initialize bridge\n");
		return 1;
	}

	/* Connect to DWL's Wayland IPC */
	if (dwl_ipc_init(bridge) < 0) {
		fprintf(stderr, "dwl-i3-bridge: Failed to connect to DWL IPC\n");
		bridge_destroy(bridge);
		return 1;
	}

	/* Start i3 IPC socket server */
	if (i3_ipc_init(bridge) < 0) {
		fprintf(stderr, "dwl-i3-bridge: Failed to start i3 IPC server\n");
		dwl_ipc_cleanup(bridge);
		bridge_destroy(bridge);
		return 1;
	}

	fprintf(stderr, "dwl-i3-bridge: Bridge running (socket: %s)\n",
	        i3_ipc_get_socket_path());

	/* Main event loop */
	while (running) {
		if (bridge_poll(bridge) < 0) {
			fprintf(stderr, "dwl-i3-bridge: Error in event loop\n");
			break;
		}
	}

	fprintf(stderr, "dwl-i3-bridge: Shutting down\n");

	i3_ipc_cleanup(bridge);
	dwl_ipc_cleanup(bridge);
	bridge_destroy(bridge);

	return 0;
}
