# SPDX-License-Identifier: GPL-2.0-or-later
"""Orion Unchained app: the Qt Quick window, its backend object and the firmware writer.

Every change to a zone becomes one write to the driver's "effect" file. That
costs two firmware calls, each a software SMI that pauses every CPU core, plus
40 ms of settling time. The writer thread keeps only the newest state per zone
and leaves a gap between writes, so dragging a slider never floods the firmware.
"""
import argparse
import collections
import json
import os
import pwd
import sys
import threading
import time
import urllib.parse

from PySide6.QtCore import Property, QFile, QObject, QTimer, QUrl, Signal, Slot
from PySide6.QtGui import QDesktopServices, QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine, QQmlEngine, QQmlExpression
from PySide6.QtQuick import QQuickWindow  # noqa: F401  (lets rootObjects() return a QQuickWindow)
from PySide6.QtQuickControls2 import QQuickStyle
from PySide6.QtWidgets import QApplication

from .. import VERSION, core
from ..cli import doctor_checks

HERE = os.path.dirname(os.path.abspath(__file__))
QML_MAIN = os.path.join(HERE, "qml", "Main.qml")
ICON = os.path.join(HERE, "icons", "orion-unchained.svg")
PROJECT_URL = "https://github.com/s0t0h/orion-unchained"

MIN_GAP = 0.1          # seconds between two firmware updates
SAVE_DELAY_MS = 1000   # quiet time before the look is saved for the next boot
POLL_MS = 2000         # how often to pick up changes made with orionctl
IDENTIFY_MS = 2600
IDENTIFY = {"mode": "breathing", "color": "ffffff", "brightness": 100, "speed": 9,
            "duration": 0, "direction": 0}

# PredatorSense's five swatches first, then a few more.
SWATCHES = ["00aec7", "3cf03c", "ff0000", "ffa000", "a000ff", "ffffff",
            "ff2080", "ff00d0", "0050ff", "00ffa0", "ffe000", "ff5000"]

LABELS = {
    "global": "Whole case", "cpu": "CPU cooler", "front": "Front", "front1": "Front fan 1",
    "front2": "Front fan 2", "radiator": "Radiator", "rear": "Rear fan", "motherboard": "Motherboard",
    "lightbar": "Light bar", "sysfan1": "System fan 1", "sysfan2": "System fan 2", "bezel": "Bezel",
    "memory": "Memory",
}

MODE_TEXT = {
    "static": ("Static", "One steady colour."),
    "breathing": ("Breathing", "Fades in and out."),
    "heartbeat": ("Heartbeat", "Two quick beats, then a pause."),
    "twinkling": ("Twinkling", "Blinks on for a second, then stays dark for a few."),
    "rainbow": ("Rainbow", "One colour at a time, slowly going round the colour wheel."),
    "wave": ("Wave", "A pulse of light runs through the case, then a pause."),
    "risen": ("Risen", "A rainbow that climbs slowly up the case."),
    "stack": ("Stack", "LEDs pile up along each zone while the colour changes."),
    "extend": ("Extend", "Light spreads round each fan, holds and fades, in ever-changing colours."),
    "meteorite": ("Meteorite", "Meteors in random colours run through each zone."),
    "magic": ("Magic", "Bands of light sweep through each zone as the colours cycle."),
    "snake": ("Snake", "A snake runs round each zone, through all of its fans."),
    "off": ("Off", "No light."),
}

PAGES = ["lighting", "styles", "device", "about"]
DEMO_STYLE = "synthwave"


class SysfsDevice:
    """The acer_predator_dt_rgb driver's sysfs files."""

    def __init__(self, path):
        self.path = path

    def zones(self):
        return core.zones(self.path)

    def read_all(self):
        return core.read_all(self.path)

    def write(self, zone, state):
        core.write_zone(self.path, zone, core.concrete(zone, state))

    def writable(self):
        return core.can_write(self.path, self.zones())

    def smbios_version(self):
        return core.read(os.path.join(self.path, "smbios_version"))

    def save(self, path):
        core.save_state(self.path, path)


