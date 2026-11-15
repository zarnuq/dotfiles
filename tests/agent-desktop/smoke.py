#!/usr/bin/python3
"""Exercise real GUI input in an already-running agent desktop; never host input."""
import argparse
import json
from pathlib import Path
import os
import runpy
import subprocess
import struct
import sys
import tempfile
import time
import uuid

SCRIPT = Path(__file__).resolve()
ROOT = SCRIPT.parents[2]


def app(artifacts, title):
    import gi
    gi.require_version('Gtk', '3.0')
    from gi.repository import Gtk, Gdk
    window = Gtk.Window(title=title)
    window.set_default_size(800, 600)
    view = Gtk.TextView()
    view.set_name('agent-input-pad')
    view.add_events(Gdk.EventMask.POINTER_MOTION_MASK | Gdk.EventMask.BUTTON_PRESS_MASK |
                    Gdk.EventMask.BUTTON_RELEASE_MASK | Gdk.EventMask.SCROLL_MASK)
    (artifacts/'events.jsonl').write_text('')

    def event(_, ev):
        item = dict(type=int(ev.type), x=getattr(ev, 'x', None), y=getattr(ev, 'y', None))
        with open(artifacts/'events.jsonl', 'a') as file:
            file.write(json.dumps(item)+'\n')
        return False

    for name in ('motion-notify-event', 'button-press-event', 'button-release-event', 'scroll-event'):
        view.connect(name, event)

    def changed(buffer):
        start, end = buffer.get_bounds()
        (artifacts/'input.txt').write_text(buffer.get_text(start, end, True))

    view.get_buffer().connect('changed', changed)
    window.add(view)
    window.connect('destroy', Gtk.main_quit)
    window.show_all()
    view.grab_focus()
    Gtk.main()


