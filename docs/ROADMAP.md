# Roadmap

The goal is the best way to control the lights of a Predator Orion on any operating system, built in the open. Linux users should end up with more control than PredatorSense gives Windows users, and the project should show what open systems make possible when a vendor does not bother.

## Done in 0.1.0

- Kernel driver for the lighting firmware, with the exact payloads PredatorSense uses, input validation and firmware read-back.
- `orionctl` with every effect and parameter the hardware has, zone names per model, JSON output, save and restore.
- 49 styles in an open JSON format.
- DKMS, udev, systemd and group setup: the driver survives kernel updates, the lighting survives reboots and suspend, and no sudo is needed day to day.
- Documentation of the protocol and of how it was found.

## Done for 0.2.0

- The Orion Unchained app. It draws the PO7-660 with each zone lit and animated the way the hardware is set, and has every effect and setting for each zone and for the whole case. The style library comes with live previews, and styles can be saved, imported, exported and shared through GitHub. Identify buttons show which zone is which, the checks from `orionctl doctor` are built in, and a demo mode runs without the hardware.
- orionctl and the app share one Python package, `orion_unchained`.

## Next

- Confirm the zone names on the PO7-660 by eye, and get model reports for the PO3, PO5, PO7-640/650/655 and POX so they can be enabled by default.
- Find out what the duration parameter does for each effect and its real range.
- Check whether the firmware keeps the lighting through power loss, reboot and suspend on its own.
- Packages: AUR, Fedora COPR, a Debian/Ubuntu package, and a NixOS module.
- An OpenRGB bridge, so the zones show up in OpenRGB and work with its profiles and plugins for people who already use it.

## The app

The app exists now, and the aim has not changed: better than both PredatorSense and OpenRGB, and state of the art for what it does. It already shows the case and every setting, and it works offline with no account, telemetry or ads. Still to come:

- Drawings for the other Orion models, which show a plain ring per zone for now.
- Fine-tune the effect previews. They were fitted to a video at speed 5 and duration 0 and come close, but still differ a little from the hardware. How speed and duration scale is a guess until each effect is filmed at a few settings.
- A preview mode that tries a style on the drawing before anything is sent to the hardware.
- A style gallery to browse, search and install from with one click, and a way to publish your own from the app.
- Switching styles by schedule or trigger: time of day, idle, screen lock, a game starting.
- Panel widgets for KDE Plasma and GNOME for quick changes.

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
