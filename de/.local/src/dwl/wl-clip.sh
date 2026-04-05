#!/bin/bash
wl-clip-persist -c regular &
someblocks -p | dwlb -status-stdin all &
