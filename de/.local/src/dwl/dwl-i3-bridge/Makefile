# Makefile for dwl-i3-bridge

.POSIX:

VERSION = 0.1

# Paths
PREFIX = /usr/local
BINDIR = $(PREFIX)/bin

# Compiler flags
CFLAGS = -std=c99 -Wall -Wextra -pedantic -D_POSIX_C_SOURCE=200809L \
         -DVERSION=\"$(VERSION)\" $(shell pkg-config --cflags wayland-client)
LDFLAGS = $(shell pkg-config --libs wayland-client)

# Source files
SRCS = main.c bridge.c i3_ipc.c dwl_ipc.c
OBJS = $(SRCS:.c=.o)
HDRS = bridge.h i3_ipc.h dwl_ipc.h

# Wayland protocol (client-side)
PROTO_SRC = dwl-ipc-unstable-v2-client-protocol.c
PROTO_HDR = dwl-ipc-unstable-v2-client-protocol.h
PROTO_OBJ = dwl-ipc-unstable-v2-client-protocol.o

TARGET = dwl-i3-bridge

all: $(TARGET)

$(TARGET): $(OBJS) $(PROTO_OBJ)
	$(CC) -o $@ $(OBJS) $(PROTO_OBJ) $(LDFLAGS)

%.o: %.c $(HDRS) $(PROTO_HDR)
	$(CC) $(CFLAGS) -c $<

$(PROTO_HDR):
	wayland-scanner client-header ../protocols/dwl-ipc-unstable-v2.xml $@

$(PROTO_SRC):
	wayland-scanner private-code ../protocols/dwl-ipc-unstable-v2.xml $@

$(PROTO_OBJ): $(PROTO_SRC) $(PROTO_HDR)
	$(CC) $(CFLAGS) -c $(PROTO_SRC) -o $@

clean:
	rm -f $(TARGET) $(OBJS) $(PROTO_OBJ) $(PROTO_HDR) $(PROTO_SRC)

install: $(TARGET)
	mkdir -p $(DESTDIR)$(BINDIR)
	cp -f $(TARGET) $(DESTDIR)$(BINDIR)
	chmod 755 $(DESTDIR)$(BINDIR)/$(TARGET)

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/$(TARGET)

.PHONY: all clean install uninstall
