# Safety

Orion Unchained talks to the board firmware of an expensive machine, through an interface that also controls fans, CPU overclocking and BIOS settings. This page lists exactly what it does and what it will not do.

## What the driver talks to

On the PO7-660 the lighting controller sits at address `0x29` on the chipset's SMBus. The driver reaches it in one of two ways, chosen with the module option `transport` (default `auto`).

### Through the firmware

This is the path on every model except the PO7-660, and on the PO7-660 with `transport=wmi`. The driver calls only four methods of the `AcerGamingFunction` WMI class, the same four PredatorSense uses for lighting:

| Method | When |
|---|---|
| 6, `GetGamingLedBehavior` | at load, once per area, and on reads of the debugfs `state` file |
| 8, `GetGamingRgbSetting` | at load, once per area, and on reads of the debugfs `state` file |
| 5, `SetGamingLedBehavior` | when you change a zone |
| 7, `SetGamingRgbSetting` | when you change a zone, right after method 5 |

The payloads are built exactly as PredatorSense's lighting DLL builds them, including the 20 ms pause after each call. The firmware then passes each request on to the controller.

### Directly

With `transport=auto` on the PO7-660, the driver sends the controller the SMBus transfers the firmware would send, built byte for byte as BIOS 1.08 builds them: a block write of command `0x05` for the effect, one of `0x07` for the colour, and block reads for the state of an area and for the controller's version. Each write is followed by the same 20 ms pause.

Before it uses this path, the driver checks the controller with reads only. The version command must answer in the expected shape, and every area must read back the same through the controller as through the firmware. If anything differs, the driver logs the reason and stays with the firmware. The file `transport` next to `smbios_version` shows which path is in use.

The address is a constant in the driver's source. The driver never reads or writes any other address on the bus, and it sends no command the firmware does not send itself.

On both paths, loading the driver only reads: it asks which areas exist and what they show, and changes nothing.

## What it never calls

The method numbers, the address and the SMBus commands are fixed in the driver's source, and there is no interface for sending anything else. In particular it never calls or touches:

- `AcerGamingFunction` methods 1 to 3 (system information and configuration, which include fan and performance settings), 4 (`GetLightingPatternArea`, meaning unknown), 9 to 11 (CPU overclocking) and 12 (synchronisation data);
- anything in the `BIOSSetting`, `UtilityFunction`, `APGeAction` or `AcerBiosConfigurationTool` classes (BIOS passwords, boot order, BIOS defaults, device state);
- any SMBus address other than the lighting controller's, including the chips that describe the RAM to the BIOS;
- the embedded controller, I/O ports or the GPU's I2C buses.

## Validation

Every value is checked in the kernel before a payload is built: the zone must be one the firmware reported, the effect must be one that PredatorSense's lighting DLL lists for that zone, speed and duration must be 0 to 9, brightness 0 to 100, direction 0 or 1, and a random colour is only accepted where PredatorSense allows it. Anything else is rejected with "Invalid argument" and never reaches the controller.

The memory zone stays hidden unless the module is loaded with `enable_dimm=1` and the firmware reports memory lighting. Memory lighting lives on the same bus as the chips that describe the RAM to the BIOS, and it has not been tested on hardware yet.

The driver binds only on tested models. `force=1` binds anyway and then sends the requests PredatorSense would send on that model, always through the firmware and never directly, but nobody has tried it there yet, so read [HARDWARE.md](HARDWARE.md) first.

## Frequent updates

Through the firmware, each change of a zone is two firmware calls, and on a PO7-660 each call pauses all CPU cores for about 1.6 ms. That is harmless for normal use and for scripts that change something every few seconds, but a loop that rewrites the lights many times per second can cause stutter. The direct path makes no firmware calls and pauses nothing; how long a change keeps the bus busy has not been measured. Software animations are still on the roadmap and not in the tools.

## If something looks wrong

- `orionctl style apply predator-classic` sets Acer's factory look.
- Unloading the driver (`sudo rmmod acer_predator_dt_rgb`) leaves the lights exactly as they are.
- `sudo cat /sys/kernel/debug/acer_predator_dt_rgb/state` shows what the firmware reports for every area, which is the first thing to include in a bug report.

## GPU lighting

Some Orion models have an Acer graphics card whose lighting PredatorSense drives with NvAPI I2C writes. The same buses reach the card's power and voltage controllers. Nothing touches them in this project, and nothing will until the Windows side is fully understood and the risk has been written down and reviewed.

## Reporting a problem

Open an issue with the output of `orionctl doctor` and `sudo sh scripts/collect-info.sh`. If you found something that could damage hardware or expose a system, say so in the title so it gets looked at first.
