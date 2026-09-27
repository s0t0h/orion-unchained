# SPDX-License-Identifier: GPL-2.0-or-later
"""Device access, validation, styles and saved state, shared by orionctl and the app.

Everything goes through the sysfs files of the acer_predator_dt_rgb driver,
which validates again in the kernel before anything reaches the firmware.
"""
import glob
import grp
import json
import os
import pwd
import re
import shlex
import sys
import tempfile
import time

SYSFS_DRIVER = "/sys/bus/wmi/drivers/acer-predator-dt-rgb"
STATE_DIR = "/var/lib/orion-unchained"
STATE_FILE = os.path.join(STATE_DIR, "state.json")
LAST_ON_FILE = os.path.join(STATE_DIR, "last-on.json")
# Kept across the sudo fallback so personal styles are still found.
USER_STYLE_DIR = os.environ.get("ORIONCTL_USER_STYLE_DIR",
                                os.path.expanduser("~/.config/orion-unchained/styles"))
_HERE = os.path.dirname(os.path.realpath(__file__))
SYSTEM_STYLE_DIRS = [
    "/usr/local/share/orion-unchained/styles",
    "/usr/share/orion-unchained/styles",
    os.path.join(_HERE, "..", "styles"),  # git checkout
]
STYLE_FORMAT = 1
GROUP = "orion-rgb"

# What each firmware effect uses, from PredatorSense's UI rules. "random" is
# only offered on the global zone.
MODES = {
    "static":    {"color": True,  "speed": False, "duration": False, "direction": False, "random": False},
    "breathing": {"color": True,  "speed": True,  "duration": True,  "direction": False, "random": True},
    "heartbeat": {"color": True,  "speed": True,  "duration": True,  "direction": False, "random": True},
    "twinkling": {"color": True,  "speed": True,  "duration": True,  "direction": False, "random": True},
    "rainbow":   {"color": False, "speed": True,  "duration": False, "direction": False, "random": False},
    "wave":      {"color": True,  "speed": True,  "duration": True,  "direction": False, "random": True},
    "risen":     {"color": False, "speed": True,  "duration": True,  "direction": False, "random": False},
    "stack":     {"color": False, "speed": True,  "duration": False, "direction": True,  "random": False},
    "extend":    {"color": False, "speed": True,  "duration": False, "direction": False, "random": False},
    "meteorite": {"color": False, "speed": True,  "duration": False, "direction": False, "random": False},
    "magic":     {"color": False, "speed": True,  "duration": False, "direction": False, "random": False},
    "snake":     {"color": True,  "speed": True,  "duration": False, "direction": True,  "random": True},
    "off":       {"color": False, "speed": False, "duration": False, "direction": False, "random": False},
}
GLOBAL_ONLY_IN_PREDATORSENSE = {"wave", "snake"}
DIMM_MODES = {"static", "breathing", "heartbeat", "twinkling", "rainbow", "risen", "off"}

DEFAULTS = {"mode": "static", "color": "ffffff", "brightness": 100, "speed": 5,
            "duration": 0, "direction": 0}
LIMITS = {"brightness": 100, "speed": 9, "duration": 9, "direction": 1}

# Zone names per model family, taken from PredatorSense's own layout tables
# (alias -> driver zones). The first matching entry wins, so specific models
# come first. A style may use any alias; zones a machine lacks are skipped.
MODELS = [
    ("PO7-660", {"cpu": ["area1"], "front": ["area2"], "radiator": ["area3"], "top": ["area3"],
                 "rear": ["area4"], "memory": ["dimm"]}),
    ("PO7", {"cpu": ["area1"], "front1": ["area2"], "front2": ["area3"], "front": ["area2", "area3"],
             "rear": ["area4"], "motherboard": ["area5"], "memory": ["dimm"]}),
    ("PO5", {"cpu": ["area1"], "front1": ["area2"], "front2": ["area3"], "front": ["area2", "area3"],
             "rear": ["area4"], "motherboard": ["area5"], "memory": ["dimm"]}),
    ("PO3", {"cpu": ["area1"], "front": ["area2"], "rear": ["area3"], "lightbar": ["area4"]}),
    ("POX", {"cpu": ["area1"], "sysfan1": ["area2"], "sysfan2": ["area3"], "fans": ["area2", "area3"],
             "bezel": ["area4"], "memory": ["dimm"]}),
]

