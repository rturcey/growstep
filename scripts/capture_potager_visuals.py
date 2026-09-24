"""Capture the static potager fixture in the complete Linux app.

Build first with ``flutter build linux --debug -t lib/potager_visual_fixture.dart
--dart-define=GROWSTEP_POTAGER_STATE=<initial|intermediaire|sature>``.
Run under xvfb-run with the requested screen size. Requires Pillow,
ImageMagick's ``import`` and X11.
"""

from __future__ import annotations

import argparse
import ctypes
import ctypes.util
import os
from pathlib import Path
import re
import subprocess
import time

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "build/linux/x64/debug/bundle/growstep"
OUTPUT = ROOT / "docs/visual-review/issue-41"


def wait_for_window() -> int:
    for _ in range(60):
        info = subprocess.run(
            ["xwininfo", "-root", "-tree"], capture_output=True, text=True, check=True
        ).stdout
        match = re.search(r'(0x[0-9a-f]+) "growstep"', info)
        if match:
            return int(match.group(1), 16)
        time.sleep(0.2)
    raise RuntimeError("The Growstep window did not appear")


def resize(window: int, width: int, height: int) -> None:
    x11 = ctypes.CDLL(ctypes.util.find_library("X11"))
    x11.XOpenDisplay.restype = ctypes.c_void_p
    display = x11.XOpenDisplay(None)
    if not display:
        raise RuntimeError("Cannot open X display")
    x11.XResizeWindow.argtypes = [
        ctypes.c_void_p,
        ctypes.c_ulong,
        ctypes.c_uint,
        ctypes.c_uint,
    ]
    x11.XResizeWindow(display, window, width, height)
    x11.XFlush.argtypes = [ctypes.c_void_p]
    x11.XFlush(display)
    x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
    x11.XCloseDisplay(display)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("state", choices=["initial", "intermediaire", "sature"])
    parser.add_argument("width", type=int)
    parser.add_argument("height", type=int)
    args = parser.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    env = {**os.environ, "LIBGL_ALWAYS_SOFTWARE": "1", "GDK_BACKEND": "x11"}
    app = subprocess.Popen(
        [str(APP)], cwd=ROOT, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )
    try:
        window = wait_for_window()
        resize(window, args.width, args.height)
        time.sleep(10.0)  # Wait for the static scene and plant sprites to load.
        path = OUTPUT / f"application_potager_{args.state}_{args.width}x{args.height}.png"
        subprocess.run(["import", "-window", "root", str(path)], check=True)
        with Image.open(path) as image:
            image.convert("L").convert("RGB").save(path.with_name(f"{path.stem}_gris.png"))
    finally:
        app.terminate()
        try:
            app.wait(timeout=3)
        except subprocess.TimeoutExpired:
            app.kill()


if __name__ == "__main__":
    main()
