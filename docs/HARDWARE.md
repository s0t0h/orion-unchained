# Hardware

## Tested

| Model | BIOS | SMBIOS 172 | Zones reported | Notes |
|---|---|---|---|---|
| Predator Orion 7000, PO7-660 (Core Ultra 7 265KF, RTX 5090) | 1.08 | 6.2 | global, area1 to area4 | Area 5 and memory rejected by the firmware (no RGB RAM fitted). GPU lighting not supported yet. |

## Probably compatible

PredatorSense DT 4.2.512, the version Acer ships for the PO7-660, contains lighting layouts for these models too:

- PO3-640, PO3-650, PO3-655, PO3-660
- PO5-640, PO5-650, PO5-655, PO5-660
- PO7-640, PO7-650, PO7-655
- POX-650, POX-655, POX-950, POX-955

Its lighting DLL builds the same requests for all of them, so the driver should work on them. Each needs someone to try it before it is enabled by default.

## Zone names

These come from PredatorSense's layout tables. orionctl accepts the names in the table, and the driver zones (`area1` and so on) work on every model.

| Model | area1 | area2 | area3 | area4 | area5 |
|---|---|---|---|---|---|
| PO7-660 | `cpu` | `front` | `radiator`, `top` | `rear` | |
| PO7-640/650/655 | `cpu` | `front1` | `front2` | `rear` | `motherboard` |
| PO5 | `cpu` | `front1` | `front2` | `rear` | `motherboard` |
| PO3 | `cpu` | `front` | `rear` | `lightbar` | |
| POX | `cpu` | `sysfan1` | `sysfan2` | `bezel` | |

On models with two front fans, `front` covers both, and on POX `fans` covers both system fans. Where a model has RGB memory, `memory` is the `dimm` zone. PredatorSense's table suggests the PO3 uses a different number for its memory zone, which the driver does not support yet.

## Testing another model

Nothing below writes to the hardware until the last step, and the last step only changes colours.

1. Install as described in [INSTALL.md](INSTALL.md). The driver will not bind yet; `sudo dmesg | grep acer-predator` says "unverified model".
2. Load it anyway:

   ```bash
   sudo modprobe -r acer_predator_dt_rgb
   sudo modprobe acer_predator_dt_rgb force=1
   orionctl status
   ```

   This only reads. `orionctl status` should list the zones your firmware reports.
3. Collect a report:

   ```bash
   sudo sh scripts/collect-info.sh > report.md
   ```

   It prints the model, BIOS version, the SMBIOS 172 table, the WMI GUIDs and the firmware's read-back of every area. It contains no serial numbers.
4. Light the zones one at a time and note which part of the case reacts:

   ```bash
   orionctl set area1 -m static -c red
   orionctl set area2 -m static -c green
   orionctl set area3 -m static -c blue
   orionctl set area4 -m static -c yellow
   ```

Then open a "Model report" issue with the report and what you saw. That is enough to enable your model by default and give its zones proper names.

## What is not supported yet

- GPU lighting on models with an Acer graphics card. PredatorSense drives it over the card's I2C bus, which needs separate work; see [SAFETY.md](SAFETY.md).
- Memory lighting. The driver can expose it (`enable_dimm=1`) but nobody has tested it with RGB memory.
- Laptops. Predator and Nitro laptops use the same WMI GUID with different methods; the in-kernel `acer-wmi` driver and other projects cover their keyboards.
