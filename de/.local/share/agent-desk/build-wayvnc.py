#!/usr/bin/python3
"""Build a private cursor-capture compatibility copy from Portage's cached source.

No downloads, Git commands, system installs, or elevation. Run after installing
WayVNC's build dependencies through Portage. Leaves /usr/bin/wayvnc unchanged.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile

VERSION = '0.10.1'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--archive', type=Path, default=Path(f'/var/cache/distfiles/wayvnc-{VERSION}.tar.gz'))
parser.add_argument('--output', type=Path, default=Path(os.environ.get('XDG_CACHE_HOME', str(Path.home()/'.cache'))) / 'agent-desk/wayvnc-compat')
args = parser.parse_args()
if not args.archive.is_file():
    parser.error(f'missing cached source {args.archive}; install gui-apps/wayvnc first')
output = args.output.expanduser().absolute()
output.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix='agent-wayvnc-') as temp:
    root = Path(temp)
    with tarfile.open(args.archive) as archive:
        archive.extractall(root, filter='data')
    source = root / f'wayvnc-{VERSION}'
    main = source / 'src/main.c'
    text = main.read_text()
    needle = '\tnvnc_log(NVNC_LOG_DEBUG, "Configuring cursor capturing");'
    if text.count(needle) != 1:
        raise RuntimeError('unexpected WayVNC source; review compatibility patch')
    text = text.replace(needle, '''\t/* river 0.4.8 assumes capture sources are outputs or windows.
\t * Skip separate cursor capture; -r renders the cursor in the output. */
\tif (getenv("WAYVNC_NO_CURSOR_CAPTURE"))
\t\treturn false;
''' + needle)
    main.write_text(text)
    meson = source / 'meson.build'
    text = meson.read_text()
    # Release tarballs don't need VCS discovery. The owner disallows Git calls,
    # including build-system invocations of Git.
    start = text.index("git = find_program('git'")
    end = text.index("add_project_arguments('-DPROJECT_VERSION", start)
    text = text[:start] + text[end:]
    text = text.replace("version = '\"@0@\"'.format(meson.project_version())",
                        "version = '\"@0@-agent-cursor-compat\"'.format(meson.project_version())")
    meson.write_text(text)
    build = root / 'build'
    env = dict(os.environ, CC='/usr/bin/cc', CCACHE_DIR=str(root / 'ccache'))
    subprocess.run(['meson', 'setup', str(build), str(source), '--wrap-mode=nofallback',
                    '--buildtype=release', '-Dpam=disabled', '-Dman-pages=disabled',
                    '-Dtests=false', '-Dscreencopy-dmabuf=disabled'], env=env, check=True)
    subprocess.run(['meson', 'compile', '-C', str(build), '-j', '2'], env=env, check=True)
    shutil.copy2(build / 'wayvnc', output / 'wayvnc')
    # Keep its licence beside the private executable.
    shutil.copy2(source / 'COPYING', output / 'COPYING')
    (output / 'build.json').write_text(json.dumps({
        'version': VERSION, 'compatibility': 'skip-separate-cursor-capture',
        'source_sha256': hashlib.sha256(args.archive.read_bytes()).hexdigest(),
        'binary_sha256': hashlib.sha256((output/'wayvnc').read_bytes()).hexdigest(),
    }, indent=2) + '\n')
print(output / 'wayvnc')
