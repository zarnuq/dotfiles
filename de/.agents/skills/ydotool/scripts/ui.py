#!/usr/bin/python3
"""Find widgets through AT-SPI and act on them with ydotool.

Coordinates are screen pixels, the same as a grim screenshot. On Wayland
AT-SPI reports positions relative to the client surface, so a widget's screen
position is: extents - surface margin (CSD shadow) + window origin.
Run with /usr/bin/python3: the Nix python lacks the gi bindings.
"""
import argparse
import os
import re
import subprocess
import sys
import time

import gi
gi.require_version('Atspi', '2.0')
from gi.repository import Atspi

YDOTOOL = '/home/miles/.nix-profile/bin/ydotool'
# ponytail: measured pointer gain and window origin for a master/sole window on
# eDP-1 below the 18 px bar; override per layout with the env knobs.
SCALE = float(os.environ.get('YDOTOOL_SCALE', '2'))
ORIGIN = tuple(int(v) for v in os.environ.get('UI_ORIGIN', '0,18').split(','))
BUTTONS = {'left': '0xC0', 'right': '0xC1', 'middle': '0xC2'}
HIDDEN = -2147483648
MAX_CHILDREN = 2000


def ydotool(*args):
    env = {**os.environ}
    env.setdefault('YDOTOOL_SOCKET', '/run/ydotoold/socket')
    subprocess.run([YDOTOOL, *args], env=env, check=True, stdout=subprocess.DEVNULL)


def move(x, y):
    ydotool('mousemove', '--absolute', '-x', str(round(x / SCALE)), '-y', str(round(y / SCALE)))


def click(x, y, button='left'):
    move(x, y)
    time.sleep(0.15)
    ydotool('click', BUTTONS[button])


def apps(pattern):
    desktop = Atspi.get_desktop(0)
    for i in range(desktop.get_child_count()):
        app = desktop.get_child_at_index(i)
        if app and re.search(pattern, app.get_name() or '', re.I):
            yield app


def extents(node):
    component = node.get_component_iface()
    box = component and component.get_extents(Atspi.CoordType.WINDOW)
    return None if not box or box.x == HIDDEN else box


def margin(toplevel):
    boxes = [extents(toplevel.get_child_at_index(i)) for i in range(toplevel.get_child_count())]
    boxes = [b for b in boxes if b]
    return (min(b.x for b in boxes), min(b.y for b in boxes)) if boxes else (0, 0)


def to_screen(node, offset):
    box = extents(node)
    return box and (box.x - offset[0] + ORIGIN[0], box.y - offset[1] + ORIGIN[1], box.width, box.height)


def walk(app, everything=False, window='.'):
    """Yield (depth, node, screen box or None, surface margin), skipping hidden subtrees unless everything."""
    for t in range(app.get_child_count()):
        top = app.get_child_at_index(t)
        if not re.search(window, top.get_name() or '', re.I):
            continue
        offset = margin(top)
        stack = [(0, top)]
        while stack:
            depth, node = stack.pop()
            try:
                showing = node.get_state_set().contains(Atspi.StateType.SHOWING)
                screen = to_screen(node, offset)
            except gi.repository.GLib.Error:
                continue
            if not (showing or everything):
                continue
            yield depth, node, screen, offset
            count = node.get_child_count()
            if count > MAX_CHILDREN:  # a Calc sheet reports 2**31 cells; use the cell command
                continue
            children = [node.get_child_at_index(i) for i in range(count)]
            stack.extend((depth + 1, c) for c in reversed(children) if c)


def describe(node, screen):
    states = node.get_state_set()
    flags = [s for s, k in (('focused', Atspi.StateType.FOCUSED), ('checked', Atspi.StateType.CHECKED),
                            ('selected', Atspi.StateType.SELECTED)) if states.contains(k)]
    where = f'{screen[0] + screen[2] // 2},{screen[1] + screen[3] // 2} {screen[2]}x{screen[3]}' if screen else '-'
    text = Atspi.Text.get_text(node, 0, min(80, Atspi.Text.get_character_count(node))) if node.get_text_iface() else ''
    value = f' = {text!r}' if text and text != node.get_name() else ''
    return f"{where:<18} {node.get_role_name()} {node.get_name()!r}{value} {' '.join(flags)}".rstrip()


def text_of(node, depth=0):
    """Own text, or the joined text of children (Writer keeps text in paragraph children)."""
    if node.get_text_iface():
        return Atspi.Text.get_text(node, 0, Atspi.Text.get_character_count(node))
    if depth > 3:
        return ''
    parts = (text_of(node.get_child_at_index(i), depth + 1) for i in range(min(node.get_child_count(), 500)))
    return '\n'.join(p for p in parts if p)


def runs(node, depth=0):
    """Yield (text, attributes) formatting runs of node and its text descendants."""
    if node.get_text_iface():
        offset, count = 0, Atspi.Text.get_character_count(node)
        while offset < count:
            attributes, start, end = Atspi.Text.get_attribute_run(node, offset, True)
            yield Atspi.Text.get_text(node, start, end), attributes
            offset = max(end, offset + 1)
    elif depth < 4:
        for i in range(min(node.get_child_count(), 500)):
            yield from runs(node.get_child_at_index(i), depth + 1)


