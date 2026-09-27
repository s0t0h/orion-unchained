# Orion Unchained

Open-source lighting control for Acer Predator Orion desktops on Linux.

Acer sells the Predator Orion with a case full of RGB fans and a Windows app to drive them, and gives Linux users nothing. Orion Unchained fills that gap with a kernel driver, a desktop app, a command-line tool and a library of lighting styles. It was built from scratch by taking the Windows software apart, and every byte it sends to the hardware is documented here, so nobody has to do that work again.

It is tested on a Predator Orion 7000 (PO7-660) running Linux 7.2, and the driver builds on kernels from 6.8 up.

## What you get

- A kernel driver, `acer_predator_dt_rgb`, that sends the lighting firmware the same requests PredatorSense sends on Windows, byte for byte.
- The Orion Unchained app, which draws the case with each zone lit the way the hardware shows it and puts every setting and the whole style library one click away.
- `orionctl`, a command-line tool for every zone and every hardware effect: static, breathing, heartbeat, twinkling, rainbow, wave, risen, stack, extend, meteorite, magic and snake, each with colour, brightness, speed, duration and direction where the effect uses them.
- 49 ready-made styles, from Acer's own factory looks to distro themes, synthwave and pride flags.
- Styles are small JSON files, so you can write your own and share them like any other file.
- Your lighting comes back after a reboot or suspend, and your own account can change it without sudo.
- Everything is scriptable. `orionctl status --json` feeds other programs, and the driver's sysfs files work from any language.

## Quick start

```bash
git clone https://github.com/s0t0h/orion-unchained
cd orion-unchained
sudo make install
orionctl style apply synthwave
```

Then open Orion Unchained from your app menu, or run `orion-unchained`. The app needs PySide6, which most distributions package; see below.

`make install` builds the driver through DKMS, so it is rebuilt automatically when your kernel updates. It also adds your account to the `orion-rgb` group, which lets you change the lights without sudo. [docs/INSTALL.md](docs/INSTALL.md) has the details for each distribution, PySide6, Secure Boot and uninstalling.

## The app

The app shows the case unfolded like a box, with each fan ring and the CPU cooler lit and animated the way the hardware is set. Click a part to change its effect, colour, brightness, speed, duration or direction, and the lights follow as you drag. The Styles page previews the whole library and applies a style with one click. Anything you build can be saved as a style, and each style's menu can export it or send it to the project through GitHub's style form. `orion-unchained --demo` runs it without the hardware. [docs/APP.md](docs/APP.md) covers the rest.

## Using orionctl

```bash
orionctl status                                     # what every zone is doing
orionctl set front rear -m breathing -c purple -s 3  # two zones breathing purple
orionctl set global -m wave -c random               # a wave in random colours across the case
orionctl set cpu -m static -c ff2a6d -b 60          # the CPU block in pink at 60 %
orionctl off                                        # lights out
orionctl on                                         # and back to how they were
orionctl style list                                 # browse the style library
orionctl style save "my look"                       # keep what you just built
```

On the PO7-660 the zones are `cpu` (the pump block of the liquid cooler), `front` (the front fans), `radiator` or `top` (the fans on the radiator) and `rear` (the rear fan). `global` sets all of them with one command, and it is the only zone where PredatorSense offers the wave and snake effects. The names come from PredatorSense's own layout tables. [docs/USAGE.md](docs/USAGE.md) covers every command and the raw sysfs interface.

## Styles

A style describes the whole case in a few lines:

```json
{
  "format": 1,
  "name": "Synthwave",
  "author": "Orion Unchained",
  "description": "Hot pink and neon cyan, straight out of 1986.",
  "tags": ["retro", "neon"],
  "zones": {
    "front": {"mode": "static", "color": "ff2a6d"},
    "radiator": {"mode": "static", "color": "d300c5"},
    "cpu": {"mode": "static", "color": "05d9e8"},
    "rear": {"mode": "static", "color": "05d9e8"}
  }
}
```

