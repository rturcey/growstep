"""Capture the fixture app after real UI navigation under xvfb-run.

Build first with ``flutter build linux --debug -t lib/visual_fixture.dart
--dart-define=GROWSTEP_VISUAL_STATE=initial`` (or ``sature``), then run this
script inside a 390x844 or 375x667 Xvfb screen. Requires ImageMagick import,
Pillow and libXtst.
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
OUTPUT = ROOT / "docs/visual-review"


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


def click(x: int, y: int) -> None:
    x11 = ctypes.CDLL(ctypes.util.find_library("X11"))
    xtst = ctypes.CDLL(ctypes.util.find_library("Xtst"))
    x11.XOpenDisplay.restype = ctypes.c_void_p
    display = x11.XOpenDisplay(None)
    if not display:
        raise RuntimeError("Cannot open X display")
    xtst.XTestFakeMotionEvent.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_ulong]
    xtst.XTestFakeButtonEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
    xtst.XTestFakeMotionEvent(display, -1, x, y, 0)
    xtst.XTestFakeButtonEvent(display, 1, 1, 0)
    xtst.XTestFakeButtonEvent(display, 1, 0, 0)
    x11.XFlush.argtypes = [ctypes.c_void_p]
    x11.XFlush(display)
    x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
    x11.XCloseDisplay(display)


def resize(window: int, width: int, height: int) -> None:
    x11 = ctypes.CDLL(ctypes.util.find_library("X11"))
    x11.XOpenDisplay.restype = ctypes.c_void_p
    display = x11.XOpenDisplay(None)
    x11.XResizeWindow.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_uint, ctypes.c_uint]
    x11.XResizeWindow(display, window, width, height)
    x11.XFlush.argtypes = [ctypes.c_void_p]
    x11.XFlush(display)
    x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
    x11.XCloseDisplay(display)


def capture(name: str) -> None:
    path = OUTPUT / f"{name}.png"
    subprocess.run(["import", "-window", "root", str(path)], check=True)
    with Image.open(path) as image:
        image.convert("L").convert("RGB").save(OUTPUT / f"{name}_gris.png")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("state", choices=["initial", "sature"])
    parser.add_argument("width", type=int)
    parser.add_argument("height", type=int)
    args = parser.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    env = {**os.environ, "LIBGL_ALWAYS_SOFTWARE": "1", "GDK_BACKEND": "x11"}
    app = subprocess.Popen([str(APP)], cwd=ROOT, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        window = wait_for_window()
        resize(window, args.width, args.height)
        time.sleep(2.5)
        for zone, x in [("potager", args.width // 2), ("jardinFleuri", args.width // 6), ("verger", args.width * 5 // 6)]:
            if zone != "potager":
                click(x, args.height - 36)
                time.sleep(1.5)
            capture(f"application_{zone}_{args.state}_{args.width}x{args.height}")
    finally:
        app.terminate()
        try:
            app.wait(timeout=3)
        except subprocess.TimeoutExpired:
            app.kill()


if __name__ == "__main__":
    main()
