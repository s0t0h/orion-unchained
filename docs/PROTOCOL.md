# Lighting protocol of Acer Predator Orion desktops

This document describes how the case lighting of Predator Orion desktops is controlled, as far as it has been worked out. It was reconstructed from the machine's firmware tables and from PredatorSense DT 4.2.512 for Windows; [REVERSE-ENGINEERING.md](REVERSE-ENGINEERING.md) explains how. All byte values were checked on a PO7-660 with BIOS 1.08.

## Overview

On the PO7-660 the lighting controller sits on the chipset's SMBus at address `0x29` and has no USB or HID interface. The board firmware owns it and exposes it through the WMI class `AcerGamingFunction`. PredatorSense uses four of that class's methods for lighting:

| ID | Method | Input | Output | Purpose |
|---|---|---|---|---|
| 5 | `SetGamingLedBehavior` | `uint8[16]` | `uint64` | effect, speed, duration, colour type, direction |
| 6 | `GetGamingLedBehavior` | `uint64` | `uint64` | read the effect of one area |
| 7 | `SetGamingRgbSetting` | `uint64` | `uint32` | colour and brightness |
| 8 | `GetGamingRgbSetting` | `uint32` | `uint64` | read the colour of one area |

Every change is two calls, in this order: method 5, then method 7. PredatorSense waits 20 ms after each call.

## The WMI class

| | |
|---|---|
| Class | `AcerGamingFunction` (namespace `root\wmi`) |
| GUID | `7A4DDFE7-5B5D-40B4-8595-4408E0CC7F56` |
| WMI object ID | `BH`, so the ACPI method is `\_SB.WMID.WMBH` |
| Instances | 1 |

The firmware's embedded MOF (decoded copies are in [firmware/](firmware/)) declares these methods:

| ID | Method | Used for lighting |
|---|---|---|
| 1 | `GetGamingSysInfo` | no |
| 2 | `SetGamingSysConfig` | no |
| 3 | `GetGamingSysConfig` | no |
| 4 | `GetLightingPatternArea` | not by PredatorSense; meaning unknown |
| 5 | `SetGamingLedBehavior` | yes |
| 6 | `GetGamingLedBehavior` | yes |
| 7 | `SetGamingRgbSetting` | yes |
| 8 | `GetGamingRgbSetting` | yes |
| 9 | `SetCpuOverclockingProfile` | no |
| 10 | `GetCpuOverclockingProfile` | no |
| 11 | `GetCpuOverclockingCapability` | no |
| 12 | `SetAcerGamingSynchronizationData` | no |

The same WMI device (`_UID` "APGe") also carries the classes `BIOSSetting`, `UtilityFunction`, `APGeAction` and `AcerBiosConfigurationTool`, which handle BIOS passwords, boot order, BIOS defaults and device state. None of them has anything to do with lighting.

## What happens in ACPI

`WMBH(instance, method, input)` does no hardware access itself. For methods 1 to 8 and 12 it:

1. stores `0x40 | method` in `WCMD` and the input buffer in `WBUF`, a mailbox in system memory (region `EXBU` at `0x91C2E018` on BIOS 1.08),
2. calls `PHSR`, which writes `0x91` to I/O port `0xB2` and so raises a software SMI,
3. returns the first bytes of `WBUF` as the result: 8 bytes for methods 1, 3, 5, 6 and 8, 4 bytes for methods 2, 4, 7 and 12.

The lighting logic therefore runs in System Management Mode, inside the BIOS. Methods 9 to 11 (overclocking) take a separate path in `WMBH`.

## Inside the firmware

The SMM driver that handles these requests (`OEMWMISmi` in BIOS 1.08) turns each lighting method into one SMBus block transfer to the controller at 7-bit address `0x29` on the chipset's SMBus (`i2c-0`, driver `i2c_i801`, on Linux):

| Method | SMBus transfer |
|---|---|
| 5 | block write, command `0x05`, 8 bytes: area mask high, area mask low, enable, mode, feature bits, speed, duration, colour type |
| 7 | block write, command `0x07`, 7 bytes: area mask high, area mask low, red, green, blue, brightness, `0x03` |
| 6 | block read, command `(n << 4) \| 5`, 6 bytes back; n is 1 to 5 for areas 1 to 5, 6 for global and 7 for memory |
| 8 | block read, command `(n << 4) \| 7`, 6 bytes back, the first four being red, green, blue and brightness |

The firmware fills in the feature bits and the direction itself, and it always sends `0x03` as the last colour byte, so the `0x02` PredatorSense sends for colourless effects never reaches the controller. BIOS Setup reads the controller's firmware version with a block read of command `0xF0` and shows it as "LED Firmware Version" on its Information page. When the SMBus is busy, for example because a Linux driver is using it at that moment, the firmware drops the change and still reports success.