class DemoDevice:
    """A PO7-660 that only exists in memory, for --demo and machines without the driver."""

    def __init__(self, states):
        self._states = {z: core.normalize(s) for z, s in states.items()}
        self._lock = threading.Lock()

    def zones(self):
        return list(self._states)

    def read_all(self):
        with self._lock:
            return {z: dict(s) for z, s in self._states.items()}

    def write(self, zone, state):
        time.sleep(0.04)  # what the real firmware round trip costs
        with self._lock:
            s = core.normalize(state)
            self._states[zone] = s
            if zone == "global":
                for z in self._states:
                    if z not in ("global", "dimm"):
                        self._states[z] = dict(s)

    def writable(self):
        return True

    def smbios_version(self):
        return "6.2"

    def save(self, path):
        pass


class Writer(QObject):
    """Sends zone states from a background thread; the newest state per zone wins."""

    done = Signal(str, str)  # zone, error message ("" when it worked)
    idle = Signal()

    def __init__(self, device):
        super().__init__()
        self.device = device
        self._pending = collections.OrderedDict()
        self._cond = threading.Condition()
        self._active = False
        self._last = 0.0
        threading.Thread(target=self._run, name="orion-writer", daemon=True).start()

    def submit(self, zone, state):
        with self._cond:
            if zone == "global":
                # The firmware copies a global effect to every area, so queued area changes are moot.
                for z in [z for z in self._pending if z not in ("global", "dimm")]:
                    del self._pending[z]
            # A newer state replaces the queued one and goes to the back, after any queued global.
            self._pending[zone] = dict(state)
            self._pending.move_to_end(zone)
            self._cond.notify_all()

    def busy(self):
        with self._cond:
            return self._active or bool(self._pending)

    def flush(self, timeout):
        deadline = time.monotonic() + timeout
        with self._cond:
            while self._active or self._pending:
                left = deadline - time.monotonic()
                if left <= 0:
                    return False
                self._cond.wait(left)
        return True

    def _run(self):
        while True:
            with self._cond:
                while not self._pending:
                    self._cond.wait()
                gap = self._last + MIN_GAP - time.monotonic()
            if gap > 0:
                time.sleep(gap)  # changes arriving meanwhile replace the queued ones
            with self._cond:
                if not self._pending:
                    continue
                zone, state = self._pending.popitem(last=False)
                self._active = True
            error = ""
            try:
                self.device.write(zone, state)
            except core.OrionError as e:
                error = str(e)
            except OSError as e:
                error = f"{zone}: {e.strerror or e}"
            with self._cond:
                self._last = time.monotonic()
                self._active = False
                drained = not self._pending
                self._cond.notify_all()
            self.done.emit(zone, error)
            if drained:
                self.idle.emit()


def _ro(type_, attr, signal):
    return Property(type_, lambda self: getattr(self, attr), notify=signal)


