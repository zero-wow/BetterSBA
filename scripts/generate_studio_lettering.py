"""Render exact comic lettering for Studio controls. Run from the addon root.

The images contain lettering only; the faction button plates and their hover /
press animation remain separate. This also keeps arbitrary user data as live text.
"""

from pathlib import Path
import json
import re

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "IMG" / "Comic" / "Lettering"
FONT_ROOT = ROOT / "Fonts" / "Comic"

BUTTONS = [
    "Open Talents", "Tune Motion", "Switch Profile", "New Profile",
    "Bind To This Profile", "Unbind Character", "Copy From Profile",
    "Reset To Defaults", "Delete Profile", "Rename", "Change Build",
    "Choose a Build", "Reset & Rebuild", "Undo Respec",
    "Browse Builds and Imports", "Spend Available Points", "Previous",
    "Next", "Close", "Classic Settings", "Fit Window", "Preview Motion",
    "Talent Options", "← Talents", "Cancel", "Confirm", "Create", "Edit",
    "Clear", "Unavailable", "Approved", "Approve", "Not Set", "On", "Off",
    "X", "+", "−", "↑", "↓", "\\",
]

HEADINGS = [
    "BetterSBA", "Overview", "Combat", "Button & Queue", "Motion", "Talents",
    "Visibility", "Colors & Fonts", "Advanced", "Profiles", "Leveling Talents",
    "Your Adventure", "Confirm Action", "Build Library", "Current Route",
    "What Happens Next", "Automation & Safety", "Choose a Build",
    "Essentials", "Quick Behavior", "Macro Actions", "Class Abilities",
    "Trinkets & Input", "Equipped Trinkets", "Button", "Button Keybind",
    "Priority Queue", "Priority Placement", "Animated Clone", "Cast Feedback",
    "Classic Animation", "Palettes", "Build Automation", "Display Visibility",
    "Minimap & Data Broker", "Theme", "Comic Studio Lettering",
    "Spell Importance", "Global & Panel Fonts", "Button Keybind Font",
    "Priority Fonts", "Pause Text", "Clone Font", "Section Accents",
    "Performance", "Diagnostics", "Particle & Additional Options", "More Settings",
]
HEADINGS += [name + " Particles" for name in (
    "Drift", "Pulse", "Vortex", "Zoom", "Slam", "Pop!", "Burst",
    "Fade", "Flip", "Rise", "Scatter",
)]


def slug(text):
    aliases = {"←": "Left", "↑": "Up", "↓": "Down", "−": "Minus", "+": "Plus", "\\": "Grip"}
    text = "".join(aliases.get(char, char) for char in text)
    return re.sub(r"[^A-Za-z0-9]+", "", text) or "Label"


def power_of_two(value):
    return 1 << (value - 1).bit_length()