The BIOS update contains no firmware for the controller and no code that could update it, and it never sends the controller per-LED colours. The chip is not named anywhere. The way Setup writes its registers resembles ENE's SMBus RGB controllers, which is unconfirmed.

The transfers come from a disassembly of the BIOS 1.08 update. The reads were then checked on the bus of a PO7-660 with `i2cget -y 0 0x29 <command> s`, and they return what methods 6 and 8 return, minus the status byte:

| Command | Reply |
|---|---|
| `(n << 4) \| 5` | enable, mode, speed, duration, `0x00`, `0xFF` |
| `(n << 4) \| 7` | red, green, blue, brightness, `0xFF`, `0xFF` |
| `0xF0` | `0x35 0x48 0x00 0x00 0x00 0x00` on that machine |

The global entry keeps its own values: after areas were changed one by one, command `0x65` still returned the last global effect. The writes have not been tried on the bus.

## SMBIOS type 172

PredatorSense picks the payload format from Acer's OEM SMBIOS structure, type 172 (`0xAC`). Its first two data bytes are a version:

```
offset  0: 0xAC (type)   1: length   2-3: handle
offset  4: major version
offset  5: minor version
offset  6: records of 3 bytes (1-byte id, 16-bit value), 0xFF = unused
```

If the version is 6.x with a minor version of 2 or more, `SetGamingLedBehavior` takes the 16-byte payload with a direction field. Otherwise it takes an 8-byte value without one. The PO7-660 reports 6.2:

```
AC 36 2D 00 06 02 FF FF FF 02 01 00 FF FF FF 04
01 00 FF FF FF FF FF FF FF FF FF FF FF FF FF FF
FF FF FF FF FF FF FF FF FF FF 0D FF 00 FF FF FF
FF FF FF FF FF FF
```

PredatorSense reads the records but only uses the version. What the records mean is not known.

## Areas

Every call addresses areas through a bit mask, `1 << area`:

| Area | Mask | Meaning |
|---|---|---|
| 0 | `0x01` | global: all areas at once |
| 1 to 5 | `0x02` to `0x20` | individual areas, see below |
| 6 | `0x40` | memory (DIMM) lighting |

PredatorSense decides from the model name which areas to offer: Global and Area1 to Area5 on PO5 and PO7 models, Global and Area1 to Area4 on PO3 and POX models, plus the memory area when the query described under "Reading back" says it exists. Its interface names the areas per model:

| Model | Area 1 | Area 2 | Area 3 | Area 4 | Area 5 |
|---|---|---|---|---|---|
| PO7-660 | CPU fan (pump block) | front fans | cooler fans (radiator) | rear fan | |
| PO7-640/650/655 | CPU fan | front fan 1 | front fan 2 | rear fan | motherboard |
| PO5 | CPU fan | front fan 1 | front fan 2 | rear fan | motherboard |
| PO3 | CPU fan | front fan | rear fan | light bar | |
| POX | CPU fan | system fan 1 | system fan 2 | bezel | |

The GPU ("VGA") appears in the same interface but is driven separately; see "GPU lighting" below. On the PO7-660 the firmware accepts areas 0 to 4 and rejects 5 and 6 (the test machine has no RGB memory).

Setting area 0 copies the effect and colour to every area; reading the areas back afterwards returns the global values. Setting a single area afterwards changes only that area.

## SetGamingLedBehavior (method 5)

16-byte payload, used with SMBIOS 172 v6.2 and later:

| Byte | Meaning |
|---|---|
| 0 | area mask, low byte (`1 << area` for areas 0 to 8) |
| 1 | area mask, high byte (`1 << (area - 8)` for areas above 8) |
| 2 | enable: 0 when the mode is `0xFE` (off), otherwise 1 |
| 3 | mode, see "Modes" |
| 4 | `0x0F` |
| 5 | speed, 0 to 9 |
| 6 | duration |
| 7 | colour type: 0 = the colour set with method 7, 1 = random colours |
| 8 | direction: 0 or 1 |
| 9-15 | 0 |

With older SMBIOS versions the input is a `uint64` holding the first 8 bytes of the table above, with `0x07` instead of `0x0F` in byte 4 and no direction.

PredatorSense's lighting DLL builds the area mask in two halves as shown, which means area 8 produces an empty mask in the 16-byte format. No PO7 model uses area 8.

## SetGamingRgbSetting (method 7)

`uint64`, little endian:

| Byte | Meaning |
|---|---|
| 0-1 | area mask (`1 << area`) |
| 2 | red |
| 3 | green |
| 4 | blue |
| 5 | brightness, 0 to 100 |
| 6 | `0x02` for modes `0x06` and `0x0A` to `0x0E`, `0x03` for all others |
| 7 | 0 |

