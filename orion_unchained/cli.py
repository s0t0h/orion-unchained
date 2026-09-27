# SPDX-License-Identifier: GPL-2.0-or-later
"""orionctl: lighting control for Acer Predator Orion desktops (Orion Unchained).

Talks to the acer_predator_dt_rgb kernel driver through sysfs. Styles are
plain JSON files, see docs/STYLES.md.

Examples:
  orionctl status
  orionctl set front rear -m breathing -c purple -s 3
  orionctl set global -m rainbow -b 60
  orionctl style list
  orionctl style apply synthwave
  orionctl off
"""
import argparse
import json
import os
import subprocess
import sys

from . import VERSION, core
from .core import OrionError

QUIET = False


def say(msg):
    if not QUIET:
        print(msg)


def die(msg, code=1):
    print(f"orionctl: {msg}", file=sys.stderr)
    sys.exit(code)


def require_device(wait=0.0):
    dev = core.device_dir(wait)
    if not dev:
        die("the acer_predator_dt_rgb driver is not loaded (try: sudo modprobe acer_predator_dt_rgb, "
            "or run 'orionctl doctor')")
    return dev


def ensure_writable(dev, zone_list):
    if core.can_write(dev, zone_list):
        return
    core.reexec_with_group(sys.argv)
    if os.geteuid() == 0:
        die("cannot write to the driver's sysfs files even as root")
    say(f"note: no write access yet (join the '{core.GROUP}' group and log in again); using sudo")
    os.execvp("sudo", ["sudo", "env", f"ORIONCTL_USER_STYLE_DIR={core.USER_STYLE_DIR}",
                       sys.executable, *sys.argv])


def resolve(dev, name, aliases):
    try:
        return core.resolve_zone(dev, name, aliases)
    except OrionError as e:
        die(str(e))


def plan_style(dev, doc, aliases):
    try:
        return core.plan_style(dev, doc, aliases, warn=lambda m: say(f"  ({m})"))
    except OrionError as e:
        die(str(e))


def apply_plan(dev, plan):
    ensure_writable(dev, [zone for zone, _ in plan])
    for zone, state in plan:
        try:
            effect = core.write_zone(dev, zone, state)
        except OrionError as e:
            die(str(e))
        say(f"  {zone:7s} {effect}")


def save_state(dev, path, quiet_fail=False):
    try:
        core.save_state(dev, path)
        return True
    except OSError as e:
        if not quiet_fail:
            die(f"cannot save state to {path}: {e.strerror}")
        return False


def load_style(path):
    try:
        return core.load_style_file(path)
    except ValueError as e:
        die(str(e))


def find_style(name):
    try:
        return core.find_style(name)
    except OrionError as e:
        die(str(e))


def color_arg(value):
    """argparse type: turn parse_color's error into a readable usage message."""
    try:
        return core.parse_color(value)
    except ValueError as e:
        raise argparse.ArgumentTypeError(str(e))


# --- commands ---------------------------------------------------------------

def cmd_status(args):
    dev = require_device()
    aliases = core.zone_aliases()
    states = core.read_all(dev)
    smbios = core.read(os.path.join(dev, "smbios_version"))
    transport = core.transport(dev)
    if args.json:
        print(json.dumps({"model": core.product_name(), "smbios_version": smbios, "transport": transport or None,
                          "zones": {z: dict(s, aliases=core.names_for(z, aliases)) for z, s in states.items()}},
                         indent=2))
        return
    print(f"{core.product_name() or 'unknown model'}, SMBIOS 172 v{smbios}"
          + (f", {transport} transport" if transport else ""))
    for zone, s in states.items():
        mode = core.MODES.get(s["mode"], {})
        extra = []
        if mode.get("speed"):
            extra.append(f"speed {s['speed']}")
        if mode.get("duration"):
            extra.append(f"duration {s['duration']}")
        if mode.get("direction"):
            extra.append("right" if s["direction"] else "left")
        color = s["color"] if mode.get("color") else "-"
        print(f"  {core.zone_label(zone, aliases):20s} {s['mode']:10s} {color:7s} "
              f"{s['brightness']:3d}%  {', '.join(extra)}")


