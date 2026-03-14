from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter


REPO_ROOT = Path(__file__).resolve().parents[1]
SOURCE_ICON_PATH = REPO_ROOT / "assets/origin.png"
MANIFEST_BRAND_COLOR = "#E6A6BE"
MASTER_SIZE = 1024

ANDROID_LEGACY_ICON_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

ANDROID_ADAPTIVE_ICON_SIZES = {
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}

IOS_ICON_SIZES = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}

MACOS_ICON_SIZES = {
    "app_icon_16.png": 16,
    "app_icon_32.png": 32,
    "app_icon_64.png": 64,
    "app_icon_128.png": 128,
    "app_icon_256.png": 256,
    "app_icon_512.png": 512,
    "app_icon_1024.png": 1024,
}

WEB_ICON_SIZES = {
    "Icon-192.png": 192,
    "Icon-512.png": 512,
}

WEB_MASKABLE_ICON_SIZES = {
    "Icon-maskable-192.png": 192,
    "Icon-maskable-512.png": 512,
}

WINDOWS_ICO_SIZES = [16, 24, 32, 48, 64, 128, 256]

IOS_BACKGROUND_TOP = (0xFF, 0xF6, 0xFA, 0xFF)
IOS_BACKGROUND_BOTTOM = (0xF4, 0xC8, 0xDA, 0xFF)
ANDROID_BACKGROUND_TOP = (0xFF, 0xF2, 0xF8, 0xFF)
ANDROID_BACKGROUND_BOTTOM = (0xD7, 0x86, 0xA3, 0xFF)
WINDOWS_BACKGROUND_TOP = (0xFF, 0xF5, 0xFA, 0xFF)
WINDOWS_BACKGROUND_BOTTOM = (0xE8, 0xAB, 0xC2, 0xFF)
PANEL_TOP = (0xFF, 0xFE, 0xFF, 0xFF)
PANEL_BOTTOM = (0xFA, 0xF0, 0xF5, 0xFF)
PANEL_BORDER = (0xFF, 0xFF, 0xFF, 0x9A)
PANEL_INNER_GLOW = (0xFF, 0xF1, 0xF7, 0x96)
MAC_PANEL_HALO = (0xF4, 0xC9, 0xD8, 0x6E)
FLOWER_SHADOW = (0xBE, 0x73, 0x8D, 0x88)
PANEL_SHADOW = (0xA8, 0x62, 0x7B, 0x78)
MAC_PANEL_SHADOW = (0x74, 0x42, 0x56, 0x8C)
WINDOWS_PANEL_SHADOW = (0x8C, 0x4C, 0x63, 0x7A)


def clamp(value: float, lower: int = 0, upper: int = 255) -> int:
    return max(lower, min(upper, int(round(value))))


def blend(
    color_a: tuple[int, int, int, int],
    color_b: tuple[int, int, int, int],
    factor: float,
) -> tuple[int, int, int, int]:
    return tuple(
        clamp(color_a[index] * (1 - factor) + color_b[index] * factor)
        for index in range(4)
    )


def vertical_gradient(
    size: int,
    top: tuple[int, int, int, int],
    bottom: tuple[int, int, int, int],
) -> Image.Image:
    vertical_mask = Image.linear_gradient("L").resize(
        (size, size),
        Image.Resampling.BICUBIC,
    )
    return Image.composite(
        Image.new("RGBA", (size, size), bottom),
        Image.new("RGBA", (size, size), top),
        vertical_mask,
    )


def expand_box(
    box: tuple[int, int, int, int],
    padding: int,
    bounds: tuple[int, int],
) -> tuple[int, int, int, int]:
    left = max(0, box[0] - padding)
    top = max(0, box[1] - padding)
    right = min(bounds[0], box[2] + padding)
    bottom = min(bounds[1], box[3] + padding)
    return left, top, right, bottom


