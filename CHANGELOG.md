# Changelog

## 0.1.0 (2026-09-26)

First release.

- `acer_predator_dt_rgb` kernel driver: lighting control through the `AcerGamingFunction` WMI methods 5 to 8, with PredatorSense's payload formats for SMBIOS 172 v6.2 and older, firmware read-back of every area at load, per-zone sysfs files, and a debugfs read-back for research. Tested on Linux 7.2, compile-tested on 6.8 and 6.12.
- `orionctl`: status, set, off and on, save and restore, style list, show, apply, save and validate, and doctor. JSON output, zone names per model, automatic saving of the current look.
- 49 styles, including ports of PredatorSense's defaults.
- DKMS, udev, sysusers, tmpfiles and systemd files, with `make install` and `make uninstall`.
- Documentation: installation, usage, style format, protocol, reverse engineering notes, safety, hardware and roadmap.

Tested on a Predator PO7-660 with BIOS 1.08.
