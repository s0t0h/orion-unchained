// SPDX-License-Identifier: GPL-2.0-or-later
// Preview of the firmware's lighting effects, one LED at a time.
//
// The shapes and timings come from a video of a PO7-660 running every effect for
// the whole case at speed 5 and duration 0, plus the owner's description of the
// slower effects. How speed and duration scale was not filmed: speed is assumed
// to scale time by 1.38 per step and duration to add a dark pause per cycle.
// Only the controller knows the real curves; these are fitted by eye.
.pragma library

var rgbCache = {}

function rgb(hex) {
    var c = rgbCache[hex]
    if (c === undefined) {
        var v = parseInt(hex, 16)
        if (isNaN(v))
            v = 0xffffff
        c = [((v >> 16) & 255) / 255, ((v >> 8) & 255) / 255, (v & 255) / 255]
        rgbCache[hex] = c
    }
    return c
}

function fract(x) { return x - Math.floor(x) }
function clamp(x) { return x < 0 ? 0 : (x > 1 ? 1 : x) }

function hash(n) {
    var s = Math.sin(n * 91.3458 + 47.853) * 43758.5453
    return s - Math.floor(s)
}

// Fully saturated colour for a hue in 0..1.
function hue(h) {
    h = fract(h) * 6
    var i = Math.floor(h), f = h - i
    switch (i) {
    case 0: return [1, f, 0]
    case 1: return [1 - f, 1, 0]
    case 2: return [0, 1, f]
    case 3: return [0, 1 - f, 1]
    case 4: return [f, 0, 1]
    default: return [1, 0, 1 - f]
    }
}

function rate(speed) { return 0.12 * Math.pow(1.38, speed) }
function pause(duration) { return duration * 0.12 }

// Effect seconds per real second: 1 at speed 5, the speed on the video.
function pace(speed) { return Math.pow(1.38, speed - 5) }
// Dark seconds added to each cycle by the duration setting.
function gap(duration) { return duration * 0.5 }

function smooth(x) {
    x = clamp(x)
    return x * x * (3 - 2 * x)
}

// 0..1 over a cycle p (seconds): rises until a, holds until b, falls until c.
function envelope(p, a, b, c) {
    if (p <= 0 || p >= c)
        return 0
    if (p < a)
        return smooth(p / a)
    if (p < b)
        return 1
    return 1 - smooth((p - b) / (c - b))
}

var STACK = 8
var STACK_STEPS = STACK * (STACK + 1) / 2

// The PO7-660's LED rings in CaseView's design units (1000 x 660), listed in the
// order a wave runs through the case on the hardware: CPU cooler, rear fan,
// radiator, then the front's emblem ring and its two fans. pos is the place along
// that path, chain the place in the ring's own area, y the height in the case.
var PO7_660_RINGS = (function () {
    var list = [
        { zone: "area1", x: 410, y: 312, r: 44, n: 24, th: 7 },
        { zone: "area4", x: 170, y: 282, r: 60, n: 26, th: 8 },
        { zone: "area3", x: 345, y: 92, r: 50, n: 20, th: 8 },
        { zone: "area3", x: 485, y: 92, r: 50, n: 20, th: 8 },
        { zone: "area3", x: 625, y: 92, r: 50, n: 20, th: 8 },
        { zone: "area2", x: 845, y: 146, r: 58, n: 24, th: 8 },
        { zone: "area2", x: 845, y: 322, r: 78, n: 32, th: 10 },
        { zone: "area2", x: 845, y: 502, r: 78, n: 32, th: 10 }
    ]
    var total = 0, perZone = {}, i, ring
    for (i = 0; i < list.length; i++) {
        total += list[i].n
        perZone[list[i].zone] = (perZone[list[i].zone] || 0) + list[i].n
    }
    var at = 0, atZone = {}
    for (i = 0; i < list.length; i++) {
        ring = list[i]
        var z = atZone[ring.zone] || 0
        ring.posStart = at / total
        ring.posSpan = ring.n / total
        ring.chainStart = z / perZone[ring.zone]
        ring.chainSpan = ring.n / perZone[ring.zone]
        ring.yTop = (ring.y - ring.r) / 660
        ring.ySpan = 2 * ring.r / 660
        at += ring.n
        atZone[ring.zone] = z + ring.n
    }
    return list
})()

