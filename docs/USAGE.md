# Using orionctl

`orionctl` is the command-line front end of Orion Unchained. `orionctl --help` and `orionctl COMMAND --help` list every option.

## Zones

A zone is one lighting area that the firmware can set on its own. `orionctl zones` lists the ones your machine has. On the PO7-660:

| Name | Driver zone | Part of the case |
|---|---|---|
| `cpu` | `area1` | pump block of the liquid cooler |
| `front` | `area2` | front fans |
| `radiator`, `top` | `area3` | fans on the radiator |
| `rear` | `area4` | rear fan |
| `global` | `global` | all of the above with one command |
| `all` | | every area except `global` and memory, one by one |

Other models have other names (`front1`, `front2`, `bezel`, `lightbar` and so on); [HARDWARE.md](HARDWARE.md) has the full table. The driver's own names (`area1` to `area5`, `global`, `dimm`) work everywhere.

Setting `global` copies the effect to every area. Setting an area afterwards changes only that area.

## Effects

`orionctl modes` prints this table:

| Effect | Colour | Speed | Duration | Direction |
|---|---|---|---|---|
| static | yes | | | |
| breathing | yes | yes | yes | |
| heartbeat | yes | yes | yes | |
| twinkling | yes | yes | yes | |
| rainbow | | yes | | |
| wave | yes | yes | yes | |
| risen | | yes | yes | |
| stack | | yes | | yes |
| extend | | yes | | |
| meteorite | | yes | | |
| magic | | yes | | |
| snake | yes | yes | | yes |
| off | | | | |

Every effect also takes a brightness. PredatorSense only offers wave and snake on the global zone; the firmware accepts them on single areas too.

## Parameters

| Option | Values | Notes |
|---|---|---|
| `-m`, `--mode` | an effect from the table | |
| `-c`, `--color` | `RRGGBB`, `#RRGGBB`, a name, or `random` | names: red, green, blue, white, yellow, cyan, magenta, orange, purple, pink, black, predator (`00aec7`). `random` only works on `global` with breathing, heartbeat, twinkling, wave or snake. |
| `-b`, `--brightness` | 0 to 100 | percent |
| `-s`, `--speed` | 0 to 9 | higher is faster |
| `-t`, `--duration` | 0 to 9 | PredatorSense's default is 3 |
| `-d`, `--direction` | `left`, `right` | for stack and snake |

Options you leave out keep the zone's current value.

## Commands

```bash
orionctl status [--json]         # every zone's effect, colour and settings
orionctl zones                   # zone names on this machine
orionctl modes                   # effects and what they use
orionctl set ZONE... [options]   # change zones; without ZONE it means "all"
orionctl off [ZONE...]           # turn zones off
orionctl on                      # bring back the look from before "off"
orionctl save [FILE]             # save the current look
orionctl restore [FILE]          # apply a saved look
orionctl reapply                 # send the current state to the hardware again
orionctl style list [--tag TAG]  # the style library
orionctl style show NAME         # print a style's JSON
orionctl style apply NAME|FILE   # apply a style
orionctl style save NAME         # save the current look as a style
orionctl style validate FILE...  # check style files
orionctl doctor                  # check the installation
```

Some examples:

```bash
orionctl set -m static -c predator                  # Acer's cyan on every area
orionctl set global -m rainbow -s 3 -b 70           # a slow rainbow at 70 %
orionctl set front -m breathing -c ff0040 -s 2 -t 5
orionctl set global -m snake -c 00ff88 -d right
orionctl style list --tag linux
orionctl style apply ~/Downloads/someones-style.json
```

## What happens to your changes

After every `set`, `off`, `on` and `style apply`, orionctl saves the current look to `/var/lib/orion-unchained/state.json`. At boot `orion-unchained.service` applies that file, and after suspend or hibernation `orion-unchained-resume.service` sends the current state again. `off` also remembers the look it replaced in `last-on.json`, which is what `on` brings back.

Changes made by writing to sysfs directly are not saved until you run `orionctl save`.

## The sysfs interface

orionctl is a thin layer over the driver's files, which any program can use. They live under the WMI device the driver is bound to:

```bash
D=$(dirname /sys/bus/wmi/drivers/acer-predator-dt-rgb/*/zones)
cat $D/zones                 # global area1 area2 area3 area4
cat $D/smbios_version        # 6.2
cat $D/area2/mode            # static [breathing] heartbeat ... (current one in brackets)
echo ff2a6d > $D/area2/color
echo 60 > $D/area2/brightness
echo "mode=breathing color=00aec7 speed=3 duration=3 brightness=80" > $D/area2/effect
```

Each zone directory has `mode`, `color`, `brightness`, `speed`, `duration` and `direction`, which can be read and written, and `effect`, which is write-only and changes several properties with a single firmware update. Every write goes to the hardware at once. Invalid values are rejected with "Invalid argument" before the firmware is involved.

## Scripting

Anything that can run a command can drive the lights. A few ideas:

```bash
# dim everything at 23:00 (crontab -e)
0 23 * * * orionctl style apply night-owl

# colour the CPU block by package temperature
zone=$(dirname "$(grep -l x86_pkg_temp /sys/class/thermal/thermal_zone*/type | head -1)")
while sleep 5; do
    t=$(( $(cat "$zone/temp") / 1000 ))
    if   [ "$t" -ge 80 ]; then c=ff0000
    elif [ "$t" -ge 60 ]; then c=ffa000
    else c=00aec7; fi
    [ "$c" != "$last" ] && orionctl -q set cpu -m static -c "$c" && last=$c
done
```

`x86_pkg_temp` is the CPU package sensor on Intel machines.

Keep scripts to a change every few seconds at most. Each zone update is two firmware calls, and while the firmware handles a call every CPU core pauses for a moment. Changing only when the colour actually differs, as in the loop above, keeps that cost near zero.
