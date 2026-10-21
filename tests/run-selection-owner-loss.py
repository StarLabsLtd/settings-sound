#!/usr/bin/env python3
"""Run the selection regression against a private, null-device PulseAudio server."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

if Path('/dev/snd').exists():
    sys.exit(77)

with tempfile.TemporaryDirectory(prefix='vale-sound-selection-') as directory:
    root = Path(directory)
    env = dict(os.environ, XDG_RUNTIME_DIR=directory, XDG_CONFIG_HOME=directory,
               XDG_STATE_HOME=directory, XDG_CACHE_HOME=directory,
               PULSE_SERVER='unix:' + str(root / 'native'), GSETTINGS_BACKEND='memory')
    env.pop('DBUS_SESSION_BUS_ADDRESS', None)
    config = root / 'pulse.conf'
    config.write_text('load-module module-native-protocol-unix socket=' + str(root / 'native') + ' auth-anonymous=1\n'
                      'load-module module-null-sink sink_name=physical_output\n'
                      'load-module module-null-sink sink_name=physical_output2\n'
                      'load-module module-remap-source master=physical_output.monitor source_name=physical_input\n'
                      'set-default-sink physical_output\n'
                      'set-default-source physical_input\n')
    with (root / 'pulse.log').open('w+') as log:
        server = subprocess.Popen(['pulseaudio', '-n', '-F', str(config), '--use-pid-file=no',
                                   '--exit-idle-time=-1'], env=env, stdout=log, stderr=log)
        try:
            deadline = time.monotonic() + 5
            while not (root / 'native').exists():
                if server.poll() is not None or time.monotonic() > deadline:
                    log.seek(0)
                    raise RuntimeError(log.read())
                time.sleep(0.02)
            result = subprocess.run(['dbus-run-session', '--', sys.argv[1]], env=env, timeout=15)
        finally:
            server.terminate()
            server.wait(timeout=5)
    sys.exit(result.returncode)
