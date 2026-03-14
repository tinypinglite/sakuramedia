import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image


class GenerateAppIconsTest(unittest.TestCase):
    def setUp(self):
        self.repo_root = Path(__file__).resolve().parents[2]
        self.script_path = self.repo_root / "tool" / "generate_app_icons.py"
        self.temp_dir = Path(tempfile.mkdtemp(prefix="icon-gen-test-"))
        self.output_root = self.temp_dir / "output"
        self.manifest_path = self.temp_dir / "manifest.json"
        self.manifest_path.write_text(
            json.dumps(
                {
                    "name": "sakuramedia",
                    "background_color": "#0175C2",
                    "theme_color": "#0175C2",
                    "icons": [
                        {"src": "icons/Icon-192.png", "sizes": "192x192"},
                        {"src": "icons/Icon-512.png", "sizes": "512x512"},
                        {
                            "src": "icons/Icon-maskable-192.png",
                            "sizes": "192x192",
                            "purpose": "maskable",
                        },
                        {
                            "src": "icons/Icon-maskable-512.png",
                            "sizes": "512x512",
                            "purpose": "maskable",
                        },
                    ],
                },
                indent=2,
            ),
            encoding="utf-8",
        )

    def tearDown(self):
        shutil.rmtree(self.temp_dir)

    def run_generator(self):
        subprocess.run(
            [
                sys.executable,
                str(self.script_path),
                "--output-root",
                str(self.output_root),
                "--manifest",
                str(self.manifest_path),
            ],
            check=True,
            cwd=self.repo_root,
        )

    def test_generates_platform_specific_outputs(self):
        self.run_generator()

        master = self.output_root / "assets/branding/app_icon_master.png"
        ios_icon = (
            self.output_root
            / "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"
        )
        mac_icon = (
            self.output_root
            / "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png"
        )
        web_maskable = self.output_root / "web/icons/Icon-maskable-512.png"
        windows_icon = self.output_root / "windows/runner/resources/app_icon.ico"
        android_legacy = (
            self.output_root
            / "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"
        )
        android_round = (
            self.output_root
            / "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_round.png"
        )
        android_foreground = (
            self.output_root
            / "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png"
        )
        android_background = (
            self.output_root
            / "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_background.png"
        )
        adaptive_icon_xml = (
            self.output_root
            / "android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml"
        )
        adaptive_round_xml = (
            self.output_root
            / "android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml"
        )

        self.assertTrue(master.exists())
        self.assertTrue(ios_icon.exists())
        self.assertTrue(mac_icon.exists())
        self.assertTrue(web_maskable.exists())
        self.assertTrue(windows_icon.exists())
        self.assertTrue(android_legacy.exists())
        self.assertTrue(android_round.exists())
        self.assertTrue(android_foreground.exists())
        self.assertTrue(android_background.exists())
        self.assertTrue(adaptive_icon_xml.exists())
        self.assertTrue(adaptive_round_xml.exists())

        with Image.open(master) as master_image:
            self.assertEqual(master_image.size, (1024, 1024))

        with Image.open(ios_icon) as ios_image:
            self.assertEqual(ios_image.size, (1024, 1024))
            self.assertEqual(ios_image.getpixel((0, 0))[3], 255)

        with Image.open(mac_icon) as mac_image:
            self.assertEqual(mac_image.size, (1024, 1024))
            self.assertEqual(mac_image.getpixel((0, 0))[3], 0)
            self.assertGreater(mac_image.getpixel((512, 512))[3], 0)

        with Image.open(android_foreground) as foreground_image:
            self.assertEqual(foreground_image.size, (432, 432))
            self.assertEqual(foreground_image.getpixel((0, 0))[3], 0)
            self.assertGreater(foreground_image.getpixel((216, 216))[3], 0)

        with Image.open(android_background) as background_image:
            self.assertEqual(background_image.size, (432, 432))
            self.assertEqual(background_image.getpixel((0, 0))[3], 255)

        with Image.open(android_legacy) as legacy_image:
            self.assertEqual(legacy_image.size, (192, 192))
            self.assertEqual(legacy_image.getpixel((0, 0))[3], 255)

        with Image.open(web_maskable) as web_maskable_image:
            self.assertEqual(web_maskable_image.size, (512, 512))

        adaptive_xml_text = adaptive_icon_xml.read_text(encoding="utf-8")
        adaptive_round_xml_text = adaptive_round_xml.read_text(encoding="utf-8")
        self.assertIn("@mipmap/ic_launcher_background", adaptive_xml_text)
        self.assertIn("@mipmap/ic_launcher_foreground", adaptive_xml_text)
        self.assertEqual(adaptive_xml_text, adaptive_round_xml_text)
        self.assertGreater(windows_icon.stat().st_size, 0)

    def test_updates_manifest_brand_colors(self):
        self.run_generator()

        manifest = json.loads(self.manifest_path.read_text(encoding="utf-8"))

        self.assertEqual(manifest["background_color"], "#E6A6BE")
        self.assertEqual(manifest["theme_color"], "#E6A6BE")


if __name__ == "__main__":
    unittest.main()
