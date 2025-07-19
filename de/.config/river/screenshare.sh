#!/bin/sh
systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
systemctl --user restart xdg-desktop-portal-wlr.service
systemctl --user restart xdg-desktop-portal.service