COLORS = {
    "red": "ff0000", "green": "00ff00", "blue": "0000ff", "white": "ffffff",
    "yellow": "ffff00", "cyan": "00ffff", "magenta": "ff00ff", "orange": "ff6000",
    "purple": "8000ff", "pink": "ff2080", "black": "000000",
    "predator": "00aec7",
}


class OrionError(Exception):
    """A problem worth showing to the user as is."""


def read(path):
    with open(path) as f:
        return f.read().strip()


# --- device -----------------------------------------------------------------

def device_dir(wait=0.0):
    deadline = time.monotonic() + wait
    while True:
        found = glob.glob(os.path.join(SYSFS_DRIVER, "*", "zones"))
        if found:
            return os.path.dirname(found[0])
        if time.monotonic() >= deadline:
            return None
        time.sleep(0.5)


def product_name():
    try:
        return read("/sys/class/dmi/id/product_name")
    except OSError:
        return ""


def driver_version():
    try:
        return read("/sys/module/acer_predator_dt_rgb/version")
    except OSError:
        return ""


def transport(dev):
    """How the driver reaches the lighting controller: "smbus", "wmi", or "" for drivers before 0.2.0."""
    try:
        return read(os.path.join(dev, "transport"))
    except OSError:
        return ""


def zone_aliases():
    name = product_name()
    for key, table in MODELS:
        if key in name:
            return table
    return {}


def names_for(zone, aliases):
    """Aliases that point at exactly this one zone."""
    return [a for a, targets in aliases.items() if targets == [zone]]


def zone_label(zone, aliases):
    names = names_for(zone, aliases)
    return f"{zone} ({'/'.join(names)})" if names else zone


def zones(dev):
    return read(os.path.join(dev, "zones")).split()


def read_zone(dev, zone):
    d = os.path.join(dev, zone)
    m = re.search(r"\[(\w+)\]", read(os.path.join(d, "mode")))
    state = {"mode": m.group(1) if m else "static", "color": read(os.path.join(d, "color"))}
    for key in ("brightness", "speed", "duration", "direction"):
        state[key] = int(read(os.path.join(d, key)))
    return state


def read_all(dev):
    return {z: read_zone(dev, z) for z in zones(dev)}


def resolve_zone(dev, name, aliases, strict=True, warn=None):
    """Map a user-facing zone name to driver zones. Non-strict lookups skip missing zones."""
    return resolve_in(zones(dev), name, aliases, strict, warn)


def resolve_in(available, name, aliases, strict=True, warn=None):
    name = name.lower()
    if name == "all":
        return [z for z in available if z not in ("global", "dimm")]
    if name in available:
        return [name]
    present = [z for z in aliases.get(name, []) if z in available]
    if present:
        return present
    if not strict:
        if warn:
            warn(f"skipping {name!r}: this machine has no such zone")
        return []
    known = sorted(set(available) | {a for a, t in aliases.items() if any(z in available for z in t)} | {"all"})
    raise OrionError(f"unknown zone {name!r}; this machine has: {' '.join(known)}")


def can_write(dev, zone_list):
    return all(os.access(os.path.join(dev, z, "effect"), os.W_OK) for z in zone_list)


def in_group_file():
    """True when the user is listed in orion-rgb but this login session predates it."""
    try:
        group = grp.getgrnam(GROUP)
    except KeyError:
        return False
    user = pwd.getpwuid(os.getuid()).pw_name
    return group.gr_gid not in os.getgroups() and user in group.gr_mem


def reexec_with_group(argv):
    """Re-run the program through sg so a fresh group membership works without logging out."""
    if os.geteuid() == 0 or os.environ.get("ORION_UNCHAINED_SG") or not in_group_file():
        return
    os.environ["ORION_UNCHAINED_SG"] = "1"
    os.execvp("sg", ["sg", GROUP, "-c", shlex.join([sys.executable, *argv])])


def normalize(zone_state):
    """Fill in defaults so two states compare equal when they look the same."""
    s = dict(DEFAULTS)
    s.update({k: v for k, v in zone_state.items() if v is not None})
    return s


def concrete(zone, state):
    """A global random colour is mirrored into every area; areas themselves need a real colour."""
    s = dict(state)
    if zone != "global" and s.get("color") == "random":
        s["color"] = DEFAULTS["color"]
    return s


def is_lit(state):
    """Whether a zone gives off light: off and brightness 0 are both dark."""
    s = normalize(state)
    return s["mode"] != "off" and s["brightness"] > 0


