#!/usr/bin/env python3
"""Draws the app's icons, as SVG: the app icon's layers (rendered to PNG by
render.swift, for Icon Composer's AppIcon.icon) and the two menu bar icons.

    make icons

The dog is a small white spitz, drawn here from circles and curves: being
good (the app icon, and the menu bar while all is quiet) and barking (the menu
bar while background sounds play).
"""
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICON = os.path.join(ROOT, "EmbarrassMeNot", "AppIcon.icon", "Assets")
ASSETS = os.path.join(ROOT, "EmbarrassMeNot", "Assets.xcassets")
INK = "#1F1B24"

FUR = ('<linearGradient id="fur" x1="0" y1="0" x2="0" y2="1">'
       '<stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#E4EAF5"/></linearGradient>')
SKY = ('<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">'
       '<stop offset="0" stop-color="#8CC0FF"/><stop offset="1" stop-color="#3D6EDC"/></linearGradient>')


def svg(body, defs="", box=(0, 0, 1024, 1024), height=1024):
    """box is the part of the 1024 drawing shown, at this height."""
    x, y, w, h = box
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w * height / h:g}" height="{height}" '
            f'viewBox="{x} {y} {w} {h}"><defs>{defs}</defs>{body}</svg>\n')


def fluff(cx, cy, rx, ry, n, amp):
    """A cloud of fur round an ellipse: each stretch of the edge bulges out,
    more at the cheeks and chin (a spitz's ruff) than on top."""
    pts = [(a, cx + rx * math.cos(a), cy + ry * math.sin(a))
           for a in (-math.pi / 2 + 2 * math.pi * i / n for i in range(n + 1))]
    d = f"M {pts[0][1]:.1f} {pts[0][2]:.1f}"
    for (a0, _, _), (a1, x1, y1) in zip(pts, pts[1:]):
        m = (a0 + a1) / 2
        k = amp * (0.35 + 0.65 * (1 + math.sin(m)) / 2)
        d += f" Q {cx + (rx + k) * math.cos(m):.1f} {cy + (ry + k) * math.sin(m):.1f} {x1:.1f} {y1:.1f}"
    return d + " Z"


LEFT, RIGHT = (lambda x: x), (lambda x: 1024 - x)


def ear(f):
    return f"M {f(300)} 452 Q {f(306)} 330 {f(348)} 278 Q {f(366)} 258 {f(392)} 274 Q {f(452)} 312 {f(486)} 372 Z"


def inner_ear(f):
    return f"M {f(334)} 420 Q {f(338)} 346 {f(364)} 312 Q {f(374)} 302 {f(388)} 312 Q {f(424)} 336 {f(446)} 376 Z"


def small_ear(f):
    # Shorter and softer, folded a little at the tip: at 18 points the app
    # icon's tall ears make the dog look like a cat.
    return f"M {f(286)} 470 Q {f(276)} 360 {f(318)} 318 Q {f(344)} 294 {f(380)} 312 Q {f(440)} 344 {f(470)} 400 Z"


def head(fill, bumps=24, amp=34, ear=ear):
    ears = "".join(f'<path d="{ear(f)}" fill="{fill}"/>' for f in (LEFT, RIGHT))
    return ears + f'<path d="{fluff(512, 548, 238, 214, bumps, amp)}" fill="{fill}"/>'


NOSE = "M494 566 Q 512 558 530 566 Q 534 574 524 582 Q 512 590 500 582 Q 490 574 494 566 Z"
MOUTH = "M466 610 Q 512 596 558 610 Q 556 672 512 680 Q 468 672 466 610 Z"


def flower(cx, cy, r):
    petals = "".join(f'<circle cx="{cx}" cy="{cy - r}" r="{r * 0.95:.1f}" '
                     f'transform="rotate({72 * k} {cx} {cy})" fill="#7FB2FF"/>' for k in range(5))
    return petals + f'<circle cx="{cx}" cy="{cy}" r="{r * 0.5:.1f}" fill="#FFD43B"/>'


