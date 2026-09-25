# Safety

Orion Unchained talks to the board firmware of an expensive machine, through an interface that also controls fans, CPU overclocking and BIOS settings. This page lists exactly what it does and what it will not do.

## What the driver calls

Only four methods of the `AcerGamingFunction` WMI class, the same four PredatorSense uses for lighting:

| Method | When |
|---|---|
| 6, `GetGamingLedBehavior` | at load, once per area, and on reads of the debugfs `state` file |
| 8, `GetGamingRgbSetting` | at load, once per area, and on reads of the debugfs `state` file |
| 5, `SetGamingLedBehavior` | when you change a zone |
| 7, `SetGamingRgbSetting` | when you change a zone, right after method 5 |

The payloads are built exactly as PredatorSense's lighting DLL builds them, including the 20 ms pause after each call. Loading the driver only reads: it asks which areas exist and what they show, and changes nothing.

## What it never calls

The method numbers are fixed in the driver's source, and there is no interface for sending anything else. In particular it never calls:

- `AcerGamingFunction` methods 1 to 3 (system information and configuration, which include fan and performance settings), 4 (`GetLightingPatternArea`, meaning unknown), 9 to 11 (CPU overclocking) and 12 (synchronisation data);
- anything in the `BIOSSetting`, `UtilityFunction`, `APGeAction` or `AcerBiosConfigurationTool` classes (BIOS passwords, boot order, BIOS defaults, device state);
- the SMBus, the embedded controller, I/O ports or the GPU's I2C buses.

## Validation

Every value is checked in the kernel before a payload is built: the zone must be one the firmware reported, the effect must be one that PredatorSense's lighting DLL lists for that zone, speed and duration must be 0 to 9, brightness 0 to 100, direction 0 or 1, and a random colour is only accepted where PredatorSense allows it. Anything else is rejected with "Invalid argument" and never reaches the firmware.

The memory zone stays hidden unless the module is loaded with `enable_dimm=1` and the firmware reports memory lighting. Memory lighting lives on the same bus as the chips that describe the RAM to the BIOS, and it has not been tested on hardware yet.

The driver binds only on tested models. `force=1` binds anyway and then sends the requests PredatorSense would send on that model, but nobody has tried it there yet, so read [HARDWARE.md](HARDWARE.md) first.

## Frequent updates

Each change of a zone is two firmware calls. While the firmware handles a call, all CPU cores pause briefly. That is harmless for normal use and for scripts that change something every few seconds. A loop that rewrites the lights many times per second could cause stutter; the cost per call has not been measured yet, which is why software animations are still on the roadmap and not in the tools.

## If something looks wrong

- `orionctl style apply predator-classic` sets Acer's factory look.
- Unloading the driver (`sudo rmmod acer_predator_dt_rgb`) leaves the lights exactly as they are.
- `sudo cat /sys/kernel/debug/acer_predator_dt_rgb/state` shows what the firmware reports for every area, which is the first thing to include in a bug report.

## GPU lighting

Some Orion models have an Acer graphics card whose lighting PredatorSense drives with NvAPI I2C writes. The same buses reach the card's power and voltage controllers. Nothing touches them in this project, and nothing will until the Windows side is fully understood and the risk has been written down and reviewed.

## Reporting a problem

Open an issue with the output of `orionctl doctor` and `sudo sh scripts/collect-info.sh`. If you found something that could damage hardware or expose a system, say so in the title so it gets looked at first.
