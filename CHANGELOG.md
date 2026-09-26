# Changelog

## 0.2.0 (unreleased)

- The Orion Unchained app, `orion-unchained`, built with Qt Quick through PySide6 6.8 or newer. It draws the PO7-660 with every zone lit and animated as the hardware is set, and it has every effect and setting per zone and for the whole case, the style library with previews, saving, import, export and sharing, identify buttons, the installation checks and a demo mode. Other models get a plain ring per zone.
- orionctl and the app share the `orion_unchained` Python package. `bin/orionctl` replaces `cli/orionctl`.
- A saved look whose areas still ran a global effect in random colours could not be restored: the saved file gave those areas a random colour, which only the global zone accepts. Such areas are now saved through the global zone.
- Turning the lights off left them lit on the PO7-660, because its firmware ignores the off mode. The driver, orionctl and the app now send brightness 0 with off. A zone switched from off to another effect gets full brightness back unless the change sets a brightness.
- The app's effect previews now follow a video of the real effects instead of guesses based on their names. Most had looked nothing like the hardware: twinkling blinks the whole case, rainbow and risen are slow, and wave is one pulse through the case. The effect descriptions changed to match.
- `sudo make install` removes older DKMS versions of the driver first, and installs the app with a menu entry and an icon.

## 0.1.0 (2026-09-26)

First release.

- `acer_predator_dt_rgb` kernel driver: lighting control through the `AcerGamingFunction` WMI methods 5 to 8, with PredatorSense's payload formats for SMBIOS 172 v6.2 and older, firmware read-back of every area at load, per-zone sysfs files, and a debugfs read-back for research. Tested on Linux 7.2, compile-tested on 6.8 and 6.12.
- `orionctl`: status, set, off and on, save and restore, style list, show, apply, save and validate, and doctor. JSON output, zone names per model, automatic saving of the current look.
- 49 styles, including ports of PredatorSense's defaults.
- DKMS, udev, sysusers, tmpfiles and systemd files, with `make install` and `make uninstall`.
- Documentation: installation, usage, style format, protocol, reverse engineering notes, safety, hardware and roadmap.

Tested on a Predator PO7-660 with BIOS 1.08.
