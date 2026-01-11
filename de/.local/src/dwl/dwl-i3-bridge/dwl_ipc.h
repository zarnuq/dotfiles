/*
 * dwl_ipc.h - DWL Wayland IPC client (dwl-ipc-unstable-v2)
 */

#ifndef DWL_IPC_H
#define DWL_IPC_H

#include "bridge.h"

/* Initialize connection to DWL's Wayland IPC */
int dwl_ipc_init(struct bridge_state *bridge);
void dwl_ipc_cleanup(struct bridge_state *bridge);

/* Process DWL events */
int dwl_ipc_dispatch(struct bridge_state *bridge, int timeout);

#endif /* DWL_IPC_H */