def cmd_zones(args):
    dev = require_device()
    aliases = core.zone_aliases()
    for zone in core.zones(dev):
        names = ", ".join(core.names_for(zone, aliases)) or ("every area at once" if zone == "global" else "")
        print(f"  {zone:7s} {names}")
    for alias, targets in aliases.items():
        if len(targets) > 1:
            print(f"  {alias:7s} {' + '.join(targets)}")
    print("  all     every area except global and memory")


def cmd_modes(args):
    print(f"  {'mode':10s} colour  speed  duration  direction")
    for name, m in core.MODES.items():
        note = "  (PredatorSense offers this on global only)" if name in core.GLOBAL_ONLY_IN_PREDATORSENSE else ""
        print(f"  {name:10s} {'yes' if m['color'] else '-':7s} {'yes' if m['speed'] else '-':6s} "
              f"{'yes' if m['duration'] else '-':9s} {'yes' if m['direction'] else '-'}{note}")


def targets_for(dev, names):
    aliases = core.zone_aliases()
    targets = []
    for name in names or ["all"]:
        targets += resolve(dev, name, aliases)
    return list(dict.fromkeys(targets))


def cmd_set(args):
    dev = require_device()
    state = {"mode": args.mode, "color": args.color, "brightness": args.brightness,
             "speed": args.speed, "duration": args.duration, "direction": args.direction}
    given = {k: v for k, v in state.items() if v is not None}
    if not given:
        die("nothing to set; pass at least one of -m/-c/-b/-s/-t/-d")
    plan = []
    for zone in targets_for(dev, args.zones):
        current = core.concrete(zone, core.read_zone(dev, zone))
        merged = dict(current, **core.wake(current, core.prepare_state(given)))
        errors = core.check_zone_state(zone, merged)
        if errors:
            die("; ".join(errors))
        plan.append((zone, merged))
    apply_plan(dev, plan)
    save_state(dev, core.STATE_FILE, quiet_fail=True)


def cmd_off(args):
    dev = require_device()
    targets = targets_for(dev, args.zones)
    plan = [(z, dict(core.concrete(z, core.read_zone(dev, z)), mode="off")) for z in targets]
    ensure_writable(dev, targets)
    # Remember the lit look for 'orionctl on', then persist "off" for the next boot.
    if any(core.is_lit(s) for s in core.read_all(dev).values()):
        save_state(dev, core.LAST_ON_FILE, quiet_fail=True)
    apply_plan(dev, plan)
    save_state(dev, core.STATE_FILE, quiet_fail=True)


def cmd_on(args):
    dev = require_device()
    if not os.path.exists(core.LAST_ON_FILE):
        die("no previous look saved yet; pick one with 'orionctl style apply NAME'")
    doc = load_style(core.LAST_ON_FILE)
    apply_plan(dev, plan_style(dev, doc, core.zone_aliases()))
    save_state(dev, core.STATE_FILE, quiet_fail=True)


def cmd_save(args):
    dev = require_device()
    save_state(dev, args.file)
    say(f"saved to {args.file}")


def cmd_restore(args):
    dev = core.device_dir(args.wait)
    if not dev:
        die("driver not loaded, nothing to restore")
    if not os.path.exists(args.file):
        say(f"no saved state at {args.file}, leaving the lights as they are")
        return
    doc = load_style(args.file)
    say(f"restoring {args.file}")
    apply_plan(dev, plan_style(dev, doc, core.zone_aliases()))


def cmd_reapply(args):
    dev = require_device()
    say("re-applying the driver's current state")
    apply_plan(dev, plan_style(dev, core.snapshot(dev), core.zone_aliases()))