The library in [styles/](styles/) has ports of Acer's defaults, one showcase per hardware effect, Linux distribution themes, nature and neon palettes, pride flags, seasonal looks and quiet ones for night and focus. Your own styles live in `~/.config/orion-unchained/styles/`. The format is specified in [docs/STYLES.md](docs/STYLES.md), and new styles are welcome as pull requests.

## Supported machines

| Model | Status |
|---|---|
| Predator Orion 7000, PO7-660 | Works. Tested on BIOS 1.08. |
| PO7-640, PO7-650, PO7-655 | Should work, needs a tester |
| PO5-640, PO5-650, PO5-655, PO5-660 | Should work, needs a tester |
| PO3-640, PO3-650, PO3-655, PO3-660 | Should work, needs a tester |
| POX-650, POX-655, POX-950, POX-955 | Should work, needs a tester |

All of these are handled by the same PredatorSense lighting code on Windows, so they very likely speak the same protocol. The driver only binds on verified models unless it is loaded with `force=1`. If you own one of the others, [docs/HARDWARE.md](docs/HARDWARE.md) explains how to test it safely and report back.

## How it works

The lights are driven by a controller on the motherboard's SMBus, and the board firmware owns it. PredatorSense reaches it through a WMI class called `AcerGamingFunction`. Two of its methods set an effect and a colour for one area of the case, and two more read them back. The ACPI code behind them hands each request to the firmware through a software SMI, and the firmware passes it on to the controller. Every such call pauses all CPU cores for a moment, so on the PO7-660 the driver skips it: after checking the controller at load, it sends it the same SMBus transfers the firmware would. Other models, and the module option `transport=wmi`, use the WMI methods. [docs/SAFETY.md](docs/SAFETY.md) lists exactly what the driver sends.

The driver calls the same four methods through the kernel's WMI bus, with payloads copied from a disassembly of Acer's lighting DLL. It asks the firmware which areas exist, hides the rest, and validates every value before anything is sent. [docs/PROTOCOL.md](docs/PROTOCOL.md) documents the protocol, and [docs/REVERSE-ENGINEERING.md](docs/REVERSE-ENGINEERING.md) explains how it was worked out and how to check the work.

## Safety

The same firmware interface also handles fan control, CPU overclocking and system settings. The driver has no way to call those methods; it is limited to the lighting ones, and it sends nothing that PredatorSense would not send. [docs/SAFETY.md](docs/SAFETY.md) lists exactly what is called, what is never called, and why.

## Roadmap

The driver, orionctl and the app together cover everything the lighting firmware can do. Next on the list are an online style gallery in the app, switching styles on a schedule or when a game starts, panel widgets for KDE Plasma and GNOME, and a much bigger style library. Further out come software animations and lighting that reacts to what the computer is doing. See [docs/ROADMAP.md](docs/ROADMAP.md).

## Why this exists

I bought a Predator Orion 7000, installed Linux on it, and found out the lights only take orders from a Windows app. Acer publishes no protocol, no SDK and no Linux support. So this project took the long way round. It read the firmware tables, took PredatorSense apart and rebuilt the lighting control in the open, where anyone can improve it.

Changing the colour of a computer you own should not require a particular operating system. This is my raised middle finger to hardware that pretends otherwise, and a small advertisement for what open systems make possible.

## Contributing

Test it on your model, share a style, fix a bug or improve these docs. [CONTRIBUTING.md](CONTRIBUTING.md) explains how.

## Legal

Orion Unchained is free software under the GNU General Public License, version 2 or later. See [LICENSE](LICENSE).

It contains no code or files from Acer. The driver and tools were written from scratch; Acer's software was only studied. Acer, Predator, Predator Orion and PredatorSense are trademarks of Acer Inc. This project is not affiliated with or endorsed by Acer.