// Colour of one LED as rgba, alpha carrying the light's intensity.
//   s      zone state: mode, color ("rrggbb" or "random"), brightness, speed, duration, direction
//   t      seconds; a negative t asks for a representative still frame
//   i, n   index of the LED in its ring and the ring's LED count
//   pos    0..1 along the case when a global effect runs in sync, otherwise along the area
//   chain  0..1 along the LEDs of the LED's own area (the front: emblem, fan 1, fan 2)
//   y      0 (top) .. 1 (bottom), in the case when in sync, otherwise in the ring
//   seed   a number that differs per ring
function led(s, t, i, n, pos, chain, y, seed) {
    if (!s || s.mode === "off" || !(s.brightness > 0))
        return Qt.rgba(0, 0, 0, 0)
    var still = t < 0
    var random = s.color === "random"
    var c = random ? [1, 1, 1] : rgb(s.color)
    var k = 1
    var u = still ? -1 : t * pace(s.speed)
    var r, p, cyc, d, T

    switch (s.mode) {
    case "static":
        break
    case "breathing":
        r = rate(s.speed)
        T = 1 + pause(s.duration)
        u = still ? 0.5 : t * r
        cyc = Math.floor(u / T)
        p = u - cyc * T
        k = p < 1 ? 0.5 - 0.5 * Math.cos(2 * Math.PI * p) : 0
        if (random)
            c = hue(hash(cyc + 0.5))
        break
    case "heartbeat":
        // Two one-second beats, then about three seconds dark.
        T = 5 + gap(s.duration)
        if (still)
            u = 0.5
        cyc = Math.floor(u / T)
        p = u - cyc * T
        k = Math.max(envelope(p, 0.3, 0.6, 1), envelope(p - 1.15, 0.3, 0.6, 1))
        if (random)
            c = hue(hash(cyc + 0.25))
        break
    case "twinkling":
        // The whole case blinks: about a second on, five off.
        T = 6.1 + gap(s.duration)
        if (still)
            u = 0.6
        cyc = Math.floor(u / T)
        p = u - cyc * T
        k = envelope(p, 0.1, 1.2, 1.35)
        if (random)
            c = hue(hash(cyc * 2.3 + 0.1))
        break
    case "rainbow":
        // The whole case shows one colour that slowly goes round the colour wheel.
        c = hue((still ? 15 : u) / 90)
        break
    case "wave":
        // One pulse runs through the case in 1.8 s, then it stays dark until the next.
        T = 6.2 + gap(s.duration)
        if (still)
            u = 1.2
        cyc = Math.floor(u / T)
        p = u - cyc * T
        k = envelope(p - pos * 1.8, 0.2, 0.7, 1.2)
        if (random)
            c = hue(hash(cyc + 0.61))
        break
    case "risen":
        // A rainbow that climbs slowly: every height has its own colour.
        c = hue(0.8 * (y + (still ? 0 : u) / 40))
        break
    case "stack": {
        // LEDs run along the area and pile up at its end, one after another.
        var x = s.direction ? chain : 1 - chain
        var cell = Math.min(STACK - 1, Math.floor(x * STACK))
        var q = still ? 20 : Math.floor(u * 5.4) % (STACK_STEPS + STACK)
        k = 0
        if (q >= STACK_STEPS) {
            k = 1
        } else {
            var stage = 0, start = 0
            while (start + STACK - stage <= q) {
                start += STACK - stage
                stage++
            }
            if (cell >= STACK - stage || cell === q - start)
                k = 1
        }
        c = hue((still ? 3 : u) / 11)
        break
    }
    case "extend":
        // Light spreads round each ring from the bottom, holds, and fades, while the
        // colour slowly goes round the colour wheel.
        T = 5.2 + gap(s.duration)
        if (still)
            u = 2.5
        cyc = Math.floor(u / T)
        p = u - cyc * T
        d = Math.abs(i / n - 0.5) * 2
        k = p < 3.8 ? smooth((p - d) / 0.3) : 1 - smooth((p - 3.8) / 0.6)
        c = hue(u / 60)
        break
    case "meteorite": {
        // One meteor at a time runs along each area, each in a new random colour.
        var TAIL = 0.3
        T = 3.3 + gap(s.duration)
        if (still)
            u = 0.8
        cyc = Math.floor(u / T)
        p = u - cyc * T
        d = p / 2 * (1 + TAIL) - chain
        k = 0
        if (d >= 0 && d < TAIL) {
            k = Math.pow(1 - d / TAIL, 2.2)
            var h = hue(hash(cyc * 3.1 + 0.7))
            var w = Math.pow(1 - d / TAIL, 10)
            c = [h[0] + (1 - h[0]) * w, h[1] + (1 - h[1]) * w, h[2] + (1 - h[2]) * w]
        }
        break
    }
    case "magic": {
        // Bands of light sweep along each area while the colours go round the wheel.
        if (still)
            u = 0.8
        d = 0.5 + 0.5 * Math.cos(2 * Math.PI * (u / 2.5 - chain * 0.8))
        k = Math.pow(d, 1.5)
        c = hue(u / 3.5 - chain * 0.6)
        break
    }
    case "snake": {
        // A snake runs round each area, through all of its rings in turn.
        var dir = s.direction ? 1 : -1
        var head = fract(dir * (still ? 0.55 : u / 3.2))
        d = dir > 0 ? fract(head - chain) : fract(chain - head)
        k = d < 0.3 ? Math.pow(1 - d / 0.3, 0.7) : 0
        if (random)
            c = hue(hash(Math.floor(u / 3.2) + 0.37))
        break
    }
    }
    return Qt.rgba(c[0], c[1], c[2], k * Math.pow(s.brightness / 100, 0.7))
}

// One colour that stands for the whole zone, for dots, halos and chips.
function swatch(s, t) {
    if (!s || s.mode === "off")
        return Qt.rgba(0, 0, 0, 0)
    return led(s, t === undefined ? -1 : t, 0, 1, 0.5, 0.5, 0.5, 1)
}

// Settings an effect uses.
function usesColor(mode) { return ["static", "breathing", "heartbeat", "twinkling", "wave", "snake"].indexOf(mode) >= 0 }