The value in byte 6 separates effects that PredatorSense treats as colourless (rainbow, risen, stack, extend, meteorite, magic) from those that use the colour.

## Reading back (methods 6 and 8)

Both take an area mask (method 6 as `uint64`, method 8 as `uint32`) and return 8 bytes. Byte 0 is a status: 0 when the area exists, 1 when it does not.

| Byte | GetGamingLedBehavior | GetGamingRgbSetting |
|---|---|---|
| 0 | status | status |
| 1 | enable | red |
| 2 | mode | green |
| 3 | speed | blue |
| 4 | duration | brightness |
| 5 | 0 in all observations | 0 |
| 6 | `0xFF` in all observations | 0 |
| 7 | 0 | 0 |

The direction is not reported. PredatorSense calls `GetGamingLedBehavior(0x40)` at startup and offers memory lighting when the status byte is 0.

## Modes

| Mode | ID | Colour | Speed | Duration | Direction |
|---|---|---|---|---|---|
| static | `0x00` | yes | | | |
| breathing | `0x01` | yes | yes | yes | |
| heartbeat | `0x02` | yes | yes | yes | |
| twinkling | `0x03` | yes | yes | yes | |
| rainbow | `0x06` | | yes | | |
| wave | `0x09` | yes | yes | yes | |
| risen | `0x0A` | | yes | yes | |
| stack | `0x0B` | | yes | | yes |
| extend | `0x0C` | | yes | | |
| meteorite | `0x0D` | | yes | | |
| magic | `0x0E` | | yes | | |
| snake | `0x0F` | yes | yes | | yes |
| off | `0xFE` | | | | |

The speed, duration and direction columns follow PredatorSense's interface, which disables controls an effect does not use. The colour column follows Acer's lighting DLL. The two disagree on snake: the interface shows no colour picker for it, while the DLL declares a colour for snake and sends it with byte 6 of method 7 set to `0x03`.

On the PO7-660 with BIOS 1.08 the firmware accepts off (`0xFE` with enable 0), but the LEDs stay lit. Brightness 0 in method 7 does turn them off, so the driver sends brightness 0 with off.

PredatorSense's individual-area menus on PO7 models leave out wave and snake, and its memory menu offers only static, breathing, risen, twinkling, rainbow and heartbeat. The DLL offers a random colour only on the global area, for breathing, heartbeat, twinkling, wave and snake.

## How PredatorSense fills the fields

PredatorSense ships its own copy of OpenRGB together with a lighting service that starts it. Acer's lighting DLL, `AcerDTECDeviceController.dll`, provides the OpenRGB device classes (`AcerDTGlobal`, `AcerDTArea1` to `AcerDTArea5`, `AcerDTDIMM`) and turns an OpenRGB mode into the two WMI calls:

- speed is the low nibble of OpenRGB's speed value and duration the byte above it (`speed >> 4`), so one OpenRGB speed value carries both;
- direction is OpenRGB's direction value (0 left, 1 right);
- the colour type is 1 when OpenRGB's colour mode is "random", otherwise 0.

The interface's defaults are static, speed 3, duration 3, direction right and colour `#00AEC7`. Its colour picker's five swatches are `#00AEC7`, `#3CF03C`, `#FF0000`, `#FFA000` and `#A000FF`.

## Example

Setting area 4 (rear fan on the PO7-660) to snake, colour `#00FFFF`, speed 2, direction 1, brightness 80:

```
SetGamingLedBehavior  10 00 01 0f 0f 02 00 00 01 00 00 00 00 00 00 00
SetGamingRgbSetting   10 00 00 ff ff 50 03 00
```

Reading it back:

```
GetGamingLedBehavior(0x10) -> 00 01 0f 02 00 00 ff 00
GetGamingRgbSetting(0x10)  -> 00 00 ff ff 50 00 00 00
```

Setting the global area to static red at full brightness:

```
SetGamingLedBehavior  01 00 01 00 0f 05 00 00 00 00 00 00 00 00 00 00
SetGamingRgbSetting   01 00 ff 00 00 64 03 00
```

## GPU lighting

PredatorSense lists a second lighting device, `AcerDTNV4090Controller`, for the graphics card of some models. It does not use WMI: it writes registers of a controller on the card through NVIDIA's NvAPI I2C functions. The registers, the bus and the address are not documented here yet. Writing to a GPU's I2C buses reaches the same buses as its power and voltage controllers, so this needs careful analysis before anything is tried. See [SAFETY.md](SAFETY.md).

## Open questions

- What duration does, visually, for each effect, and its useful range. PredatorSense defaults to 3; the driver accepts 0 to 9.
- The meaning of the SMBIOS 172 records and of method 4, `GetLightingPatternArea`.
- Whether the firmware keeps the lighting across power loss, reboots and suspend. The driver restores it from userspace either way.
- The GPU controller's register map.
