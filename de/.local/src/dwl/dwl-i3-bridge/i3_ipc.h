/*
 * i3_ipc.h - i3 IPC protocol implementation (Unix socket server)
 */

#ifndef I3_IPC_H
#define I3_IPC_H

#include <stdint.h>
#include "bridge.h"

/* i3 IPC message types */
#define I3_IPC_MAGIC "i3-ipc"
#define I3_IPC_MAGIC_LEN 6

/* Message type codes */
#define I3_IPC_MESSAGE_TYPE_RUN_COMMAND       0
#define I3_IPC_MESSAGE_TYPE_GET_WORKSPACES    1
#define I3_IPC_MESSAGE_TYPE_SUBSCRIBE         2
#define I3_IPC_MESSAGE_TYPE_GET_OUTPUTS       3
#define I3_IPC_MESSAGE_TYPE_GET_TREE          4
#define I3_IPC_MESSAGE_TYPE_GET_MARKS         5
#define I3_IPC_MESSAGE_TYPE_GET_BAR_CONFIG    6
#define I3_IPC_MESSAGE_TYPE_GET_VERSION       7
#define I3_IPC_MESSAGE_TYPE_GET_BINDING_MODES 8
#define I3_IPC_MESSAGE_TYPE_GET_CONFIG        9
#define I3_IPC_MESSAGE_TYPE_SEND_TICK         10
#define I3_IPC_MESSAGE_TYPE_SYNC              11
#define I3_IPC_MESSAGE_TYPE_GET_BINDING_STATE 12
#define I3_IPC_MESSAGE_TYPE_GET_INPUTS        100  /* Sway extension */

/* Event type codes (bit 31 set) */
#define I3_IPC_EVENT_WORKSPACE           0x80000000
#define I3_IPC_EVENT_OUTPUT              0x80000001
#define I3_IPC_EVENT_MODE                0x80000002
#define I3_IPC_EVENT_WINDOW              0x80000003
#define I3_IPC_EVENT_BARCONFIG_UPDATE    0x80000004
#define I3_IPC_EVENT_BINDING             0x80000005
#define I3_IPC_EVENT_SHUTDOWN            0x80000006
#define I3_IPC_EVENT_TICK                0x80000007

/* i3 IPC message header */
struct i3_ipc_header {
	char magic[6];      /* "i3-ipc" */
	uint32_t length;    /* payload length */
	uint32_t type;      /* message type */
} __attribute__((packed));

/* Initialize i3 IPC server */
int i3_ipc_init(struct bridge_state *bridge);
void i3_ipc_cleanup(struct bridge_state *bridge);
const char *i3_ipc_get_socket_path(void);

/* Handle i3 IPC messages */
int i3_ipc_handle_message(struct bridge_state *bridge,
                          struct i3_subscriber *sub,
                          uint32_t message_type,
                          const char *payload,
                          uint32_t payload_len);

/* Send i3 IPC reply */
int i3_ipc_send_reply(int fd, uint32_t message_type, const char *payload);

/* Send i3 IPC event to subscriber */
int i3_ipc_send_event(struct i3_subscriber *sub, uint32_t event_type,
                      const char *payload);

/* Add/remove subscribers */
int i3_ipc_add_subscriber(struct bridge_state *bridge, int fd);
void i3_ipc_remove_subscriber(struct bridge_state *bridge,
                               struct i3_subscriber *sub);

/* Generate JSON responses */
char *i3_ipc_gen_workspaces_json(struct bridge_state *bridge);
char *i3_ipc_gen_outputs_json(struct bridge_state *bridge);
char *i3_ipc_gen_version_json(void);
char *i3_ipc_gen_tree_json(struct bridge_state *bridge);
char *i3_ipc_gen_inputs_json(void);

#endif /* I3_IPC_H */