def cmd_style_list(args):
    styles = core.all_styles(warn=lambda m: print(f"orionctl: {m}", file=sys.stderr))
    rows = []
    for key, (path, doc) in sorted(styles.items(), key=lambda kv: kv[1][1]["name"].lower()):
        tags = doc.get("tags", [])
        if args.tag and args.tag.lower() not in [t.lower() for t in tags]:
            continue
        rows.append((key, doc, path))
    if args.json:
        print(json.dumps([dict(doc, id=key, path=path) for key, doc, path in rows], indent=2))
        return
    for key, doc, _ in rows:
        print(f"  {key:24s} {doc.get('description', '')}")
    say(f"\n{len(rows)} styles; apply one with: orionctl style apply NAME")


def cmd_style_show(args):
    path, doc = find_style(args.name)
    print(f"# {path}")
    print(json.dumps(doc, indent=2))


def cmd_style_apply(args):
    dev = require_device()
    path, doc = find_style(args.name)
    say(f"{doc['name']}: {doc.get('description', '')}".rstrip(": "))
    apply_plan(dev, plan_style(dev, doc, core.zone_aliases()))
    save_state(dev, core.STATE_FILE, quiet_fail=True)


def cmd_style_save(args):
    dev = require_device()
    doc = core.style_from_snapshot(dev, args.name, author=args.author or os.environ.get("USER", ""),
                                   description=args.description or "", tags=(args.tags or "").split(","))
    path = os.path.join(core.USER_STYLE_DIR, core.slug(args.name) + ".json")
    core.write_json(path, doc, mode=0o644)
    say(f"saved {path}")


def cmd_style_validate(args):
    bad = 0
    for path in args.files:
        try:
            core.load_style_file(path)
            say(f"ok    {path}")
        except ValueError as e:
            print(f"FAIL  {e}")
            bad += 1
    sys.exit(1 if bad else 0)


def cmd_doctor(args):
    checks = doctor_checks()
    print(f"orionctl {VERSION}, model: {core.product_name() or 'unknown'}")
    for ok, text, hint in checks:
        print(f"  [{'ok' if ok else '!!'}] {text}")
        if not ok and hint:
            print(f"       {hint}")
    sys.exit(0 if all(ok for ok, _, _ in checks) else 1)


def doctor_checks():
    """(ok, text, hint) tuples, shared with the app's device page."""
    checks = []
    loaded = os.path.isdir("/sys/module/acer_predator_dt_rgb")
    version = core.driver_version()
    checks.append((loaded, f"kernel module loaded ({version or 'unknown version'})" if loaded else
                   "kernel module not loaded",
                   "sudo modprobe acer_predator_dt_rgb   (install with: sudo make install)"))
    dev = core.device_dir()
    if dev:
        transport = core.transport(dev)
        checks.append((True, f"driver bound: zones {' '.join(core.zones(dev))}, SMBIOS 172 v"
                             f"{core.read(os.path.join(dev, 'smbios_version'))}"
                             + (f", {transport} transport" if transport else ""), ""))
        writable = core.can_write(dev, core.zones(dev))
        if not writable and core.in_group_file():
            hint = "you are in the group already; log out and back in once"
        else:
            hint = f"sudo usermod -aG {core.GROUP} $USER, then log out and back in"
        checks.append((writable, "this user can change the lights" if writable else
                       "this user cannot write the zone files", hint))
    else:
        checks.append((False, "no device bound", "see 'sudo dmesg | grep acer-predator' for the reason"))
    try:
        out = subprocess.run(["dkms", "status", "acer-predator-dt-rgb"], capture_output=True, text=True).stdout.strip()
    except OSError:
        out = ""
    checks.append(("installed" in out, f"DKMS: {out}" if "installed" in out else
                   "not installed through DKMS (manual insmod?)",
                   "sudo make install   (rebuilds automatically on kernel updates)"))
    try:
        enabled = subprocess.run(["systemctl", "is-enabled", "orion-unchained.service"],
                                 capture_output=True, text=True).stdout.strip()
    except OSError:
        enabled = ""
    checks.append((enabled == "enabled", "boot restore service enabled" if enabled == "enabled" else
                   "boot restore service not enabled", "sudo systemctl enable orion-unchained.service"))
    have_state = os.path.exists(core.STATE_FILE)
    checks.append((have_state, f"saved state: {core.STATE_FILE}" if have_state else "no saved state yet",
                   "any 'orionctl set' or 'orionctl style apply' creates it"))
    return checks


