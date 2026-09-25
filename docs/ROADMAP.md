# Roadmap

The goal is the best way to control the lights of a Predator Orion on any operating system, built in the open. Linux users should end up with more control than PredatorSense gives Windows users, and the project should show what open systems make possible when a vendor does not bother.

## Done in 0.1.0

- Kernel driver for the lighting firmware, with the exact payloads PredatorSense uses, input validation and firmware read-back.
- `orionctl` with every effect and parameter the hardware has, zone names per model, JSON output, save and restore.
- 49 styles in an open JSON format.
- DKMS, udev, systemd and group setup: the driver survives kernel updates, the lighting survives reboots and suspend, and no sudo is needed day to day.
- Documentation of the protocol and of how it was found.

## Next

- Confirm the zone names on the PO7-660 by eye, and get model reports for the PO3, PO5, PO7-640/650/655 and POX so they can be enabled by default.
- Find out what the duration parameter does for each effect and its real range.
- Check whether the firmware keeps the lighting through power loss, reboot and suspend on its own.
- Packages: AUR, Fedora COPR, a Debian/Ubuntu package, and a NixOS module.
- An OpenRGB bridge, so the zones show up in OpenRGB and work with its profiles and plugins for people who already use it.

## The app

The big one is a graphical app made for these machines, better than both PredatorSense and OpenRGB, and state of the art for what it does. What it should do:

- Show a live, accurate picture of the case, with every zone in place and lit the way the real one is.
- Give direct access to every parameter the hardware has (effect, colour, brightness, speed, duration, direction) on every zone and on the whole case, with nothing hidden behind presets.
- Let anyone make their own styles in an editor, preview them on the picture before applying, and save them as ordinary style files.
- Make sharing part of the app: a style gallery to browse, search and install from with one click, and a way to publish your own.
- Switch styles by schedule or trigger: time of day, idle, screen lock, a game starting.
- Sit in the KDE Plasma and GNOME panels for quick changes.
- Run fast and look native, work offline, and have no account, no telemetry and no ads.

Everything the app can do, `orionctl` should be able to do as well. To get there, a small system service with a D-Bus API will become the shared backend for the app, the CLI and other tools. It will also handle permissions through polkit and run animations.

## Styles for everything

The 49 styles are a start. The library should grow into hundreds, covering:

- ports of every PredatorSense preset and effect;
- popular RGB setups and colour schemes from the PC modding world;
- games, films, music, sports and art, under descriptive names;
- Linux distributions, desktops and open-source projects;
- seasons, holidays, moods and times of day;
- experimental styles that push the effects in odd directions;
- animated styles once the animation engine exists.

Since styles are plain files, anyone can remix one and send it back. A public gallery with previews will make that easy.

## Animation and reactive lighting

The firmware runs its effects by itself, which costs the computer nothing. Anything beyond them has to be animated from software, by updating zones over and over. Each update is two firmware calls, and every firmware call briefly pauses all CPU cores, so the update rate has to stay low. The plan:

- Measure the cost of one firmware call precisely and find a rate that stays invisible.
- Style format 2 with keyframes: colours that travel from the front to the rear, fades between whole styles, timed sequences.
- Combine both worlds: firmware effects for motion, slower software changes on top.
- Reactive lighting driven by CPU and GPU temperatures, load, audio, notifications, and game or chat events.

## Integrations

- OpenRGB (see above).
- Home Assistant and MQTT, so the case can match the room lights.
- KDE Plasma and GNOME widgets.
- systemd hooks, for example lights off when the screen locks.

## More hardware

- GPU lighting on Acer's own graphics cards. PredatorSense uses I2C writes to the card for this, which needs the same careful analysis the case lighting got before anything is sent.
- Memory lighting, once someone with RGB memory in an Orion can test it.
- Acer Nitro desktops (N50, N70), which appear in PredatorSense's lighting DLL with their own payload builder.

## Mainline Linux

Once the driver has been tested on a few models, submit it to the Linux kernel (`drivers/platform/x86`). Then every distribution ships it and Orion owners get working lights without installing anything.

## Beyond lighting (research only)

PredatorSense also sets fan curves, performance modes and CPU overclocking through the same firmware interface. Those could come to Linux one day. Mistakes there can overheat or destabilise the machine, so they will only be touched after the same depth of analysis as the lighting, with the findings documented and reviewed before any code sends a request.
