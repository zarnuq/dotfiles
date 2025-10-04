#!/bin/sh
sudo ip link add name br0 type bridge
sudo ip link set br0 up
sudo ip link set wlp2s0 master br0
sudo ip addr add 192.168.1.10/24 dev br0