def main():
    global QUIET
    p = argparse.ArgumentParser(prog="orionctl", description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--version", action="version", version=f"orionctl {VERSION}")
    p.add_argument("-q", "--quiet", action="store_true", help="only print errors")
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("status", help="show every zone")
    s.add_argument("--json", action="store_true")
    s.set_defaults(func=cmd_status)
    sub.add_parser("zones", help="list zone names").set_defaults(func=cmd_zones)
    sub.add_parser("modes", help="list effects and what they use").set_defaults(func=cmd_modes)

    s = sub.add_parser("set", help="change zones (default: all)")
    s.add_argument("zones", nargs="*", metavar="ZONE", help="global, all, front, rear, cpu, radiator, area1...")
    s.add_argument("-m", "--mode", choices=list(core.MODES))
    s.add_argument("-c", "--color", type=color_arg, help="RRGGBB, a colour name, or 'random' (global)")
    s.add_argument("-b", "--brightness", type=int, choices=range(0, 101), metavar="0-100")
    s.add_argument("-s", "--speed", type=int, choices=range(0, 10), metavar="0-9")
    s.add_argument("-t", "--duration", type=int, choices=range(0, 10), metavar="0-9")
    s.add_argument("-d", "--direction", choices=["left", "right"])
    s.set_defaults(func=cmd_set)

    s = sub.add_parser("off", help="turn zones off (default: all)")
    s.add_argument("zones", nargs="*", metavar="ZONE")
    s.set_defaults(func=cmd_off)
    sub.add_parser("on", help="bring back the look from before 'off'").set_defaults(func=cmd_on)

    s = sub.add_parser("save", help="save the current look (restored at boot)")
    s.add_argument("file", nargs="?", default=core.STATE_FILE)
    s.set_defaults(func=cmd_save)
    s = sub.add_parser("restore", help="apply a saved look")
    s.add_argument("file", nargs="?", default=core.STATE_FILE)
    s.add_argument("--wait", type=float, default=0, metavar="SECONDS", help="wait for the driver")
    s.set_defaults(func=cmd_restore)
    sub.add_parser("reapply", help="push the current state to the hardware again").set_defaults(func=cmd_reapply)

    st = sub.add_parser("style", help="list, apply and create styles").add_subparsers(dest="style_cmd", required=True)
    s = st.add_parser("list")
    s.add_argument("--tag")
    s.add_argument("--json", action="store_true")
    s.set_defaults(func=cmd_style_list)
    s = st.add_parser("show")
    s.add_argument("name")
    s.set_defaults(func=cmd_style_show)
    s = st.add_parser("apply")
    s.add_argument("name", help="style name or path to a .json file")
    s.set_defaults(func=cmd_style_apply)
    s = st.add_parser("save", help="save the current look as a style in ~/.config/orion-unchained/styles")
    s.add_argument("name")
    s.add_argument("--description")
    s.add_argument("--author")
    s.add_argument("--tags", help="comma separated")
    s.set_defaults(func=cmd_style_save)
    s = st.add_parser("validate")
    s.add_argument("files", nargs="+")
    s.set_defaults(func=cmd_style_validate)

    sub.add_parser("doctor", help="check the installation").set_defaults(func=cmd_doctor)

    args = p.parse_args()
    QUIET = args.quiet
    args.func(args)
