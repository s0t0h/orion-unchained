# How the protocol was worked out

This is the path from "the lights don't do anything on Linux" to a working driver, written down so anyone can check it or repeat it on another model. Every tool used is free software. No Acer code is included in this repository; to follow along, download PredatorSense yourself from Acer's support site.

The work was done on a Predator PO7-660 (BIOS 1.08) running Nobara 44 with Linux 7.2. At every step only read-only probes were used until the protocol was understood well enough to send exactly what Windows sends.

## 1. Looking for a lighting controller

Most RGB hardware shows up as a USB HID device or sits on the SMBus. On this machine `lsusb` and `/sys/class/hidraw` show only the keyboard, a wireless receiver, Bluetooth and a mouse. OpenRGB had already run a full detection pass here, including every SMBus and GPU I2C probe, and recognised nothing belonging to the case. The RAM is non-RGB Crucial memory, so there was no reason to probe the SMBus further. Section 7 shows that the controller does sit on the SMBus, at an address OpenRGB does not look at.

That leaves the firmware. `ls /sys/bus/wmi/devices` lists the WMI blocks the BIOS exposes, and one of them, `7A4DDFE7-5B5D-40B4-8595-4408E0CC7F56`, is the "Acer Gaming Function" GUID that Linux drivers for Predator laptops already use for keyboard lighting. On this desktop no driver claimed it.

## 2. Reading the firmware's own documentation

WMI blocks come with a description in binary MOF, which Linux exposes under `/sys/bus/wmi/devices/05901221-D566-11D1-B2F0-00A0C9062910-*/bmof`. [bmfdec](https://github.com/pali/bmfdec) turns it into readable MOF:

```bash
sudo cat /sys/bus/wmi/devices/05901221-D566-11D1-B2F0-00A0C9062910-8/bmof | bmf2mof
```

The desktop's `AcerGamingFunction` class turned out to differ from the laptops'. It declares `GetLightingPatternArea`, `SetGamingLedBehavior(uint8 input[16])`, `GetGamingLedBehavior`, `SetGamingRgbSetting` and `GetGamingRgbSetting` as methods 4 to 8. The same firmware also declares BIOS password, boot order and CPU overclocking methods, which made the rule for everything after this obvious: call nothing that is not understood. The decoded files are in [firmware/](firmware/).

## 3. Following the ACPI code

```bash
sudo acpidump -b      # or copy /sys/firmware/acpi/tables/DSDT
iasl -d dsdt.dat
```

The WMI object ID `BH` means the method is `WMBH` in the DSDT. It copies the method number and the input into a memory mailbox and calls `PHSR`, which writes `0x91` to port `0xB2`. That is a software SMI: the actual work happens in System Management Mode, inside the BIOS, where the operating system cannot see it. The payload format was therefore not in the ACPI tables, and the only complete description of it was the Windows software.

## 4. Taking PredatorSense apart

Acer's support page for the PO7-660 offers PredatorSense 4.2.512 ("PredatorSense_DT"). The package is a zip file. Nothing in it was run; it was only unpacked and read on Linux.

`AgentService/driver/RGBDevice.ini` names the two lighting devices, `AcerDTECDeviceController` and `AcerDTNV4090Controller`. Next to them sit `OpenRGB.exe` and the Qt libraries it needs: PredatorSense's lighting runs on a bundled copy of OpenRGB, with Acer's DLLs plugged in as device classes. The strings of `AcerDTECDeviceController.dll` already told most of the story:

```
SELECT * FROM AcerGamingFunction
SetGamingLedBehavior / SetGamingRgbSetting / GetGamingLedBehavior
area=%d, mode=%d, speed=%d, direction=%d, brightness=%d, color= (0X%X,0X%X,0X%X), duration =%d, colorType=%d
WMI stSMBiosType172: %d.%d location: %d
```

So the DLL does no hardware access of its own. It only calls the WMI methods found in step 2.

## 5. Recovering the payloads

[Ghidra](https://ghidra-sre.org/) decompiled the DLL in headless mode. The function that logs `AcerDTECLightingBaseController::AcerDTSetMode` builds both payloads. Decompilers get byte packing wrong often enough that the layout was then checked against the machine code with `objdump -d -M intel`: every `mov BYTE PTR [rbp-0x80+n]` instruction maps to one byte of the 16-byte buffer. The jump table that picks `0x02` or `0x03` for byte 6 of the colour payload was decoded by hand from `.rdata`.

The same DLL answered the remaining questions:

- the constructors of the `RGBController_AcerDT*` classes contain the mode tables, with the firmware ID, flags and speed and brightness ranges of every effect;
- a small parser reads SMBIOS type 172 and switches to the 16-byte payload for version 6.2 and later;
- `CheckDeviceStatus` maps model names (PO3, PO5, PO7, POX) to the list of areas, and uses `GetGamingLedBehavior(0x40)` to detect memory lighting;
- the area number of each device class is set in its factory function (`Global` 0, `Area1` to `Area5` 1 to 5, `DIMM` 6).

PredatorSense's user interface is an Electron app. Unpacking its `app.asar` gave the per-model zone names (which area is the front fan on which model), which effects each area offers, the default colour `#00AEC7`, and the five swatches of the colour picker.

## 6. First contact

With the protocol understood, the first call made from Linux was the read-only query PredatorSense itself makes at every start, `GetGamingLedBehavior(0x40)`. It came back with status 1, "no memory lighting", which matches the machine's non-RGB RAM.

The first write was the smallest possible change that Windows also makes: the global area, static, red. The firmware answered with status 0, reading the areas back returned the new colour everywhere, and the case turned red. After that, one colour per area confirmed that each area can be set on its own. Which area is which part of the case comes from PredatorSense's own layout tables.

## 7. Looking inside the BIOS

After the driver worked, the official BIOS 1.08 update from Acer's support site was unpacked offline to see what the SMI does with a request. The ROM is an AMI BIOS Guard capsule; UEFIExtract splits it into modules. The SMM driver `OEMWMISmi` holds a table that maps the mailbox commands to handlers. Disassembled with Ghidra and capstone, the four lighting handlers (`0x45` to `0x48`) each perform one SMBus block transfer to address `0x29`. [PROTOCOL.md](PROTOCOL.md) lists the transfers. Nothing was installed and the bus was not touched.

## 8. What was deliberately not done

- No probing or writing on the SMBus or the GPU's I2C buses.
- No direct access to the embedded controller or to I/O ports.
- No WMI methods outside the four lighting methods, not even the read-only ones for system information.
- No BIOS update and no change to any BIOS setting.

## Tools

bmfdec (BMOF decoding), acpica-tools (`acpidump`, `iasl`), UEFIExtract, Ghidra, capstone, GNU binutils (`objdump`), Python, and the kernel's WMI and debugfs interfaces. The driver keeps a raw read-back of every area in `/sys/kernel/debug/acer_predator_dt_rgb/state` for anyone continuing this work.

## A note on OpenRGB

PredatorSense ships OpenRGB, which is licensed under the GPL, version 2. The licence file in Acer's package offers the corresponding source code on written request. Anyone curious about Acer's build of OpenRGB can ask Acer for it.
