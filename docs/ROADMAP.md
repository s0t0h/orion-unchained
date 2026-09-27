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
- On the PO7-660 the driver talks to the lighting controller directly over the SMBus, so light changes no longer pause the CPU and can no longer get lost. The WMI path stays as the fallback.
- Turning the lights off works on the PO7-660, whose firmware ignores the off mode.
- The effect previews follow a video of the real effects.

## Next

- Confirm the zone names on the PO7-660 by eye, and get model reports for the PO3, PO5, PO7-640/650/655 and POX so they can be enabled by default.
- Find out what the duration parameter does for each effect and its real range.
- Check whether the firmware keeps the lighting through power loss, reboot and suspend on its own.
- Packages: AUR, Fedora COPR, a Debian/Ubuntu package, and a NixOS module.
- An OpenRGB bridge, so the zones show up in OpenRGB and work with its profiles and plugins for people who already use it.
- Keep zones in step after a whole-case change that leaves them different, for example one zone dimmer than the rest. Such a change goes out as separate zone commands a moment apart, so each zone starts its effect a little later than the one before. Sending the effect once for the whole case and then only colours per zone would avoid that, if a colour command does not restart a running effect. That needs a test on the hardware.
- Find the shortest safe pause after each SMBus write. The driver still waits the 20 ms it inherited from the firmware path.
- Compile-test the driver on Linux 6.8 and 6.12 again; the SMBus path has only been built on 7.2.

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

The controller runs its effects by itself, which costs the computer nothing. It only takes whole-zone commands, though: an effect, a colour, a brightness and a speed for each zone, with no way to set single LEDs. Through the firmware, every change is two firmware calls, and each call pauses all CPU cores for about 1.6 ms, so software can afford only a few changes per second. On the PO7-660 the driver talks to the controller directly, which pauses nothing, so zones can change many times per second there. Nothing drives such changes yet: the animation engine and a style format for it still have to be built.

Hand-made effects will combine the firmware's effects instead of drawing their own:

- Relay across zones: start a firmware effect zone after zone with precise timing, for example one snake that travels round the whole case.
- Layering: the firmware moves the single LEDs, and software slowly changes colours or swaps effects on top, like a snake that turns from blue to red as the CPU heats up.
- Reactive lighting: CPU and GPU temperatures, load, notifications, game or chat events, time of day, lights off when the screen locks. Anything that changes about once a second or slower.
- Scenes and timed sequences, such as looks that change through the day and fades between whole styles. Style format 2 with keyframes will describe them.

Custom per-LED patterns stay out of reach, because the controller has no command for single LEDs. Layering depends on whether a colour command restarts the effect that is running, which still has to be tested.

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
