#!/usr/bin/python3
"""Read accessibility only on the explicit private bus. No input injection."""
import argparse
import json
import os
import gi

gi.require_version('Atspi', '2.0')
from gi.repository import Atspi

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('command', choices=('apps', 'tree'), nargs='?', default='apps')
parser.add_argument('--depth', type=int, default=4)
args = parser.parse_args()
if not os.environ.get('AT_SPI_BUS_ADDRESS') or not os.environ.get('REACH_AGENT_SOCKET'):
    parser.error('run through agent-desk a11y; private bus and session identity are required')
Atspi.init()
Atspi.set_timeout(1000, 3000)
items = []

def walk(node, path, depth):
    if len(items) >= 300:
        return
    item = {'path': path, 'name': node.get_name(), 'role': node.get_role_name()}
    try:
        states = node.get_state_set()
        item['focused'] = states.contains(Atspi.StateType.FOCUSED)
        item['active'] = states.contains(Atspi.StateType.ACTIVE)
        component = node.get_component_iface()
        if component:
            rect = component.get_extents(Atspi.CoordType.SCREEN)
            if rect.x > -100000 and rect.y > -100000:
                item['screen_bounds'] = [rect.x, rect.y, rect.width, rect.height]
            rect = component.get_extents(Atspi.CoordType.WINDOW)
            item['window_bounds'] = [rect.x, rect.y, rect.width, rect.height]
        text = node.get_text_iface()
        if text:
            item['text'] = text.get_text(0, min(text.get_character_count(), 300))
    except Exception as error:
        item['unavailable'] = str(error)
    items.append(item)
    if depth > 0:
        for index in range(min(node.get_child_count(), 100)):
            child = node.get_child_at_index(index)
            if child:
                walk(child, f'{path}/{index}', depth - 1)

root = Atspi.get_desktop(0)
for index in range(root.get_child_count()):
    app = root.get_child_at_index(index)
    if app:
        walk(app, str(index), min(max(args.depth, 0), 8) if args.command == 'tree' else 0)
print(json.dumps({'bus': os.environ['AT_SPI_BUS_ADDRESS'], 'nodes': items}, ensure_ascii=False))
