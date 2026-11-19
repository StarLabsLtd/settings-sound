# Sound Settings
[![Translation status](https://l10n.elementaryos.org/widget/settings/sound/svg-badge.svg)](https://l10n.elementaryos.org/engage/settings/)

![screenshot](data/screenshot-output.png?raw=true)

## Building and Installation

You'll need the following dependencies:

* libadwaita-1-dev
* libcanberra-dev
* libgranite-7-dev
* libgtk-4-dev
* libpulse-dev
* libswitchboard-3-dev
* meson (>= 0.58.0)
* valac

Run `meson` to configure the build environment and then `ninja` to build

    meson build --prefix=/usr
    cd build
    ninja

To install, use `ninja install`

    ninja install

## Audio regression tests

`tests/run-components.sh /path/to/settings-daemon` runs the model, GTK,
selection and native audio tests in a disposable container without `/dev/snd`.
In addition to the build dependencies, it needs PulseAudio, PipeWire with its
Pulse server and command-line tools, WirePlumber, Xvfb and Python.

The native bridge takes `EQ_OEM_RULE` and `EQ_OEM_PROFILE` fixture paths and
requires root inside that container. Set `EQ_PRIVATE_TEST=1`. The suite checks
both daemon loss during device selection and a Pulse output missing from the
native PipeWire connection, alongside processing and graph-ownership cases.