def extract_flower(source_path: Path) -> Image.Image:
    with Image.open(source_path) as source_image:
        source = source_image.convert("RGBA")

    source = ImageEnhance.Color(source).enhance(1.08)
    source = ImageEnhance.Contrast(source).enhance(1.04)
    crop = source.crop((232, 182, 792, 768))

    alpha_values = []
    pixels = crop.load()
    for y in range(crop.height):
        for x in range(crop.width):
            red, green, blue, _ = pixels[x, y]
            white_distance = 255 - ((red + green + blue) // 3)
            tint = max(red, green, blue) - min(red, green, blue)
            signal = max(white_distance * 1.35, tint * 2.4)
            alpha_values.append(0 if signal < 8 else clamp((signal - 8) * 9.5))

    mask = Image.new("L", crop.size)
    mask.putdata(alpha_values)
    mask = mask.filter(ImageFilter.GaussianBlur(radius=2))

    flower = crop.copy()
    flower.putalpha(mask)

    bbox = flower.getbbox()
    if bbox is None:
        raise ValueError(f"Could not isolate a flower from {source_path}.")

    flower = flower.crop(expand_box(bbox, 24, flower.size))
    return ImageEnhance.Color(flower).enhance(1.05)


def create_panel(
    size: int,
    radius: int,
    top_color: tuple[int, int, int, int],
    bottom_color: tuple[int, int, int, int],
    border_color: tuple[int, int, int, int],
    border_width: int,
    gloss_alpha: int,
) -> Image.Image:
    panel = vertical_gradient(size, top_color, bottom_color)
    mask = Image.new("L", (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle(
        (0, 0, size - 1, size - 1),
        radius=radius,
        fill=255,
    )
    panel.putalpha(mask)

    if gloss_alpha > 0:
        gloss = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        gloss_draw = ImageDraw.Draw(gloss, "RGBA")
        gloss_draw.ellipse(
            (
                -size * 0.10,
                -size * 0.28,
                size * 0.95,
                size * 0.42,
            ),
            fill=(255, 255, 255, gloss_alpha),
        )
        gloss = gloss.filter(ImageFilter.GaussianBlur(radius=size * 0.05))
        gloss.putalpha(ImageChops.multiply(gloss.getchannel("A"), mask))
        panel = Image.alpha_composite(panel, gloss)

    if border_width > 0:
        border = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        border_draw = ImageDraw.Draw(border, "RGBA")
        inset = border_width / 2
        border_draw.rounded_rectangle(
            (inset, inset, size - 1 - inset, size - 1 - inset),
            radius=max(0, radius - inset),
            outline=border_color,
            width=border_width,
        )
        border.putalpha(ImageChops.multiply(border.getchannel("A"), mask))
        panel = Image.alpha_composite(panel, border)

    return panel


def add_ellipse_glow(
    canvas: Image.Image,
    bounds: tuple[float, float, float, float],
    color: tuple[int, int, int, int],
    blur_radius: float,
) -> None:
    overlay = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    overlay_draw = ImageDraw.Draw(overlay, "RGBA")
    overlay_draw.ellipse(bounds, fill=color)
    overlay = overlay.filter(ImageFilter.GaussianBlur(radius=blur_radius))
    canvas.alpha_composite(overlay)


def add_center_glow(
    canvas: Image.Image,
    diameter: int,
    color: tuple[int, int, int, int],
    y_offset: int = 0,
) -> None:
    left = (canvas.width - diameter) // 2
    top = (canvas.height - diameter) // 2 + y_offset
    add_ellipse_glow(
        canvas,
        (left, top, left + diameter, top + diameter),
        color,
        blur_radius=diameter * 0.18,
    )


def make_shadow(image: Image.Image, color: tuple[int, int, int, int], blur: int) -> tuple[Image.Image, int]:
    padding = blur * 4 if blur > 0 else 0
    shadow = Image.new(
        "RGBA",
        (image.width + padding * 2, image.height + padding * 2),
        (0, 0, 0, 0),
    )
    alpha = image.getchannel("A").point(
        lambda value: clamp(value * color[3] / 255),
    )
    tinted = Image.new("RGBA", image.size, color[:3] + (0,))
    tinted.putalpha(alpha)
    shadow.alpha_composite(tinted, dest=(padding, padding))
    if blur > 0:
        shadow = shadow.filter(ImageFilter.GaussianBlur(radius=blur))
    return shadow, padding


def place_centered(
    canvas: Image.Image,
    image: Image.Image,
    x_offset: int = 0,
    y_offset: int = 0,
) -> tuple[int, int]:
    x = (canvas.width - image.width) // 2 + x_offset
    y = (canvas.height - image.height) // 2 + y_offset
    canvas.alpha_composite(image, dest=(x, y))
    return x, y


def resize_by_width(image: Image.Image, width: int) -> Image.Image:
    height = round(image.height * width / image.width)
    return image.resize((width, height), Image.Resampling.LANCZOS)


def add_flower(
    canvas: Image.Image,
    flower: Image.Image,
    width: int,
    y_offset: int,
    shadow_color: tuple[int, int, int, int],
    shadow_blur: int,
    shadow_offset: tuple[int, int],
) -> None:
    flower_layer = resize_by_width(flower, width)
    shadow, padding = make_shadow(flower_layer, shadow_color, shadow_blur)
    flower_x = (canvas.width - flower_layer.width) // 2
    flower_y = (canvas.height - flower_layer.height) // 2 + y_offset
    canvas.alpha_composite(
        shadow,
        dest=(
            flower_x - padding + shadow_offset[0],
            flower_y - padding + shadow_offset[1],
        ),
    )
    canvas.alpha_composite(flower_layer, dest=(flower_x, flower_y))


def add_panel_to_canvas(
    canvas: Image.Image,
    panel: Image.Image,
    y_offset: int,
    shadow_color: tuple[int, int, int, int],
    shadow_blur: int,
    shadow_offset: tuple[int, int],
) -> None:
    shadow, padding = make_shadow(panel, shadow_color, shadow_blur)
    panel_x = (canvas.width - panel.width) // 2
    panel_y = (canvas.height - panel.height) // 2 + y_offset
    canvas.alpha_composite(
        shadow,
        dest=(
            panel_x - padding + shadow_offset[0],
            panel_y - padding + shadow_offset[1],
        ),
    )
    canvas.alpha_composite(panel, dest=(panel_x, panel_y))


def render_ios_icon(flower: Image.Image) -> Image.Image:
    canvas = vertical_gradient(MASTER_SIZE, IOS_BACKGROUND_TOP, IOS_BACKGROUND_BOTTOM)
    add_ellipse_glow(canvas, (-160, -160, 620, 560), (255, 255, 255, 130), 120)
    add_ellipse_glow(canvas, (420, 360, 1160, 1120), (255, 230, 240, 95), 160)

    panel = create_panel(
        size=724,
        radius=184,
        top_color=PANEL_TOP,
        bottom_color=PANEL_BOTTOM,
        border_color=PANEL_BORDER,
        border_width=4,
        gloss_alpha=68,
    )
    add_center_glow(panel, 472, PANEL_INNER_GLOW, y_offset=-36)
    add_flower(
        panel,
        flower,
        width=512,
        y_offset=-10,
        shadow_color=FLOWER_SHADOW,
        shadow_blur=24,
        shadow_offset=(0, 18),
    )
    add_panel_to_canvas(
        canvas,
        panel,
        y_offset=36,
        shadow_color=PANEL_SHADOW,
        shadow_blur=50,
        shadow_offset=(0, 28),
    )
    return canvas


def render_macos_icon(flower: Image.Image) -> Image.Image:
    canvas = Image.new("RGBA", (MASTER_SIZE, MASTER_SIZE), (0, 0, 0, 0))
    add_ellipse_glow(canvas, (98, 104, 926, 932), MAC_PANEL_HALO, 74)

    panel = create_panel(
        size=844,
        radius=232,
        top_color=(255, 255, 255, 255),
        bottom_color=(249, 241, 246, 255),
        border_color=(255, 255, 255, 168),
        border_width=4,
        gloss_alpha=72,
    )
    add_center_glow(panel, 540, (255, 239, 246, 120), y_offset=-32)
    add_flower(
        panel,
        flower,
        width=596,
        y_offset=-8,
        shadow_color=(0xAF, 0x67, 0x83, 0x80),
        shadow_blur=28,
        shadow_offset=(0, 20),
    )
    add_panel_to_canvas(
        canvas,
        panel,
        y_offset=10,
        shadow_color=MAC_PANEL_SHADOW,
        shadow_blur=68,
        shadow_offset=(0, 34),
    )
    return canvas


def render_android_background() -> Image.Image:
    canvas = vertical_gradient(
        MASTER_SIZE,
        ANDROID_BACKGROUND_TOP,
        ANDROID_BACKGROUND_BOTTOM,
    )
    add_ellipse_glow(canvas, (-220, -180, 580, 540), (255, 255, 255, 110), 128)
    add_ellipse_glow(canvas, (340, 280, 1120, 1080), (255, 224, 236, 92), 166)
    return canvas


def render_android_foreground(flower: Image.Image) -> Image.Image:
    canvas = Image.new("RGBA", (MASTER_SIZE, MASTER_SIZE), (0, 0, 0, 0))
    panel = create_panel(
        size=624,
        radius=168,
        top_color=PANEL_TOP,
        bottom_color=PANEL_BOTTOM,
        border_color=(255, 255, 255, 150),
        border_width=4,
        gloss_alpha=60,
    )
    add_center_glow(panel, 408, (255, 239, 246, 112), y_offset=-26)
    add_flower(
        panel,
        flower,
        width=470,
        y_offset=-8,
        shadow_color=(0xB7, 0x6D, 0x87, 0x84),
        shadow_blur=22,
        shadow_offset=(0, 16),
    )
    add_panel_to_canvas(
        canvas,
        panel,
        y_offset=18,
        shadow_color=(0x9B, 0x59, 0x73, 0x72),
        shadow_blur=28,
        shadow_offset=(0, 20),
    )
    return canvas


def render_windows_icon(flower: Image.Image) -> Image.Image:
    canvas = vertical_gradient(
        MASTER_SIZE,
        WINDOWS_BACKGROUND_TOP,
        WINDOWS_BACKGROUND_BOTTOM,
    )
    add_ellipse_glow(canvas, (-180, -160, 600, 560), (255, 255, 255, 110), 126)
    add_ellipse_glow(canvas, (380, 320, 1120, 1080), (255, 231, 240, 92), 152)

    panel = create_panel(
        size=704,
        radius=164,
        top_color=PANEL_TOP,
        bottom_color=blend(PANEL_BOTTOM, (255, 233, 242, 255), 0.35),
        border_color=PANEL_BORDER,
        border_width=4,
        gloss_alpha=62,
    )
    add_center_glow(panel, 440, (255, 241, 247, 110), y_offset=-28)
    add_flower(
        panel,
        flower,
        width=500,
        y_offset=-8,
        shadow_color=FLOWER_SHADOW,
        shadow_blur=20,
        shadow_offset=(0, 14),
    )
    add_panel_to_canvas(
        canvas,
        panel,
        y_offset=28,
        shadow_color=WINDOWS_PANEL_SHADOW,
        shadow_blur=34,
        shadow_offset=(0, 24),
    )
    return canvas


def render_maskable_icon(
    background: Image.Image,
    flower: Image.Image,
) -> Image.Image:
    foreground = Image.new("RGBA", (MASTER_SIZE, MASTER_SIZE), (0, 0, 0, 0))
    panel = create_panel(
        size=560,
        radius=152,
        top_color=PANEL_TOP,
        bottom_color=PANEL_BOTTOM,
        border_color=(255, 255, 255, 148),
        border_width=4,
        gloss_alpha=54,
    )
    add_center_glow(panel, 380, (255, 240, 247, 108), y_offset=-24)
    add_flower(
        panel,
        flower,
        width=420,
        y_offset=-6,
        shadow_color=(0xB6, 0x70, 0x88, 0x82),
        shadow_blur=20,
        shadow_offset=(0, 14),
    )
    add_panel_to_canvas(
        foreground,
        panel,
        y_offset=14,
        shadow_color=(0x98, 0x58, 0x70, 0x6E),
        shadow_blur=24,
        shadow_offset=(0, 18),
    )
    icon = background.copy()
    icon.alpha_composite(foreground)
    return icon


def save_png_variants(
    image: Image.Image,
    destination: Path,
    mapping: dict[str, int],
) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    for filename, size in mapping.items():
        resized = image.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(destination / filename)


def save_android_icons(
    legacy_icon: Image.Image,
    foreground: Image.Image,
    background: Image.Image,
    root: Path,
) -> None:
    resource_root = root / "android/app/src/main/res"

    for density, size in ANDROID_LEGACY_ICON_SIZES.items():
        destination = resource_root / density
        destination.mkdir(parents=True, exist_ok=True)
        resized = legacy_icon.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(destination / "ic_launcher.png")
        resized.save(destination / "ic_launcher_round.png")

    for density, size in ANDROID_ADAPTIVE_ICON_SIZES.items():
        destination = resource_root / density
        destination.mkdir(parents=True, exist_ok=True)
        foreground.resize((size, size), Image.Resampling.LANCZOS).save(
            destination / "ic_launcher_foreground.png",
        )
        background.resize((size, size), Image.Resampling.LANCZOS).save(
            destination / "ic_launcher_background.png",
        )

    anydpi = resource_root / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    adaptive_icon_xml = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
"""
    (anydpi / "ic_launcher.xml").write_text(adaptive_icon_xml, encoding="utf-8")
    (anydpi / "ic_launcher_round.xml").write_text(
        adaptive_icon_xml,
        encoding="utf-8",
    )


def save_windows_icon(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="ICO", sizes=[(size, size) for size in WINDOWS_ICO_SIZES])


def update_manifest(path: Path) -> None:
    manifest = json.loads(path.read_text(encoding="utf-8"))
    manifest["background_color"] = MANIFEST_BRAND_COLOR
    manifest["theme_color"] = MANIFEST_BRAND_COLOR
    path.write_text(
        json.dumps(manifest, indent=4, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def generate_assets(output_root: Path, manifest_path: Path, source_path: Path) -> None:
    flower = extract_flower(source_path)
    ios_icon = render_ios_icon(flower)
    macos_icon = render_macos_icon(flower)
    android_background = render_android_background()
    android_foreground = render_android_foreground(flower)
    android_legacy = android_background.copy()
    android_legacy.alpha_composite(android_foreground)
    windows_icon = render_windows_icon(flower)
    maskable_icon = render_maskable_icon(android_background, flower)

    master_path = output_root / "assets/branding/app_icon_master.png"
    master_path.parent.mkdir(parents=True, exist_ok=True)
    ios_icon.save(master_path)

    save_android_icons(
        legacy_icon=android_legacy,
        foreground=android_foreground,
        background=android_background,
        root=output_root,
    )
    save_png_variants(
        ios_icon,
        output_root / "ios/Runner/Assets.xcassets/AppIcon.appiconset",
        IOS_ICON_SIZES,
    )
    save_png_variants(
        macos_icon,
        output_root / "macos/Runner/Assets.xcassets/AppIcon.appiconset",
        MACOS_ICON_SIZES,
    )
    save_png_variants(ios_icon, output_root / "web/icons", WEB_ICON_SIZES)
    save_png_variants(maskable_icon, output_root / "web/icons", WEB_MASKABLE_ICON_SIZES)
    save_windows_icon(windows_icon, output_root / "windows/runner/resources/app_icon.ico")
    update_manifest(manifest_path)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate SakuraMedia app icons.")
    parser.add_argument(
        "--output-root",
        default=str(REPO_ROOT),
        help="Root directory where icon assets should be written.",
    )
    parser.add_argument(
        "--manifest",
        default=str(REPO_ROOT / "web/manifest.json"),
        help="Web manifest file to update with brand colors.",
    )
    parser.add_argument(
        "--source",
        default=str(SOURCE_ICON_PATH),
        help="Source PNG used to extract the flower mark.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    generate_assets(
        output_root=Path(args.output_root),
        manifest_path=Path(args.manifest),
        source_path=Path(args.source),
    )


if __name__ == "__main__":
    main()