class Backend(QObject):
    """Everything the QML side reads and calls, exposed as the context property "backend"."""

    deviceChanged = Signal()
    zonesChanged = Signal()
    stylesChanged = Signal()
    checksChanged = Signal()
    busyChanged = Signal()
    identifyingChanged = Signal()
    message = Signal(str, bool)  # text, is an error
    _checksReady = Signal(object)

    def __init__(self, demo=False, send=True):
        super().__init__()
        self._send = send  # False for --screenshot: nothing reaches the hardware
        self._demo_requested = demo
        self._checks = []
        self._busy = False
        self._identifying = ""
        self._identify_queue = []
        self._dirty = False
        self._resync = False
        self._save_error_shown = False
        self._last_write = 0.0
        self._last_on_demo = None
        self._styles = {}
        self._style_list = []
        self._previews = {}
        self._tags = []
        self._zone_list = []
        self._synced = False
        self._lights_on = True
        self._current_style = ""
        self._modes = [dict(core.MODES[m], id=m, name=MODE_TEXT[m][0], hint=MODE_TEXT[m][1],
                            dimm=m in core.DIMM_MODES) for m in core.MODES]

        self._load_styles(emit=False)
        self._open_device()
        self._writer = Writer(self._device)
        self._writer.done.connect(self._on_written)
        self._writer.idle.connect(self._on_idle)

        self._save_timer = QTimer(self)
        self._save_timer.setSingleShot(True)
        self._save_timer.setInterval(SAVE_DELAY_MS)
        self._save_timer.timeout.connect(self._save)
        self._identify_timer = QTimer(self)
        self._identify_timer.setSingleShot(True)
        self._identify_timer.setInterval(IDENTIFY_MS)
        self._identify_timer.timeout.connect(self._identify_step)
        self._poll_timer = QTimer(self)
        self._poll_timer.setInterval(POLL_MS)
        self._poll_timer.timeout.connect(self._poll)
        self._poll_timer.start()

        self._checksReady.connect(self._set_checks)
        self._emit_zones()
        self._run_checks()

    # --- device -------------------------------------------------------------

    def _open_device(self):
        self._aliases = core.zone_aliases()
        self._model = core.product_name()
        path = None if self._demo_requested else core.device_dir()
        if path:
            self._device = SysfsDevice(path)
            self._state = "live" if self._device.writable() else "readonly"
            self._smbios = self._device.smbios_version()
        else:
            self._state = "demo" if self._demo_requested else "missing"
            if self._demo_requested or not self._aliases:
                self._model = "Predator PO7-660"
                self._aliases = dict(core.MODELS[0][1])
            self._device = DemoDevice(self._demo_states())
            real = core.device_dir()
            self._smbios = core.read(os.path.join(real, "smbios_version")) if real else ""
        self._zone_ids = self._device.zones()
        self._states = {z: core.normalize(s) for z, s in self._device.read_all().items()}
        self._last_color = next((s["color"] for s in self._states.values()
                                 if s["color"] != "random" and s["mode"] != "off"), "00aec7")
        if hasattr(self, "_writer"):
            self._writer.device = self._device

    def _demo_states(self):
        zone_ids = ["global", "area1", "area2", "area3", "area4"]
        states = {z: dict(core.DEFAULTS, color="00aec7") for z in zone_ids}
        entry = self._styles.get(DEMO_STYLE)
        if self._demo_requested and entry:
            for zone, state in core.plan_in(zone_ids, entry[1], self._aliases or dict(core.MODELS[0][1])):
                states[zone] = core.normalize(state)
                if zone == "global":
                    for a in zone_ids[1:]:
                        states[a] = core.normalize(state)
        return states

    def _areas(self):
        return [z for z in self._zone_ids if z not in ("global", "dimm")]

    def _label(self, zone):
        if zone == "global":
            return LABELS["global"]
        if zone == "dimm":
            return LABELS["memory"]
        names = core.names_for(zone, self._aliases)
        if names:
            return LABELS.get(names[0], names[0].capitalize())
        return "Area " + zone[4:] if zone.startswith("area") else zone

    def _can_send(self):
        return self._send and self._state in ("live", "demo")

    # --- properties ----------------------------------------------------------

    deviceState = _ro(str, "_state", deviceChanged)  # live, readonly, missing, demo
    model = _ro(str, "_model", deviceChanged)
    smbiosVersion = _ro(str, "_smbios", deviceChanged)
    zones = _ro("QVariantList", "_zone_list", zonesChanged)
    synced = _ro(bool, "_synced", zonesChanged)
    lightsOn = _ro(bool, "_lights_on", zonesChanged)
    currentStyle = _ro(str, "_current_style", zonesChanged)
    lastColor = _ro(str, "_last_color", zonesChanged)
    styles = _ro("QVariantList", "_style_list", stylesChanged)
    tags = _ro("QVariantList", "_tags", stylesChanged)
    checks = _ro("QVariantList", "_checks", checksChanged)
    busy = _ro(bool, "_busy", busyChanged)
    identifying = _ro(str, "_identifying", identifyingChanged)

    @Property(bool, notify=deviceChanged)
    def writable(self):
        return self._state in ("live", "demo")

    @Property(str, notify=deviceChanged)
    def driverVersion(self):
        return core.driver_version()

    @Property(str, constant=True)
    def appVersion(self):
        return VERSION

    @Property(str, notify=deviceChanged)
    def layout(self):
        return "po7-660" if "PO7-660" in self._model else "generic"

    @Property("QVariantList", constant=True)
    def modes(self):
        return self._modes

    @Property("QVariantList", constant=True)
    def swatches(self):
        return SWATCHES

    @Property("QVariantMap", constant=True)
    def identifyLook(self):
        return IDENTIFY

    @Property(str, constant=True)
    def projectUrl(self):
        return PROJECT_URL

    @Property(str, constant=True)
    def userStyleDir(self):
        return core.USER_STYLE_DIR

    @Property(str, constant=True)
    def userName(self):
        """Login name, the same default author orionctl uses."""
        try:
            return pwd.getpwuid(os.getuid()).pw_name
        except KeyError:
            return os.environ.get("USER", "")

    def _set_busy(self, busy):
        if busy != self._busy:
            self._busy = busy
            self.busyChanged.emit()

    # --- zone state ----------------------------------------------------------

    def _whole_case(self):
        """What the whole case shows: per setting the most common value, and which settings differ."""
        areas = [self._states[a] for a in self._areas()]
        if not areas:
            return dict(self._states["global"]), []
        view, mixed = {}, []
        for key in core.DEFAULTS:
            values = [s[key] for s in areas]
            counts = collections.Counter(values)
            view[key] = max(values, key=lambda v: (counts[v], -values.index(v)))
            if len(counts) > 1:
                mixed.append(key)
        return view, mixed

    def _emit_zones(self):
        zones = []
        for z in self._zone_ids:
            state, mixed = self._whole_case() if z == "global" else (self._states[z], [])
            names = core.names_for(z, self._aliases)
            zones.append(dict(state, id=z, label=self._label(z), alias=names[0] if names else "",
                              mixed=mixed,
                              modes=[m for m in core.MODES if z != "dimm" or m in core.DIMM_MODES]))
        areas = self._areas()
        glob = self._states.get("global")
        self._zone_list = zones
        self._synced = bool(areas) and glob is not None and all(self._states[a] == glob for a in areas)
        self._lights_on = self._lit(self._states)
        self._current_style = self._match_style()
        self.zonesChanged.emit()

    def _lit(self, states):
        # An area at brightness 0 is as dark as one that is off.
        return any(core.is_lit(states[a]) for a in self._areas())

    def _plan_result(self, plan):
        """The zone states a plan would leave behind, without sending anything."""
        states = {z: dict(s) for z, s in self._states.items()}
        for zone, state in plan:
            states[zone] = core.normalize(state)
            if zone == "global":
                for a in self._areas():
                    states[a] = dict(states[zone])
        return states

    def _match_style(self):
        areas = self._areas()
        for entry in self._style_list:
            preview = entry["preview"]
            if areas and all(self._looks_same(preview.get(a), self._states[a]) for a in areas):
                return entry["id"]
        return ""

    @staticmethod
    def _looks_same(a, b):
        # Off is dark whatever colour or brightness it keeps.
        return a == b or (a is not None and a["mode"] == b["mode"] == "off")

    def _apply_plan(self, plan):
        """Show a list of (zone, state) writes at once and queue them for the firmware."""
        for zone, state in plan:
            s = core.normalize(state)
            if zone != "global":
                s = core.concrete(zone, s)
            self._states[zone] = s
            if zone == "global":
                for a in self._areas():
                    self._states[a] = dict(s)
            if s["color"] != "random" and core.MODES[s["mode"]]["color"]:
                self._last_color = s["color"]
            self._submit(zone, s)
        self._emit_zones()

    def _submit(self, zone, state):
        if not self._can_send():
            return
        self._dirty = self._state == "live"
        self._save_timer.stop()
        self._set_busy(True)
        self._writer.submit(zone, state)

    def _clean_changes(self, changes):
        changes = {k: v for k, v in dict(changes).items() if v is not None}
        for key in ("brightness", "speed", "duration", "direction"):
            if isinstance(changes.get(key), float):
                changes[key] = int(round(changes[key]))
        return core.prepare_state(changes)

    @Slot(str, "QVariantMap")
    def setZone(self, zone, changes):
        """Change some settings of one zone. "global" edits every area at once."""
        try:
            changes = self._clean_changes(changes)
        except ValueError as e:
            self.message.emit(str(e), True)
            return
        if zone not in self._states:
            return
        if zone == "global":
            self._edit_whole_case(changes)
            return
        current = core.concrete(zone, self._states[zone])
        state = core.normalize(dict(current, **core.wake(current, changes)))
        errors = core.check_zone_state(zone, state)
        if errors:
            self.message.emit("; ".join(errors), True)
            return
        self._apply_plan([(zone, state)])

    def _edit_whole_case(self, changes):
        """Apply the changes to every area and send as few writes as that allows.

        When every area ends up the same, one global write does it and the firmware
        runs the effect across the whole case. Otherwise each area keeps its own
        settings apart from the changed ones.
        """
        if changes.get("color") == "random":
            # Random colours only exist on the global zone, so this is one look for the whole case.
            view = self._whole_case()[0]
            state = core.normalize(dict(view, **core.wake(view, changes)))
            errors = core.check_zone_state("global", state)
            if errors:
                self.message.emit("; ".join(errors), True)
                return
            self._apply_plan([("global", state)])
            return

        def fix(state):
            # Only some effects take random colours; the others need a real one back.
            if state["color"] == "random" and not core.MODES[state["mode"]]["random"]:
                state["color"] = self._last_color
            return state

        def edit(state):
            return fix(core.normalize(dict(state, **core.wake(state, changes))))

        glob = edit(self._states["global"])
        areas = {a: edit(self._states[a]) for a in self._areas()}
        errors = core.check_zone_state("global", glob)
        if errors:
            self.message.emit("; ".join(errors), True)
            return
        doc = core.snapshot_from_states(dict(areas, **{"global": glob}))
        self._apply_plan(core.plan_in(self._zone_ids, doc, {}))

    @Slot(str)
    def applyStyle(self, style_id):
        entry = self._styles.get(style_id)
        if entry and self._apply_doc(entry[1]):
            self.message.emit(f"Applied {entry[1]['name']}", False)

    def _apply_doc(self, doc):
        try:
            plan = core.plan_in(self._zone_ids, doc, self._aliases)
        except core.OrionError as e:
            self.message.emit(str(e), True)
            return False
        self._apply_plan(plan)
        return True

    @Slot()
    def turnOff(self):
        if self._lights_on:
            doc = core.snapshot_from_states(self._states)
            doc["name"] = "Before lights off"
            if self._state == "live":
                try:
                    core.write_json(core.LAST_ON_FILE, doc)
                except OSError as e:
                    self.message.emit(f"Could not remember the current look: {e.strerror}", True)
            else:
                self._last_on_demo = doc
        state = dict(self._whole_case()[0], mode="off")
        if state["color"] == "random":
            state["color"] = self._last_color
        self._apply_plan([("global", state)])

    @Slot()
    def turnOn(self):
        doc = None
        if self._state in ("live", "readonly"):
            try:
                doc = core.load_style_file(core.LAST_ON_FILE)
            except ValueError:
                doc = None
        else:
            doc = self._last_on_demo
        try:
            dark = doc is None or not self._lit(self._plan_result(core.plan_in(self._zone_ids, doc, self._aliases)))
        except core.OrionError:
            dark = True
        if dark:
            # Nothing to bring back that would light anything, so fall back to Acer's factory look.
            entry = self._styles.get("predator-classic")
            doc = entry[1] if entry else {"zones": {"global": dict(core.DEFAULTS)}}
        self._apply_doc(doc)

    @Slot(str)
    def identify(self, zone):
        """Flash a zone (or "all" areas one after another) white so it can be found on the case."""
        if not self._can_send():
            self.message.emit("This account can't change the lights yet. The Device page explains why.", True)
            return
        if self._identifying:
            return
        self._identify_queue = self._areas() if zone == "all" else [zone]
        self._identify_step()

    def _identify_step(self):
        if self._identifying:
            self._restore(self._identifying)
        if not self._identify_queue:
            self._identifying = ""
            self.identifyingChanged.emit()
            return
        self._identifying = self._identify_queue.pop(0)
        self.identifyingChanged.emit()
        self._set_busy(True)
        self._writer.submit(self._identifying, IDENTIFY)
        self._identify_timer.start()

    def _restore(self, zone):
        state = self._states[zone]
        if zone == "global" or state["color"] == "random":
            doc = core.snapshot_from_states(self._states)
            plan = core.plan_in(self._zone_ids, doc, {})
        else:
            plan = [(zone, state)]
        for z, s in plan:
            self._writer.submit(z, core.normalize(s))

    def _on_written(self, zone, error):
        self._last_write = time.monotonic()
        if error:
            self._resync = True
            self.message.emit(error, True)

    def _on_idle(self):
        self._set_busy(False)
        if self._resync:
            self._resync = False
            self._reload_states()
        if self._dirty:
            self._save_timer.start()

    def _save(self):
        if self._state != "live" or self._identifying or self._writer.busy():
            return
        try:
            self._device.save(core.STATE_FILE)
            self._dirty = False
        except OSError as e:
            if not self._save_error_shown:
                self._save_error_shown = True
                self.message.emit(f"Could not save the look for the next boot: {e.strerror}", True)

    def _reload_states(self):
        try:
            states = {z: core.normalize(s) for z, s in self._device.read_all().items()}
        except (OSError, ValueError):
            if self._state in ("live", "readonly") and not core.device_dir():
                self._open_device()
                self.deviceChanged.emit()
                self._emit_zones()
                self.message.emit("The lighting driver was unloaded. This is a preview until it is back.", True)
            return
        if states != self._states:
            self._states = states
            self._emit_zones()

    def _poll(self):
        """Pick up changes made with orionctl or by the boot service."""
        if self._state not in ("live", "readonly") or self._identifying or self._writer.busy():
            return
        if time.monotonic() - self._last_write < 1.5:
            return
        self._reload_states()

    def shutdown(self):
        self._identify_timer.stop()
        if self._identifying:
            self._identify_queue = []
            self._identify_step()
        self._writer.flush(3.0)
        if self._dirty:
            self._save()

    # --- styles ---------------------------------------------------------------

    def _load_styles(self, emit=True):
        styles = core.all_styles()
        user_dir = os.path.realpath(core.USER_STYLE_DIR) + os.sep
        areas_for_preview = ["area1", "area2", "area3", "area4", "area5"]
        aliases = core.zone_aliases() or dict(core.MODELS[0][1])
        entries, tag_count = [], collections.Counter()
        for sid, (path, doc) in styles.items():
            preview = core.preview_style(doc, areas_for_preview, aliases)
            keys = {k for k in doc["zones"] if k not in ("dimm", "memory")}
            entries.append({
                "id": sid, "name": doc["name"], "description": doc.get("description", ""),
                "author": doc.get("author", ""), "tags": doc.get("tags", []), "path": path,
                "user": os.path.realpath(path).startswith(user_dir),
                "preview": preview, "synced": keys == {"global"},
            })
            tag_count.update(t.lower() for t in doc.get("tags", []))
        entries.sort(key=lambda e: (not e["user"], e["name"].lower()))
        self._styles = styles
        self._style_list = entries
        self._tags = [{"name": t, "count": n} for t, n in sorted(tag_count.items(), key=lambda kv: (-kv[1], kv[0]))]
        if emit:
            self.stylesChanged.emit()
            self._emit_zones()

    def _style_doc(self, style_id):
        entry = self._styles.get(style_id)
        return entry[1] if entry else None

    @Slot(str, str, str, str, result=str)
    def saveStyle(self, name, description, tags, author):
        name = name.strip()
        if not name:
            self.message.emit("The style needs a name.", True)
            return ""
        tag_list = [t.strip().lower() for t in tags.split(",") if t.strip()]
        doc = core.style_from_states(self._states, name, author=author.strip(),
                                     description=description.strip(), tags=tag_list)
        errors = core.validate_style(doc)
        if errors:
            self.message.emit("; ".join(errors), True)
            return ""
        style_id = core.slug(name) or "style"
        try:
            core.write_json(os.path.join(core.USER_STYLE_DIR, style_id + ".json"), doc, mode=0o644)
        except OSError as e:
            self.message.emit(f"Could not save the style: {e.strerror}", True)
            return ""
        self._load_styles()
        self.message.emit(f"Saved {name} to your styles", False)
        return style_id

    @Slot(str, result=str)
    def importStyle(self, url):
        path = QUrl(url).toLocalFile() or url
        try:
            doc = core.load_style_file(path)
        except ValueError as e:
            self.message.emit(f"That file is not a style: {e}", True)
            return ""
        base = core.slug(os.path.splitext(os.path.basename(path))[0]) or core.slug(doc["name"]) or "style"
        style_id, n = base, 2
        while os.path.exists(os.path.join(core.USER_STYLE_DIR, style_id + ".json")):
            style_id, n = f"{base}-{n}", n + 1
        try:
            core.write_json(os.path.join(core.USER_STYLE_DIR, style_id + ".json"), doc, mode=0o644)
        except OSError as e:
            self.message.emit(f"Could not import the style: {e.strerror}", True)
            return ""
        self._load_styles()
        self.message.emit(f"Imported {doc['name']}", False)
        return style_id

    @Slot(str, str)
    def exportStyle(self, style_id, url):
        doc = self._style_doc(style_id)
        if not doc:
            return
        path = QUrl(url).toLocalFile() or url
        if not path.endswith(".json"):
            path += ".json"
        try:
            core.write_json(path, doc, mode=0o644)
        except OSError as e:
            self.message.emit(f"Could not export the style: {e.strerror}", True)
            return
        self.message.emit(f"Exported to {path}", False)

    @Slot(str)
    def copyStyle(self, style_id):
        doc = self._style_doc(style_id)
        if doc:
            QGuiApplication.clipboard().setText(json.dumps(doc, indent=2) + "\n")
            self.message.emit(f"Copied {doc['name']} as JSON", False)

    @Slot(str)
    def shareStyle(self, style_id):
        doc = self._style_doc(style_id)
        if not doc:
            return
        text = json.dumps(doc, indent=2)
        QGuiApplication.clipboard().setText(text + "\n")
        query = urllib.parse.urlencode({"template": "style.yml", "title": f"Style: {doc['name']}", "json": text})
        QDesktopServices.openUrl(QUrl(f"{PROJECT_URL}/issues/new?{query}"))
        self.message.emit("Opened the style form on GitHub. The JSON is on your clipboard as well.", False)

    @Slot(str)
    def deleteStyle(self, style_id):
        entry = self._styles.get(style_id)
        if not entry or not os.path.realpath(entry[0]).startswith(os.path.realpath(core.USER_STYLE_DIR) + os.sep):
            return
        path, doc = entry
        trashed = QFile.moveToTrash(path)
        if isinstance(trashed, tuple):
            trashed = trashed[0]
        if not trashed:
            try:
                os.remove(path)
            except OSError as e:
                self.message.emit(f"Could not delete {doc['name']}: {e.strerror}", True)
                return
        self._load_styles()
        self.message.emit(f"Moved {doc['name']} to the trash" if trashed else f"Deleted {doc['name']}", False)

    @Slot()
    def openStylesFolder(self):
        os.makedirs(core.USER_STYLE_DIR, exist_ok=True)
        QDesktopServices.openUrl(QUrl.fromLocalFile(core.USER_STYLE_DIR))

    @Slot(str)
    def showStyleFile(self, style_id):
        entry = self._styles.get(style_id)
        if entry:
            QDesktopServices.openUrl(QUrl.fromLocalFile(os.path.dirname(entry[0])))

    # --- device page -----------------------------------------------------------

    def _run_checks(self):
        def work():
            try:
                rows = [{"ok": ok, "text": text, "hint": hint} for ok, text, hint in doctor_checks()]
            except Exception as e:  # a broken check must not take the app down
                rows = [{"ok": False, "text": f"the checks failed: {e}", "hint": ""}]
            self._checksReady.emit(rows)
        threading.Thread(target=work, name="orion-doctor", daemon=True).start()

    def _set_checks(self, rows):
        self._checks = rows
        self.checksChanged.emit()

    @Slot()
    def refresh(self):
        """Look for the driver again and re-read everything."""
        if not self._writer.busy() and not self._identifying:
            self._open_device()
            self.deviceChanged.emit()
        self._load_styles()
        self._run_checks()

    @Slot(str)
    def openUrl(self, url):
        QDesktopServices.openUrl(QUrl(url))

    @Slot(str, result=str)
    def zoneId(self, name):
        """Driver zone for a zone name or alias, "" if unknown."""
        try:
            found = core.resolve_in(self._zone_ids, name, self._aliases)
        except core.OrionError:
            return ""
        return "global" if len(found) > 1 else found[0]