def wake(old, changes):
    """Changes for a zone that may be leaving "off", which is stored with brightness 0.

    Without this, picking an effect for a zone that was switched off would keep
    it dark until the brightness is raised by hand.
    """
    old = normalize(old)
    if (old["mode"] == "off" and changes.get("mode", "off") != "off"
            and old["brightness"] == 0 and "brightness" not in changes):
        return dict(changes, brightness=DEFAULTS["brightness"])
    return changes


def effect_string(state):
    s = normalize(state)
    if s["mode"] == "off":
        # The PO7-660 firmware ignores the off mode and keeps the LEDs lit, but it
        # honours brightness 0.
        s["brightness"] = 0
    return (f"mode={s['mode']} color={s['color']} brightness={s['brightness']} "
            f"speed={s['speed']} duration={s['duration']} direction={s['direction']}")


def write_zone(dev, zone, state):
    effect = effect_string(state)
    try:
        with open(os.path.join(dev, zone, "effect"), "w") as f:
            f.write(effect)
    except OSError as e:
        raise OrionError(f"{zone}: the driver rejected '{effect}' ({e.strerror})") from e
    return effect


# --- validation -------------------------------------------------------------

def parse_color(value):
    value = str(value).strip().lower().lstrip("#")
    value = COLORS.get(value, value)
    if value == "random" or re.fullmatch(r"[0-9a-f]{6}", value):
        return value
    raise ValueError(f"{value!r} is not RRGGBB, a colour name or 'random'")


def check_zone_state(zone_key, state):
    errors = []
    if not isinstance(state, dict):
        return [f"{zone_key}: expected an object"]
    unknown = set(state) - set(DEFAULTS)
    if unknown:
        errors.append(f"{zone_key}: unknown field(s) {', '.join(sorted(unknown))}")
    mode = state.get("mode", DEFAULTS["mode"])
    if mode not in MODES:
        errors.append(f"{zone_key}: unknown mode {mode!r}")
    elif zone_key == "dimm" and mode not in DIMM_MODES:
        errors.append(f"dimm: {mode} is not offered for memory lighting")
    if "color" in state:
        try:
            color = parse_color(state["color"])
            if color == "random" and (zone_key != "global" or not MODES.get(mode, {}).get("random")):
                errors.append(f"{zone_key}: 'random' colour only works on the global zone "
                              f"with breathing, heartbeat, twinkling, wave or snake")
        except ValueError as e:
            errors.append(f"{zone_key}: {e}")
    for key, limit in LIMITS.items():
        if key in state:
            v = state[key]
            if key == "direction" and v in ("left", "right"):
                continue
            if not isinstance(v, int) or isinstance(v, bool) or not 0 <= v <= limit:
                errors.append(f"{zone_key}: {key} must be an integer 0-{limit}")
    return errors


def validate_style(doc):
    errors = []
    if not isinstance(doc, dict):
        return ["style must be a JSON object"]
    if doc.get("format") != STYLE_FORMAT:
        errors.append(f"'format' must be {STYLE_FORMAT}")
    if not isinstance(doc.get("name"), str) or not doc["name"].strip():
        errors.append("'name' is required")
    for key in ("description", "author"):
        if key in doc and not isinstance(doc[key], str):
            errors.append(f"'{key}' must be a string")
    if "tags" in doc and not (isinstance(doc["tags"], list) and all(isinstance(t, str) for t in doc["tags"])):
        errors.append("'tags' must be a list of strings")
    z = doc.get("zones")
    if not isinstance(z, dict) or not z:
        errors.append("'zones' must be a non-empty object")
    else:
        for zone_key, state in z.items():
            errors += check_zone_state(zone_key, state)
    return errors


def prepare_state(state):
    s = dict(state)
    if "color" in s:
        s["color"] = parse_color(s["color"])
    if s.get("direction") in ("left", "right"):
        s["direction"] = 0 if s["direction"] == "left" else 1
    return s


# --- applying ---------------------------------------------------------------

def plan_style(dev, doc, aliases, warn=None):
    """Turn a style's zone map into an ordered list of (zone, state) writes."""
    return plan_in(zones(dev), doc, aliases, warn)


