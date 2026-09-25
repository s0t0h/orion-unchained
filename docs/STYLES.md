# Styles

A style is a JSON file that describes the lighting of the whole case. Styles are how looks get shared: they are small, readable, diff well in git, and the future GUI will read and write the same format.

## Format 1

```json
{
  "format": 1,
  "name": "Lava",
  "author": "Orion Unchained",
  "description": "Glowing orange with a slow red heartbeat in the radiator.",
  "tags": ["nature"],
  "zones": {
    "front": {"mode": "static", "color": "ff3000"},
    "radiator": {"mode": "heartbeat", "color": "ff0000", "speed": 3, "duration": 3},
    "cpu": {"mode": "static", "color": "ff8000"},
    "rear": {"mode": "static", "color": "ff3000"}
  }
}
```

| Field | Required | Meaning |
|---|---|---|
| `format` | yes | Always `1` for now. |
| `name` | yes | Display name. |
| `author` | no | Who made it. |
| `description` | no | One sentence about the look. |
| `tags` | no | List of words for browsing, such as `nature`, `neon`, `animated`. |
| `zones` | yes | Map of zone name to zone settings, at least one entry. |

### Zone names

A key in `zones` can be:

- `global`, which sets every area in one go. Use it for effects that should run across the whole case.
- `all`, which applies the same settings to every area separately.
- a zone alias for the model, such as `front`, `rear`, `cpu`, `radiator` or `top` on the PO7-660, or `front1`, `front2` and `motherboard` on older PO7 and PO5 models. On those models `front` covers both front fans. [HARDWARE.md](HARDWARE.md) lists the aliases per model.
- a driver zone name: `area1` to `area5` or `dimm`.

orionctl applies `global` first, then `all`, then every named zone, so a style can set a base look and override single zones on top of it. A zone the machine does not have is skipped with a note, which lets one style work across models.

### Zone settings

| Key | Values | Default |
|---|---|---|
| `mode` | `static`, `breathing`, `heartbeat`, `twinkling`, `rainbow`, `wave`, `risen`, `stack`, `extend`, `meteorite`, `magic`, `snake`, `off` | `static` |
| `color` | `"RRGGBB"`, `"#RRGGBB"`, a colour name, or `"random"` | `"ffffff"` |
| `brightness` | 0 to 100 | 100 |
| `speed` | 0 to 9 | 5 |
| `duration` | 0 to 9 | 0 |
| `direction` | `0`, `1`, `"left"` or `"right"` | `0` (left) |

Missing keys take the default, so a style always produces the same result no matter what the lights showed before. Settings an effect does not use are harmless; [USAGE.md](USAGE.md) shows which effect uses what. `"random"` is only accepted on `global` with breathing, heartbeat, twinkling, wave or snake, because that is the only place PredatorSense offers it and the driver follows PredatorSense.

## Where styles live

orionctl looks in these places, in this order, and the first file with a given name wins:

1. `~/.config/orion-unchained/styles/` for your own styles
2. `/usr/local/share/orion-unchained/styles/` and `/usr/share/orion-unchained/styles/` for the installed library
3. `styles/` next to orionctl when it runs from a git checkout

A style is found by its file name without `.json` or by its `name`, so `orionctl style apply lava` and `orionctl style apply Lava` both work. A path works too.

## Making one

Set the lights up with `orionctl set`, then save them:

```bash
orionctl set front -m static -c ff0055
orionctl set radiator -m breathing -c 7000ff -s 2
orionctl style save "Night Drive" --description "Magenta and violet for late sessions" --tags neon,night
```

The file lands in `~/.config/orion-unchained/styles/night-drive.json`, using the zone aliases of your model. Open it in any editor to tweak it, and check it with `orionctl style validate FILE`.

## Sharing one

Send a pull request that adds your file to `styles/`, or open a "Share a style" issue with the JSON pasted in. Before you do:

- run `orionctl style validate` on it,
- look at it on real hardware, since colours on LEDs differ from colours on a screen (very dark colours mostly come out dim or off),
- name the file after the style in lower case with dashes, like `night-drive.json`,
- give it a description and a few tags.

Styles in this repository are distributed under the same licence as the rest of the project.

## What comes next

Format 1 describes what the firmware can do by itself. A later format will add software animation, with keyframes that move colours between zones over time, and reactive styles driven by temperatures, music or notifications. See [ROADMAP.md](ROADMAP.md).