def draw_lettering(value, kind):
    scale = 4
    compact_state = kind == "button" and value in ("On", "Off")
    font_name = ("LilitaOne-Regular.ttf" if compact_state else "VTC-Letterer-Pro.ttf") \
        if kind == "button" else "Bangers-Regular.ttf"
    full_size = 18 if kind == "button" else 23
    font = ImageFont.truetype(FONT_ROOT / font_name, full_size * scale)
    small_font = ImageFont.truetype(FONT_ROOT / font_name,
                                    (15 if kind == "button" else 19) * scale)
    symbol_font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 18 * scale)
    # Make the image exactly fit its painted pixels; WoW positions the cropped
    # image by its natural aspect ratio instead of stretching a padded atlas.
    stroke = 1 * scale
    spacing = (0.2 if compact_state else 0.55 if kind == "button" else 0.8) * scale
    # These comic faces draw lowercase with capital shapes. Small capitals
    # preserve the user's Title Case while keeping their hand-lettered feel.
    glyphs = [ch if compact_state else ch.upper() if ch.islower() else ch for ch in value]
    fonts = [(font if compact_state else small_font if ch.islower() else font)
             if font.getmask(glyph).getbbox()
             else symbol_font for ch, glyph in zip(value, glyphs)]
    widths = [ImageDraw.Draw(Image.new("RGBA", (1, 1))).textlength(glyph, font=face)
              for glyph, face in zip(glyphs, fonts)]
    width = int(sum(widths) + max(0, len(value) - 1) * spacing + 32 * scale)
    height = 40 * scale
    image = Image.new("RGBA", (max(width, 32 * scale), height))
    draw = ImageDraw.Draw(image)
    total = sum(widths) + max(0, len(value) - 1) * spacing
    x = (image.width - total) / 2
    bbox = draw.textbbox((0, 0), value, font=font, stroke_width=stroke)
    y = (height - (bbox[3] - bbox[1])) / 2 - bbox[1] - 1 * scale
    for ch, glyph, char_width, face in zip(value, glyphs, widths, fonts):
        glyph_y = y + ((full_size - 15 if kind == "button" else full_size - 19) * scale
                       if ch.islower() and not compact_state else 0)
        # One inked glyph with a compact outline stays crisp at the small
        # in-game sizes; an offset shadow reads as a second text layer there.
        draw.text((x, glyph_y), glyph, font=face, fill=(247, 246, 235, 255),
                  stroke_width=stroke, stroke_fill=(11, 18, 32, 255))
        x += char_width + spacing
    box = image.getbbox()
    image = image.crop((max(0, box[0] - 2 * scale), max(0, box[1] - 2 * scale),
                        min(image.width, box[2] + 2 * scale),
                        min(image.height, box[3] + 2 * scale)))
    return image.resize((max(1, image.width // 2), max(1, image.height // 2)),
                        Image.Resampling.LANCZOS)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {}
    previews = []
    for kind, values in (("button", BUTTONS), ("heading", HEADINGS)):
        for value in dict.fromkeys(values):
            name = ("Button" if kind == "button" else "Heading") + slug(value)
            image = draw_lettering(value, kind)
            texture_width, texture_height = power_of_two(image.width), power_of_two(image.height)
            padded = Image.new("RGBA", (texture_width, texture_height))
            padded.paste(image, (0, 0))
            # WoW accepts uncompressed TGA reliably; retain 2x resolution.
            padded.save(OUT / (name + ".tga"))
            manifest[kind + ":" + value] = {
                "file": name,
                "width": round(image.width / 2, 2),
                "height": round(image.height / 2, 2),
                "u": round(image.width / texture_width, 6),
                "v": round(image.height / texture_height, 6),
            }
            if value in ("Open Talents", "Switch Profile", "Spend Available Points",
                         "On", "Off", "Your Adventure", "Essentials",
                         "Class Abilities", "Automation & Safety"):
                previews.append((kind, value, image))

    lua_lines = [
        "-- Generated by scripts/generate_studio_lettering.py; do not edit by hand.",
        "local ADDON_NAME, NS = ...",
        "NS.StudioLettering = { button = {}, heading = {} }",
    ]
    for key, item in sorted(manifest.items()):
        kind, value = key.split(":", 1)
        quoted = json.dumps(value, ensure_ascii=False)
        lua_lines.append(
            f'NS.StudioLettering.{kind}[{quoted}] = '
            f'{{ file = "{item["file"]}", width = {item["width"]}, '
            f'height = {item["height"]}, u = {item["u"]}, v = {item["v"]} }}'
        )
    (ROOT / "GUI" / "StudioComicLettering.lua").write_text(
        "\n".join(lua_lines) + "\n", encoding="utf-8")

    for faction in ("Alliance", "Horde"):
        sample = Image.new("RGB", (700, len(previews) * 60 + 28),
                           (6, 15, 29) if faction == "Alliance" else (6, 18, 15))
        button_base = Image.open(ROOT / "IMG" / "Comic" /
                                 (faction + "ButtonRounded.png")).convert("RGBA")
        heading_base = Image.open(ROOT / "IMG" / "Comic" /
                                  (faction + "Caption.png")).convert("RGBA")
        for index, (kind, value, image) in enumerate(previews):
            row_y = 14 + index * 60
            if value in ("On", "Off"):
                enabled = value == "On"
                fill = (20, 42, 77) if faction == "Alliance" else (20, 41, 28)
                edge = (118, 196, 218) if enabled else (85, 103, 129)
                toggle = Image.new("RGBA", (50, 21), fill + (255,))
                draw = ImageDraw.Draw(toggle)
                draw.rectangle((0, 0, 49, 20), outline=edge + (255,))
                draw.rectangle((39 if enabled else 4, 2, 46 if enabled else 11, 3),
                               fill=edge + (255,))
                art = image.resize((round(image.width * 15 / image.height), 15),
                                   Image.Resampling.LANCZOS)
                toggle.alpha_composite(art, ((50 - art.width) // 2, 3))
                enlarged = toggle.resize((100, 42), Image.Resampling.NEAREST)
                sample.paste(enlarged, (130, row_y), enlarged)
                caption = f"switch: {value} (2x preview)"
            elif kind == "heading" and value in ("Essentials", "Class Abilities"):
                plate = heading_base.resize((230, 22), Image.Resampling.LANCZOS)
                art = image.resize((round(image.width * 16 / image.height), 16),
                                   Image.Resampling.LANCZOS)
                plate.alpha_composite(art, (30, 3))
                enlarged = plate.resize((460, 44), Image.Resampling.NEAREST)
                sample.paste(enlarged, (15, row_y), enlarged)
                caption = f"heading: {value} (2x actual layout)"
            else:
                base = button_base if kind == "button" else heading_base
                plate = base.resize((330, 43), Image.Resampling.LANCZOS)
                sample.paste(plate, (15, row_y), plate)
                target_h = 20 if kind == "button" else 27
                target_w = min(int(image.width * target_h / image.height), 310)
                art = image.resize((target_w, target_h), Image.Resampling.LANCZOS)
                sample.paste(art, (180 - target_w // 2, row_y + (43 - target_h) // 2), art)
                caption = f"{kind}: {value}"
            caption_x = 500 if kind == "heading" and value in ("Essentials", "Class Abilities") else 370
            ImageDraw.Draw(sample).text((caption_x, row_y + 12), caption,
                                        fill=(220, 230, 240))
        sample.save(ROOT / "IMG" / "Comic" / ("LetteringPreview" + faction + ".png"))
    print(f"Generated {len(manifest)} lettering textures and manifest")


if __name__ == "__main__":
    main()