def plan_in(available, doc, aliases, warn=None):
    z = doc["zones"]
    order = sorted(z, key=lambda k: 0 if k == "global" else 1 if k == "all" else 2)
    plan = []
    for key in order:
        state = prepare_state(z[key])
        for zone in resolve_in(available, key, aliases, strict=False, warn=warn):
            plan.append((zone, state))
    if not plan:
        raise OrionError("this style has no zone that exists on this machine")
    return plan


def preview_style(doc, area_names, aliases):
    """Resulting state per area when the style is applied, without touching the hardware."""
    z = doc["zones"]
    order = sorted(z, key=lambda k: 0 if k == "global" else 1 if k == "all" else 2)
    result = {}
    for key in order:
        state = normalize(prepare_state(z[key]))
        if key == "global" or key == "all":
            targets = [a for a in area_names if a != "dimm"]
        elif key in area_names:
            targets = [key]
        else:
            targets = [t for t in aliases.get(key, []) if t in area_names]
        for t in targets:
            result[t] = state
    return result


def snapshot(dev):
    """Current look as a style document; one global entry when all areas match."""
    return snapshot_from_states(read_all(dev))


def snapshot_from_states(all_states):
    """Areas that still show the last global effect are saved through global.

    Only a global write can give areas a random colour, and a random colour is
    only valid on global, so this is also what keeps such a look restorable.
    """
    states = {z: normalize(s) for z, s in all_states.items() if z != "global"}
    base = normalize(all_states["global"]) if "global" in all_states else None
    areas = [z for z in states if z != "dimm"]
    if areas and all(states[a] == states[areas[0]] for a in areas):
        zones_doc = {"global": states[areas[0]]}
    elif base and any(states[a] == base for a in areas):
        zones_doc = {"global": base}
        zones_doc.update({a: states[a] for a in areas if states[a] != base})
    else:
        zones_doc = {z: concrete(z, states[z]) for z in areas}
    if "dimm" in states:
        zones_doc["dimm"] = states["dimm"]
    return {"format": STYLE_FORMAT, "name": "Saved state", "zones": zones_doc}


def write_json(path, doc, mode=0o664):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".tmp-")
    with os.fdopen(fd, "w") as f:
        json.dump(doc, f, indent=2)
        f.write("\n")
    os.chmod(tmp, mode)
    os.replace(tmp, path)


def save_state(dev, path):
    write_json(path, snapshot(dev))


# --- styles -----------------------------------------------------------------

def slug(name):
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


def style_dirs():
    dirs = [USER_STYLE_DIR] + SYSTEM_STYLE_DIRS
    seen, out = set(), []
    for d in dirs:
        real = os.path.realpath(d)
        if real not in seen and os.path.isdir(real):
            seen.add(real)
            out.append(real)
    return out


def load_style_file(path):
    try:
        with open(path) as f:
            doc = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        raise ValueError(f"{path}: {e}") from e
    errors = validate_style(doc)
    if errors:
        raise ValueError(f"{path}: " + "; ".join(errors))
    return doc


def all_styles(warn=None):
    """slug -> (path, doc); user styles shadow system styles of the same name."""
    found = {}
    for d in style_dirs():
        for path in sorted(glob.glob(os.path.join(d, "*.json"))):
            key = os.path.splitext(os.path.basename(path))[0]
            if key in found:
                continue
            try:
                found[key] = (path, load_style_file(path))
            except ValueError as e:
                if warn:
                    warn(f"skipping {e}")
    return found


def find_style(name):
    if os.path.sep in name or name.endswith(".json"):
        try:
            return name, load_style_file(name)
        except ValueError as e:
            raise OrionError(str(e)) from e
    styles = all_styles()
    key = slug(name)
    if key in styles:
        return styles[key]
    for path, doc in styles.values():
        if slug(doc["name"]) == key:
            return path, doc
    raise OrionError(f"no style called {name!r}; see 'orionctl style list'")


def style_from_snapshot(dev, name, author="", description="", tags=()):
    """The current look as a named style, using the model's zone aliases."""
    return style_from_states(read_all(dev), name, author, description, tags)


def style_from_states(all_states, name, author="", description="", tags=()):
    doc = snapshot_from_states(all_states)
    aliases = zone_aliases()
    named = {}
    for zone, state in doc["zones"].items():
        names = names_for(zone, aliases)
        named[names[0] if names else zone] = {k: v for k, v in state.items()
                                              if k in ("mode", "color") or v != DEFAULTS[k]}
    return {"format": STYLE_FORMAT, "name": name, "author": author, "description": description,
            "tags": [t for t in tags if t], "zones": named}
