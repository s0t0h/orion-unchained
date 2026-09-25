# Firmware interface descriptions

Binary MOF from the WMI blocks of a Predator PO7-660 (BIOS 1.08), decoded with [bmf2mof](https://github.com/pali/bmfdec). They describe the method signatures the firmware itself declares.

| File | Classes |
|---|---|
| `mof/acer-wmi-classes.mof` | `AcerGamingFunction` (lighting, fans, overclocking), `BIOSSetting`, `UtilityFunction`, `APGeAction`, `AcerBiosConfigurationTool`, `APGeEvent` |
| `mof/wifi-sensor.mof` | `WiFi_GenericSensorData`, `WiFiSensorNotificationEvent` |
| `mof/debug-event.mof` | `FIRE_TEST_EVENT` |

Only four methods of `AcerGamingFunction` are used by Orion Unchained; see [../PROTOCOL.md](../PROTOCOL.md) and [../SAFETY.md](../SAFETY.md).

To produce the same files on your own machine:

```bash
for f in /sys/bus/wmi/devices/05901221-D566-11D1-B2F0-00A0C9062910-*/bmof; do sudo cat "$f" | bmf2mof; done
```