def main(argv=None):
    parser = argparse.ArgumentParser(prog="orion-unchained",
                                     description="Lighting control for Acer Predator Orion desktops.")
    parser.add_argument("--version", action="version", version=f"orion-unchained {VERSION}")
    parser.add_argument("--demo", action="store_true",
                        help="show a simulated PO7-660 and leave the hardware alone")
    parser.add_argument("--page", choices=PAGES, help="page to open")
    parser.add_argument("--zone", help="zone to select, such as front or area2")
    parser.add_argument("--screenshot", metavar="PNG",
                        help="save the window as PNG after --delay ms and quit; sends nothing to the hardware")
    parser.add_argument("--delay", type=int, default=1500, metavar="MS")
    parser.add_argument("--size", metavar="WxH", help="window size")
    parser.add_argument("--check", action="store_true",
                        help="load every page in demo mode, print any QML problem and exit non-zero if there was one")
    parser.add_argument("--run-js", help=argparse.SUPPRESS)  # for testing: evaluated on the window
    args = parser.parse_args(argv)

    QQuickStyle.setStyle("Basic")
    QGuiApplication.setOrganizationName("orion-unchained")
    QGuiApplication.setApplicationName("orion-unchained")
    QGuiApplication.setApplicationVersion(VERSION)
    QGuiApplication.setDesktopFileName("orion-unchained")
    app = QApplication(sys.argv[:1])  # widgets only for the desktop's native file dialogs
    app.setWindowIcon(QIcon(ICON))

    backend = Backend(demo=args.demo or args.check, send=not (args.screenshot or args.check))
    engine = QQmlApplicationEngine()
    problems = []
    engine.warnings.connect(lambda warnings: problems.extend(w.toString() for w in warnings))
    engine.rootContext().setContextProperty("backend", backend)
    engine.load(QUrl.fromLocalFile(QML_MAIN))
    if not engine.rootObjects():
        sys.exit("orion-unchained: the interface failed to load")
    window = engine.rootObjects()[0]
    if args.size:
        width, height = (int(v) for v in args.size.lower().split("x"))
        window.setWidth(width)
        window.setHeight(height)
    if args.page:
        window.setProperty("page", PAGES.index(args.page))
    if args.zone:
        window.setProperty("zoneId", backend.zoneId(args.zone) or "global")
    if args.run_js:
        QQmlExpression(QQmlEngine.contextForObject(window), window, args.run_js).evaluate()
    if args.check:
        for i in range(len(PAGES)):
            QTimer.singleShot(400 * i, lambda i=i: window.setProperty("page", i))

        def finish():
            for problem in problems:
                print(problem, file=sys.stderr)
            print(f"orion-unchained: {len(problems)} QML problem(s)" if problems else "orion-unchained: interface ok")
            app.exit(1 if problems else 0)
        QTimer.singleShot(400 * len(PAGES) + 400, finish)
    if args.screenshot:
        def shoot():
            if not window.grabWindow().save(args.screenshot):
                print(f"orion-unchained: could not write {args.screenshot}", file=sys.stderr)
            app.quit()
        QTimer.singleShot(args.delay, shoot)
    app.aboutToQuit.connect(backend.shutdown)
    sys.exit(app.exec())
