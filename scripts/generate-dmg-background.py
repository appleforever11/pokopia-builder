#!/usr/bin/env python3
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "dist/assets/pokopia-dmg-background-base.png"
DIST_OUT = ROOT / "dist/assets/pokopia-dmg-background.png"
DOCS_OUT = ROOT / "docs/assets/pokopia-dmg-background.png"

FONT_ROUNDED = "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf"
FONT_BLACK = "/System/Library/Fonts/Supplemental/Arial Black.ttf"


def font(path, size):
    return ImageFont.truetype(path, size)


def centered_text(draw, text, y, typeface, fill, stroke_fill=None, stroke_width=0):
    bbox = draw.textbbox((0, 0), text, font=typeface, stroke_width=stroke_width)
    x = (720 - (bbox[2] - bbox[0])) / 2
    draw.text(
        (x, y),
        text,
        font=typeface,
        fill=fill,
        stroke_fill=stroke_fill,
        stroke_width=stroke_width,
    )


def draw_checkered_badge(draw):
    badge = (168, 28, 552, 174)
    shadow = (badge[0] + 5, badge[1] + 7, badge[2] + 5, badge[3] + 7)
    draw.rounded_rectangle(shadow, radius=42, fill=(47, 95, 55, 82))
    draw.rounded_rectangle(badge, radius=42, fill=(190, 237, 108, 238), outline=(255, 255, 255, 255), width=8)

    colors = [(169, 222, 83, 92), (216, 248, 135, 92)]
    tile = 22
    for row, y in enumerate(range(badge[1] + 7, badge[3] - 8, tile)):
        for col, x in enumerate(range(badge[0] + 8, badge[2] - 8, tile)):
            color = colors[(row + col) % 2]
            draw.rounded_rectangle((x, y, x + tile, y + tile), radius=5, fill=color)

    draw.rounded_rectangle(badge, radius=42, outline=(255, 255, 255, 255), width=8)
    draw.rounded_rectangle((badge[0] + 10, badge[1] + 10, badge[2] - 10, badge[3] - 10), radius=34, outline=(123, 202, 81, 160), width=2)


def draw_pokopia_builder_logo(draw):
    draw_checkered_badge(draw)

    title = "Pokopia"
    title_font = font(FONT_ROUNDED, 58)
    letter_colors = [
        (39, 183, 232, 255),
        (255, 178, 50, 255),
        (251, 117, 80, 255),
        (111, 208, 93, 255),
        (153, 114, 232, 255),
        (255, 139, 201, 255),
        (72, 195, 88, 255),
    ]

    widths = [draw.textlength(ch, font=title_font) for ch in title]
    total = sum(widths) - 20
    x = (720 - total) / 2
    y = 65
    for index, ch in enumerate(title):
        wobble = [-5, 3, -2, 4, -4, 2, -3][index]
        color = letter_colors[index % len(letter_colors)]
        draw.text((x + 3, y + wobble + 4), ch, font=title_font, fill=(40, 77, 88, 90), stroke_width=7, stroke_fill=(40, 77, 88, 90))
        draw.text((x, y + wobble), ch, font=title_font, fill=color, stroke_width=7, stroke_fill=(255, 255, 255, 255))
        draw.text((x, y + wobble), ch, font=title_font, fill=color, stroke_width=2, stroke_fill=(38, 93, 165, 255))
        x += widths[index] - 3

    builder_font = font(FONT_BLACK, 28)
    centered_text(draw, "BUILDER", 125, builder_font, (255, 224, 74, 255), stroke_fill=(31, 92, 168, 255), stroke_width=4)


def draw_install_cue(draw):
    cue_font = font(FONT_ROUNDED, 23)
    small_font = font(FONT_ROUNDED, 15)

    panel = (178, 358, 542, 410)
    draw.rounded_rectangle((panel[0] + 3, panel[1] + 4, panel[2] + 3, panel[3] + 4), radius=17, fill=(44, 82, 88, 72))
    draw.rounded_rectangle(panel, radius=17, fill=(255, 255, 255, 182), outline=(255, 255, 255, 235), width=2)
    centered_text(draw, "Drag app to Applications", 366, cue_font, (30, 74, 88, 255))
    centered_text(draw, "Drop the icon on the blue folder", 392, small_font, (58, 97, 106, 245))

    start = (306, 309)
    end = (404, 309)
    draw.line((start[0] + 3, start[1] + 4, end[0] + 3, end[1] + 4), fill=(40, 95, 115, 95), width=13)
    draw.line((start[0], start[1], end[0], end[1]), fill=(255, 255, 255, 238), width=9)
    draw.line((start[0], start[1], end[0], end[1]), fill=(61, 183, 215, 255), width=5)

    head = [(410, 309), (388, 292), (393, 309), (388, 326)]
    draw.polygon([(x + 3, y + 4) for x, y in head], fill=(40, 95, 115, 95))
    draw.polygon(head, fill=(61, 183, 215, 255))
    draw.line(head + [head[0]], fill=(255, 255, 255, 238), width=2)


def main():
    image = Image.open(BASE).convert("RGBA")
    draw = ImageDraw.Draw(image)
    draw_pokopia_builder_logo(draw)
    draw_install_cue(draw)

    output = image.convert("RGB")
    DIST_OUT.parent.mkdir(parents=True, exist_ok=True)
    DOCS_OUT.parent.mkdir(parents=True, exist_ok=True)
    output.save(DIST_OUT, optimize=True)
    output.save(DOCS_OUT, optimize=True)
    print(DIST_OUT)
    print(DOCS_OUT)


if __name__ == "__main__":
    main()
