# Contributing

Help of every size is welcome, and you do not need to write code to make a difference.

## Test it on your model

If you own a Predator Orion other than the PO7-660, a model report is the most useful thing you can send. [docs/HARDWARE.md](docs/HARDWARE.md) walks through it; it takes about ten minutes and only changes colours.

## Share a style

Make a look you like, save it with `orionctl style save`, and send the file as a pull request to `styles/` or paste it into a "Share a style" issue. [docs/STYLES.md](docs/STYLES.md) has the format and a short checklist. Please look at a style on real hardware before sending it, since LEDs show colours differently from a screen.

## Code

- `make check` must pass. It validates every style, compiles orionctl and checks the shell scripts; CI also builds the driver.
- The driver follows the kernel coding style. Run `scripts/checkpatch.pl --no-tree -f driver/acer_predator_dt_rgb.c` from a kernel source tree if you have one.
- orionctl uses only the Python standard library, so it runs on any distribution without extra packages. Please keep it that way.
- Keep the driver buildable on Linux 6.8 and newer; `LINUX_VERSION_CODE` checks handle API differences.

## Firmware calls

The driver talks to firmware that also controls fans, overclocking and BIOS settings. A change that sends anything new to the firmware, including a new method, a new payload field or a new value range, needs:

1. a written explanation in [docs/PROTOCOL.md](docs/PROTOCOL.md) of what the call does and where that knowledge comes from;
2. evidence that PredatorSense sends the same thing on Windows, or a clear argument why the call is safe;
3. a test on real hardware, described in the pull request.

## Clean room

Do not commit Acer's files, decompiled Acer code or dumps from your own machine's firmware beyond the decoded tables that are already here. Describe what you found in your own words in the docs instead. ACPI dumps can contain licence keys (the MSDM table holds the Windows key), so never attach them unreviewed.

## Docs

Corrections and clearer explanations are always welcome. If something in the docs was wrong or confusing for you, it probably is for others too.