def smoke(artifacts):
    m = runpy.run_path(str(ROOT/'de/.local/bin/agent-desk'))
    q = m['request']
    status = q('status')
    if not status['running'] or status['paused']:
        raise RuntimeError('start the desktop and explicitly hand control to the agent first')
    checks = []
    window_id = None

    def check(name, condition):
        if not condition:
            raise AssertionError(name)
        checks.append(name)
        print('PASS', name, flush=True)

    def wait(predicate, timeout=6):
        deadline = time.monotonic()+timeout
        while time.monotonic() < deadline:
            if predicate():
                return True
            time.sleep(.05)
        return False

    def text_is(expected):
        return (artifacts/'input.txt').exists() and (artifacts/'input.txt').read_text() == expected

    def window():
        return next(w for w in q('windows')['windows'] if w['id'] == window_id)

    title = 'Agent desktop acceptance '+uuid.uuid4().hex[:8]
    try:
        q('run', ['--', '/usr/bin/python3', str(SCRIPT), '--app', str(artifacts), title])
        check('app maps only in the agent desktop', wait(lambda: any(w['title'] == title for w in q('windows')['windows'])))
        window_id = next(w['id'] for w in q('windows')['windows'] if w['title'] == title)
        q('focus', [str(window_id)])
        literal = ' leading space, café λ\nsecond line'
        q('type', [literal])
        check('leading spaces, Unicode and multiline typing', wait(lambda: text_is(literal)))
        q('key', ['Ctrl+a'])
        q('type', ['isolated'])
        check('real Ctrl+a replacement', wait(lambda: text_is('isolated')))
        q('key', ['Shift+a'])  # WayVNC drops Shift for a level-1 keysym
        check('Shift chords reach the app', wait(lambda: text_is('isolatedA')))
        q('clip', ['set', '--', 'clip café'])
        check('private clipboard round trip', q('clip', ['get'])['output'] == 'clip café')
        q('key', ['Ctrl+a'])
        q('key', ['Ctrl+v'])
        check('private clipboard pastes into the app', wait(lambda: text_is('clip café')))
        desk = str(ROOT/'de/.local/bin/agent-desk')
        check('wait-idle returns on a still screen',
              subprocess.run([desk, 'wait-idle', '--timeout', '10'], capture_output=True).returncode == 0)
        found = subprocess.run([desk, 'find-text', 'clip café'], capture_output=True, text=True)
        check('OCR finds text typed into the app', found.returncode == 0 and len(found.stdout.split()) == 2)
        q('shot', [str(artifacts/'same-a.png')])
        q('shot', [str(artifacts/'same-b.png')])
        check('compare passes identical frames',
              subprocess.run([desk, 'compare', str(artifacts/'same-a.png'), str(artifacts/'same-b.png')],
                             capture_output=True).returncode == 0)
        q('geometry', [str(window_id), '100', '80', '800', '600'])
        check('window geometry', wait(lambda: window()['x'] == 100 and window()['width'] == 800))
        q('shot', ['--window', str(window_id), str(artifacts/'window.png')])
        size = struct.unpack('>II', (artifacts/'window.png').read_bytes()[16:24])
        check('window screenshot is cropped to the window', size == (window()['width'], window()['height']))
        found = subprocess.run([str(ROOT/'de/.local/bin/agent-desk'), 'wait-window', title, '--timeout', '2'],
                               capture_output=True, text=True)
        check('wait-window finds the app', found.stdout.strip() == str(window_id))
        token = q('claim', ['smoke', '30'])['token']
        try:
            q('key', ['Escape'])
            raise AssertionError('claim did not refuse an unclaimed caller')
        except RuntimeError:
            pass
        os.environ['AGENT_DESK_CLAIM'] = token
        q('key', ['Escape'])
        q('unclaim')
        del os.environ['AGENT_DESK_CLAIM']
        check('claim refuses other callers and admits its holder', q('status')['claim'] is None)
        q('record', ['start', str(artifacts/'smoke.mp4')])
        time.sleep(1.5)
        q('record', ['stop'])
        check('recording writes a video', (artifacts/'smoke.mp4').stat().st_size > 1000)
        url = 'https://example.invalid/smoke-' + uuid.uuid4().hex[:6]
        q('run', ['--', 'xdg-open', url])
        opened = Path(q('status')['runtime'])/'opened.log'
        check('links are logged, not opened', wait(lambda: opened.exists() and url in opened.read_text()))
        q('desktop', [str(window()['desktop'] % 9 + 1)])  # any desktop but the app's
        check('hidden windows remain listed', wait(lambda: not window()['visible']))
        # sloppy_focus (the real config): park the pointer on the app, or the
        # window under it takes focus back on the next manage cycle.
        q('move', ['200', '200'])
        q('focus', [str(window_id)])
        check('focus restores its desktop', wait(lambda: window()['visible'] and window()['focused']))
        q('move', ['200', '200'])
        q('click', ['left'])
        q('drag', ['200', '200', '400', '200'])
        q('scroll', ['down', '2'])
        time.sleep(.2)
        events = [json.loads(line) for line in (artifacts/'events.jsonl').read_text().splitlines()]
        for code, name in ((3, 'motion'), (4, 'button press'), (7, 'button release'), (31, 'scroll')):
            check('real '+name, any(e['type'] == code for e in events))
        xs = [e['x'] for e in events if e['x'] is not None]
        check('pointer movement has no host scale correction', max(xs)-min(xs) == 200)
        q('pause')
        try:
            q('type', ['must not type'])
            raise AssertionError('pause accepted typing')
        except RuntimeError as error:
            check('pause blocks input', 'paused' in str(error))
        q('shot', [str(artifacts/'screen.png')])
        header = (artifacts/'screen.png').read_bytes()[:24]
        check('paused screenshot uses the virtual output', struct.unpack('>II', header[16:24]) == (status['width'], status['height']))
        q('resume')
        result = q('view', ['--control', '--no-open'])
        check('manual handoff pauses the agent', q('status')['paused'] and q('status')['manual'])
        manual = m['RFB'](Path(result['socket']))
        try:
            manual.key(m['keysym']('Ctrl'), True)
            manual.key(ord('a'), True)
            manual.key(ord('a'), False)
            manual.key(m['keysym']('Ctrl'), False)
            for char in 'manual handoff':
                manual.key(ord(char), True)
                manual.key(ord(char), False)
            check('manual viewer input reaches the real app', wait(lambda: text_is('manual handoff')))
            manual.key(m['keysym']('Ctrl'), True)
            q('resume')
            check('resume revokes manual ownership', not q('status')['manual'] and not q('status')['paused'])
        finally:
            manual.close()
        q('type', [' resumed'])
        check('handoff releases held manual modifiers', wait(lambda: text_is('manual handoff resumed')))
        result = q('view', ['--no-open'])
        viewer = m['RFB'](Path(result['socket']))
        try:
            viewer.key(ord('x'), True)
            viewer.key(ord('x'), False)
            time.sleep(.2)
            check('view-only server rejects input', text_is('manual handoff resumed'))
        finally:
            viewer.close()
        accessibility = q('a11y', ['apps'])['accessibility']
        check('private accessibility contains the test app', any(n['name'] == 'smoke.py' for n in accessibility['nodes']))
        check('private accessibility address', status['runtime']+'/session/' in accessibility['bus'])
        try:
            q('focus', ['18446744073709551615'])
            raise AssertionError('stale ID accepted')
        except RuntimeError as error:
            check('stale window IDs fail', 'unknown window' in str(error))
        q('close', [str(window_id)])
        check('window closes without stopping the session', wait(lambda: all(w['id'] != window_id for w in q('windows')['windows'])) and q('status')['running'])
        window_id = None
        (artifacts/'result.json').write_text(json.dumps(dict(checks=checks, status=q('status')), indent=2)+'\n')
        print('Artifacts:', artifacts)
    finally:
        # We started with explicit agent ownership; restore it after our own test.
        if q('status')['paused']:
            q('resume')
        q('release')
        if window_id is not None and any(w['id'] == window_id for w in q('windows')['windows']):
            q('close', [str(window_id)])


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == '--app':
        app(Path(sys.argv[2]), sys.argv[3])
    else:
        parser = argparse.ArgumentParser(description=__doc__)
        parser.add_argument('--artifacts', type=Path)
        args = parser.parse_args()
        artifacts = args.artifacts or Path(tempfile.mkdtemp(prefix='agent-desk-smoke-'))
        artifacts.mkdir(parents=True, exist_ok=True)
        smoke(artifacts.absolute())