def app_icon():
    """The good dog, in three layers for Icon Composer."""
    inner = "".join(f'<path d="{inner_ear(f)}" fill="#FFC2CF"/>' for f in (LEFT, RIGHT))
    face = f'''<ellipse cx="436" cy="544" rx="19" ry="23" fill="{INK}"/>
<ellipse cx="588" cy="544" rx="19" ry="23" fill="{INK}"/>
<ellipse cx="380" cy="604" rx="40" ry="22" fill="#FF8FA6" opacity="0.6"/>
<ellipse cx="644" cy="604" rx="40" ry="22" fill="#FF8FA6" opacity="0.6"/>
<path d="{NOSE}" fill="{INK}" transform="translate(0 22)"/>
<path d="M486 628 Q 499 640 512 626 Q 525 640 538 628" stroke="{INK}" stroke-width="8" fill="none" stroke-linecap="round" stroke-linejoin="round"/>'''
    layers = {"dog": head("url(#fur)") + inner, "face": face, "flower": flower(676, 404, 26)}
    os.makedirs(ICON, exist_ok=True)
    for name, body in layers.items():
        with open(os.path.join(ICON, f"{name}.svg"), "w") as f:
            f.write(svg(body, FUR))
    # The whole icon, for the README.
    with open(os.path.join(ROOT, "Art", "icon.svg"), "w") as f:
        f.write(svg('<clipPath id="sq"><rect width="1024" height="1024" rx="230"/></clipPath>'
                    f'<g clip-path="url(#sq)"><rect width="1024" height="1024" fill="url(#sky)"/>'
                    + "".join(layers.values()) + "</g>", FUR + SKY))


def waves(cx, cy, r0, n, gap, width):
    out = ""
    for side in (-1, 1):
        for i in range(n):
            r = r0 + i * gap
            a0, a1 = math.radians(-38), math.radians(38)
            if side < 0:
                a0, a1 = math.pi - a1, math.pi - a0
            out += (f'<path d="M {cx + r * math.cos(a0):.1f} {cy + r * math.sin(a0):.1f} '
                    f'A {r} {r} 0 0 1 {cx + r * math.cos(a1):.1f} {cy + r * math.sin(a1):.1f}" '
                    f'stroke="black" stroke-width="{width}" fill="none" stroke-linecap="round"/>')
    return out


def menu_bar():
    """Template images: black where the menu bar draws, see-through where it
    doesn't, so macOS colours them for light and dark menu bars. The face is
    cut out of the head; fewer, bigger tufts read at 18 points."""
    eyes_good = ('<ellipse cx="436" cy="546" rx="30" ry="36" fill="black"/>'
                 '<ellipse cx="588" cy="546" rx="30" ry="36" fill="black"/>')
    eyes_happy = ('<path d="M392 548 Q 430 500 468 548" stroke="black" stroke-width="34" fill="none" stroke-linecap="round"/>'
                  '<path d="M556 548 Q 594 500 632 548" stroke="black" stroke-width="34" fill="none" stroke-linecap="round"/>')
    nose = f'<path d="{NOSE}" fill="black" transform="translate(-54 -40) scale(1.1)"/>'
    mouth = f'<path d="{MOUTH}" fill="black" transform="translate(-77 -20) scale(1.15)"/>'

    def dog(features, transform=""):
        return (f'<mask id="m"><rect width="1024" height="1024" fill="white"/>{features}</mask>'
                f'<g transform="{transform}"><g mask="url(#m)">{head("black", 14, 52, small_ear)}</g></g>')

    # The same dog at the same size in both; the barking one is wider, for
    # its sound.
    icons = {
        "MenuGood": (dog(eyes_good + nose.replace("translate(-54 -40)", "translate(-51 -10)")),
                     (212, 236, 600, 600)),
        "MenuBarking": (dog(eyes_happy + nose + mouth) + waves(512, 560, 300, 2, 80, 44),
                        (88, 236, 848, 600)),
    }
    for name, (body, box) in icons.items():
        folder = os.path.join(ASSETS, f"{name}.imageset")
        os.makedirs(folder, exist_ok=True)
        with open(os.path.join(folder, f"{name}.svg"), "w") as f:
            f.write(svg(body, box=box, height=18))
        with open(os.path.join(folder, "Contents.json"), "w") as f:
            f.write('{\n  "images" : [ { "filename" : "%s.svg", "idiom" : "universal" } ],\n'
                    '  "info" : { "author" : "xcode", "version" : 1 },\n'
                    '  "properties" : { "preserves-vector-representation" : true, '
                    '"template-rendering-intent" : "template" }\n}\n' % name)
    with open(os.path.join(ASSETS, "Contents.json"), "w") as f:
        f.write('{\n  "info" : { "author" : "xcode", "version" : 1 }\n}\n')


if __name__ == "__main__":
    app_icon()
    menu_bar()
