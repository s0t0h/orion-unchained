# The Orion Unchained app

`orion-unchained` is the graphical side of Orion Unchained. It draws the case with every lighting zone in place and has every setting the firmware offers. It talks to the same driver and reads the same styles as `orionctl`, so you can use both side by side.

## Starting it

After `sudo make install` it is in your app menu as Orion Unchained. From a terminal:

```bash
orion-unchained          # the installed app
bin/orion-unchained      # straight from a git checkout
orion-unchained --demo   # a simulated PO7-660 that sends nothing to the hardware
```

`make shortcut`, run without sudo, adds Orion Unchained to your app menu and puts an icon on your desktop. Both start the app from this checkout. `make unshortcut` removes them; run it before `sudo make install` so the checkout entry does not hide the installed one.

The app needs PySide6 6.8 or newer; [INSTALL.md](INSTALL.md) lists the package for each distribution. If your account was added to the `orion-rgb` group and you have not logged in again since, the app runs itself through `sg orion-rgb` and can change the lights anyway.

## Lighting

The left side shows the case unfolded like a box: the rear panel, the inside as seen through the side window, the front panel with its emblem and two fans, and the radiator on top. Each zone is lit the way the hardware is set. The graphics card stays dark because its lighting is not supported yet. Click a part of the case, or one of the zone chips, to edit it.

The panel on the right has every setting of the selected zone: the effect, the colour (a colour wheel, the PredatorSense swatches or a hex code), brightness, speed, duration and direction. It hides the settings an effect does not use. Changes reach the hardware while you make them.

Whole case edits every zone at once. When the zones end up with the same settings, the app sends one global update, and the firmware then runs the effect over the whole case in sync; the header shows when that is so. When the zones differ, for example after a style that gives each zone its own colour, a change here only sets what you changed and each zone keeps the rest of its settings. Random colours are only offered for the whole case, because PredatorSense only offers them there and the driver follows PredatorSense.

Identify flashes the selected zone white for a few seconds, or every zone in turn when the whole case is selected, so you can see which part is which. The power button turns everything off and brings the previous look back.

The animations imitate the firmware's effects. Nobody has compared them with the real hardware side by side yet, so timing and shapes can differ, and what duration does is a guess (see [PROTOCOL.md](PROTOCOL.md)).

## Styles

The Styles page shows the library with a small preview of each style. Hover over a card to see it move, and click it to apply it. The search box matches names, descriptions, tags and authors, and the chips filter by tag.

Save as style, on the Lighting page, writes what the case shows to `~/.config/orion-unchained/styles/`, where `orionctl` finds it as well. The menu on each card copies a style as JSON, exports it to a file, opens GitHub's "Share a style" form with the JSON filled in, or moves one of your own styles to the trash. Import adds a style file you downloaded.

## Device

The Device page shows the model, the driver and the version of the firmware's lighting table. It runs the same checks as `orionctl doctor` and has a button to flash each zone. The zone names come from PredatorSense's layout tables; if a zone lights up somewhere you did not expect, please send a model report from there.

## How it treats the firmware

Every change to a zone takes two firmware calls, and each call briefly pauses all CPU cores ([SAFETY.md](SAFETY.md)). The app sends at most about seven updates a second, and while you drag a slider or the colour wheel it only sends the newest value. A second after the last change it saves the look to `/var/lib/orion-unchained/state.json`, which the boot service restores. While it is open it also picks up changes made with `orionctl`.

## Keyboard

| Keys | Action |
|---|---|
| Ctrl+1 to Ctrl+4 | switch pages |
| Ctrl+F | search the styles |
| Ctrl+S | save the current look as a style |
| Ctrl+Q | quit |

## Options

| Option | Effect |
|---|---|
| `--demo` | simulate a PO7-660; nothing reaches the hardware |
| `--page NAME` | open on `lighting`, `styles`, `device` or `about` |
| `--zone NAME` | select a zone, such as `front` or `area2` |
| `--screenshot FILE.png` | save the window after `--delay` milliseconds and quit, without sending anything to the hardware |
| `--check` | load every page in demo mode and report problems in the interface; `make check` runs this |
