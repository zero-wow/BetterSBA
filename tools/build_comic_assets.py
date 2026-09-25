"""Prepare the approved generated comic artwork for WoW textures.

The full-resolution, transparent source PNGs live in IMG/Comic/Source.  This
script performs only deterministic cropping, alpha feathering, and format
conversion; UI copy remains live Lua text.
"""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "IMG" / "Comic" / "Source"
OUTPUT = ROOT / "IMG" / "Comic"
RESAMPLE = Image.Resampling.LANCZOS


def source(name: str) -> Image.Image:
    return Image.open(SOURCE / f"{name}.png").convert("RGBA")


def alpha_crop(image: Image.Image, threshold: int = 12, pad: int = 4) -> Image.Image:
    mask = image.getchannel("A").point(lambda value: 255 if value > threshold else 0)
    bounds = mask.getbbox()
    if bounds is None:
        raise ValueError("Source art has no visible pixels")
    left, top, right, bottom = bounds
    return image.crop(
        (max(0, left - pad), max(0, top - pad),
         min(image.width, right + pad), min(image.height, bottom + pad))
    )


def feather(image: Image.Image, left: int, top: int, right: int, bottom: int) -> Image.Image:
    image = image.copy()
    alpha = image.getchannel("A")
    pixels = alpha.load()
    for y in range(image.height):
        for x in range(image.width):
            fade = 1.0
            if left:
                fade = min(fade, x / left)
            if top:
                fade = min(fade, y / top)
            if right:
                fade = min(fade, (image.width - 1 - x) / right)
            if bottom:
                fade = min(fade, (image.height - 1 - y) / bottom)
            pixels[x, y] = round(pixels[x, y] * max(0.0, min(1.0, fade)))
    image.putalpha(alpha)
    return image


def save(name: str, image: Image.Image, size: tuple[int, int]) -> None:
    image = image.resize(size, RESAMPLE)
    image.save(OUTPUT / f"{name}.png", optimize=True)
    image.save(OUTPUT / f"{name}.tga")


def save_right(name: str, image: Image.Image, size: tuple[int, int]) -> None:
    scale = min(size[0] / image.width, size[1] / image.height)
    width, height = round(image.width * scale), round(image.height * scale)
    canvas = Image.new("RGBA", size)
    canvas.alpha_composite(image.resize((width, height), RESAMPLE),
                           (size[0] - width, (size[1] - height) // 2))
    canvas.save(OUTPUT / f"{name}.png", optimize=True)
    canvas.save(OUTPUT / f"{name}.tga")


def save_center(name: str, image: Image.Image, size: tuple[int, int]) -> None:
    scale = min(size[0] / image.width, size[1] / image.height)
    width, height = round(image.width * scale), round(image.height * scale)
    canvas = Image.new("RGBA", size)
    canvas.alpha_composite(image.resize((width, height), RESAMPLE),
                           ((size[0] - width) // 2, (size[1] - height) // 2))
    canvas.save(OUTPUT / f"{name}.png", optimize=True)
    canvas.save(OUTPUT / f"{name}.tga")


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for faction in ("Alliance", "Horde"):
        save(f"{faction}Paper", source(f"{faction}Paper"), (512, 512))
        save(f"{faction}CardFrame", alpha_crop(source(f"{faction}CardFrame")), (512, 256))
        save(f"{faction}Header", source(f"{faction}Header"), (512, 128))
        save(f"{faction}Button", alpha_crop(source(f"{faction}Button")), (512, 64))
        save(f"{faction}Chevron", alpha_crop(source(f"{faction}Chevron"), pad=45), (128, 128))
        save(f"{faction}Ring", alpha_crop(source(f"{faction}Ring"), pad=25), (256, 256))
        save(f"{faction}Glint", alpha_crop(source(f"{faction}Glint"), pad=22), (64, 128))
        save(f"{faction}Caption", alpha_crop(source(f"{faction}Caption")), (512, 64))
    save("HordeChevronHover", alpha_crop(source("HordeChevronHover"), pad=45), (128, 128))
    save("AllianceChevronHover", alpha_crop(source("AllianceChevronHover"), pad=45), (128, 128))

    # The character and insignia are cut from the selected Horde reference;
    # feathering keeps both composable over panels at different sizes.
    horde = source("HordeReference")
    save_right("HordeTalentHero", feather(horde.crop((1260, 100, 1660, 255)),
                                          45, 12, 5, 24), (512, 128))
    save_center("HordeSidebarMark", feather(horde.crop((32, 575, 355, 805)),
                                             20, 42, 16, 20), (256, 256))
    alliance = source("AllianceReference")
    save_right("AllianceCity", feather(alliance.crop((610, 2, 1295, 94)),
                                       55, 2, 55, 2), (512, 128))
    save_right("AllianceTalentHero", feather(alliance.crop((1225, 101, 1668, 267)),
                                             55, 14, 5, 20), (512, 128))
    save_center("AllianceSidebarMark", feather(alliance.crop((45, 574, 345, 814)),
                                                22, 25, 18, 20), (256, 256))


if __name__ == "__main__":
    main()