def matches(args):
    found = []
    for app in apps(args.app):
        for _, node, screen, _ in walk(app, args.all, args.window):
            if (re.search(args.pattern, node.get_name() or '', re.I)
                    and (not args.role or node.get_role_name() == args.role)):
                found.append((node, screen))
    return found


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--app', default='.', help='application name regex (default: all)')
    parser.add_argument('--window', default='.', help='top-level window/dialog title regex (default: all)')
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('apps', help="accessible apps and their windows; 'active' marks the focused one")
    tree = sub.add_parser('tree', help='indented tree of showing widgets with screen centers')
    tree.add_argument('--named', action='store_true', help='only widgets with a name')
    sub.add_parser('focus', help='focused widget and its text')
    cell = sub.add_parser('cell', help='spreadsheet/table cell by reference, e.g. B3')
    cell.add_argument('ref')
    cell.add_argument('--click', action='store_true', help='also click its center')
    for name, helptext in (('find', 'widgets whose name matches PATTERN'),
                           ('text', 'text content of matching widgets'),
                           ('click', 'click the center of the Nth match'),
                           ('do', 'invoke the AT-SPI action of the Nth match (no real input)')):
        p = sub.add_parser(name, help=helptext)
        p.add_argument('pattern')
        p.add_argument('--role', help="exact role name, e.g. 'button', 'menu item', 'toggle button'")
        p.add_argument('--all', action='store_true', help='include widgets that are not showing')
        p.add_argument('--nth', type=int, default=0)
        p.add_argument('--button', choices=BUTTONS, default='left')
        p.add_argument('--action', default='0', help='action name or index for do')
        p.add_argument('--attrs', default='', help="for text: comma list of run attributes, e.g. 'size,weight'")
    for name in ('move', 'clickat'):
        p = sub.add_parser(name, help=f'{name} at screen pixel X Y')
        p.add_argument('x', type=int)
        p.add_argument('y', type=int)
        p.add_argument('--button', choices=BUTTONS, default='left')
    args = parser.parse_args()

    if args.command == 'apps':
        for app in apps(args.app):
            for t in range(app.get_child_count()):
                top = app.get_child_at_index(t)
                active = top.get_state_set().contains(Atspi.StateType.ACTIVE)
                print(f"{app.get_name()} | {top.get_name()}{' | active' if active else ''}")
    elif args.command == 'tree':
        for app in apps(args.app):
            print(app.get_name())
            for depth, node, screen, _ in walk(app, window=args.window):
                if node.get_name() or not args.named:
                    print('  ' * (depth + 1) + describe(node, screen))
    elif args.command == 'focus':
        for app in apps(args.app):
            for _, node, screen, _ in walk(app, window=args.window):
                if node.get_state_set().contains(Atspi.StateType.FOCUSED):
                    print(app.get_name(), describe(node, screen))
                    text = text_of(node)
                    if text:
                        print(text)
    elif args.command == 'cell':
        column, row = re.fullmatch(r'([A-Za-z]+)(\d+)', args.ref).groups()
        column = sum((ord(c) - 64) * 26 ** i for i, c in enumerate(reversed(column.upper()))) - 1
        for app in apps(args.app):
            for _, node, _, offset in walk(app, window=args.window):
                if node.get_table_iface() and node.get_child_count() > MAX_CHILDREN:
                    target = Atspi.Table.get_accessible_at(node, int(row) - 1, column)
                    screen = to_screen(target, offset)
                    print(describe(target, screen))
                    if args.click and screen:
                        click(screen[0] + screen[2] // 2, screen[1] + screen[3] // 2)
                    return
        sys.exit('no large table found; is a spreadsheet window showing?')
    elif args.command in ('move', 'clickat'):
        move(args.x, args.y) if args.command == 'move' else click(args.x, args.y, args.button)
    else:
        found = matches(args)
        if args.command == 'find':
            for node, screen in found:
                print(describe(node, screen))
        elif args.command == 'text':
            for node, _ in found:
                if not args.attrs:
                    print(text_of(node) or '')
                for text, attributes in runs(node) if args.attrs else ():
                    print(repr(text), {k: attributes.get(k) for k in args.attrs.split(',')})
        else:
            if len(found) <= args.nth:
                sys.exit(f'no match #{args.nth} for {args.pattern!r} ({len(found)} found)')
            node, screen = found[args.nth]
            print(describe(node, screen))  # before acting: the widget may vanish
            if args.command == 'do':
                if not node.get_action_iface():
                    sys.exit('widget has no actions')
                names = [Atspi.Action.get_action_name(node, i) for i in range(Atspi.Action.get_n_actions(node))]
                Atspi.Action.do_action(node, int(args.action) if args.action.isdigit() else names.index(args.action))
            elif not screen:
                sys.exit('widget is not on screen; use do, a shortcut, or open its parent first')
            else:
                click(screen[0] + screen[2] // 2, screen[1] + screen[3] // 2, args.button)

if __name__ == '__main__':
    main()
