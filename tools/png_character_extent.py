"""Measure the visible character extent of each bundled VAN expression.

For every PNG, find the tight bounding box of pixels whose alpha clears
a small threshold, and report it BOTH in pixels and as a fraction of the
canvas. Two assets that are framed differently will render at visibly
different character sizes under `BoxFit.contain` inside a square stage,
which is exactly the "five slightly different ducks" failure mode.

The focal-point metric additionally reports where the head sits, because
an eye-line that drifts between states reads as a character jump.
"""

import glob
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from png_alpha_probe import read_png_rgba  # noqa: E402

# Anything below this alpha is treated as background.
THRESHOLD = 24


def measure(path):
    w, h, _ct, _d, ch, px = read_png_rgba(path)
    min_x, min_y, max_x, max_y = w, h, -1, -1
    visible = 0
    for y in range(h):
        row = y * w
        for x in range(w):
            if px[(row + x) * ch + 3] >= THRESHOLD:
                visible += 1
                if x < min_x:
                    min_x = x
                if x > max_x:
                    max_x = x
                if y < min_y:
                    min_y = y
                if y > max_y:
                    max_y = y
    if max_x < 0:
        return None
    bw, bh = max_x - min_x + 1, max_y - min_y + 1
    return {
        "canvas": (w, h),
        "bbox": (min_x, min_y, bw, bh),
        "frac_w": bw / w,
        "frac_h": bh / h,
        "aspect": bw / bh,
        # Vertical position of the topmost visible row: the top of the head.
        "top_frac": min_y / h,
        "coverage": 100.0 * visible / (w * h),
    }


if __name__ == "__main__":
    print("%-18s %-11s %-22s %6s %6s %7s %7s" % (
        "asset", "canvas", "visible bbox (x,y,w,h)", "fracW", "fracH", "aspect", "top%"))
    print("-" * 88)
    for path in sorted(glob.glob("assets/van/expressions/*.png")):
        m = measure(path)
        name = os.path.basename(path)
        if m is None:
            print("%-18s NO VISIBLE PIXELS" % name)
            continue
        x, y, bw, bh = m["bbox"]
        print("%-18s %-11s %-22s %6.3f %6.3f %7.3f %6.1f%%" % (
            name,
            "%dx%d" % m["canvas"],
            "%d,%d,%d,%d" % (x, y, bw, bh),
            m["frac_w"], m["frac_h"], m["aspect"], 100 * m["top_frac"]))
