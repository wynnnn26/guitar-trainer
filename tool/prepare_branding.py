#!/usr/bin/env python3
"""Copies the FretFlow logo into every place the app needs an icon.

Usage:  python3 tool/prepare_branding.py
Input:  guitar_icon_transparent.png (367x367 RGBA, green headstock on a dark
        rounded square) — passed on the command line or the default Downloads
        path.
Output: assets/images/fretflow_logo.png          (in-app branding)
        android/.../mipmap-*/ic_launcher.png     (launcher, per density)
        android/.../drawable-xxhdpi/launch_logo.png (splash, ~122 dp)
        web/favicon.png, web/icons/Icon-{192,512}.png (+ maskable)
"""
import os
import sys

from PIL import Image

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
DEFAULT_SRC = r"C:\Users\Jessica Fernandez\Downloads\guitar_icon_transparent.png"

# Launcher densities (Android px per density bucket).
MIPMAPS = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}


def save_resized(img, path, size):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.resize((size, size), Image.LANCZOS).save(path)
    print("wrote", os.path.relpath(path, REPO), f"{size}x{size}")


def save_full(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("wrote", os.path.relpath(path, REPO))


def opaque_background(img):
    """Most common opaque colour — used to fill maskable icon backgrounds."""
    counts = {}
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a >= 250:
                counts[(r, g, b)] = counts.get((r, g, b), 0) + 1
    (r, g, b), _ = max(counts.items(), key=lambda kv: kv[1])
    return (r, g, b, 255)


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SRC
    img = Image.open(src).convert("RGBA")
    if img.width != img.height:
        raise SystemExit(f"logo must be square, got {img.width}x{img.height}")

    # In-app branding (original size, scaled by Flutter as needed).
    save_full(img, os.path.join(REPO, "assets", "images", "fretflow_logo.png"))

    # Android launcher icons.
    for density, size in MIPMAPS.items():
        save_resized(
            img,
            os.path.join(REPO, "android", "app", "src", "main", "res",
                         f"mipmap-{density}", "ic_launcher.png"),
            size,
        )

    # Splash logo: living in drawable-xxhdpi (3x) makes 367 px render as
    # ~122 dp on every device, whatever its density.
    save_full(img, os.path.join(REPO, "android", "app", "src", "main", "res",
                                "drawable-xxhdpi", "launch_logo.png"))

    # Web: favicon + PWA icons. Maskable icons are filled edge to edge so the
    # launcher's circular crop never reveals transparency.
    save_resized(img, os.path.join(REPO, "web", "favicon.png"), 64)
    for size in (192, 512):
        save_resized(img, os.path.join(REPO, "web", "icons", f"Icon-{size}.png"), size)
        maskable = Image.new("RGBA", (size, size), opaque_background(img))
        scaled = img.resize((size, size), Image.LANCZOS)
        maskable.alpha_composite(scaled)
        save_resized(maskable, os.path.join(REPO, "web", "icons",
                                            f"Icon-maskable-{size}.png"), size)


if __name__ == "__main__":
    main()
