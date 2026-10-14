#!/usr/bin/env python3
"""Rebuild native icon variants from the bundled, unmodified official PNG.

Requires Pillow. No network, generated typography, artificial corner mask, or
product launch hook. Crop only transparent margins; preserve the supplied ink.
"""
from pathlib import Path
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / 'StayGrubby' / 'Assets.xcassets'
SOURCE = ASSETS / 'StayGrubbyWordmark.imageset' / 'StayGrubbyWordmark.png'
ICON = ASSETS / 'AppIcon.appiconset'
CREAM = (250, 243, 236)
CHARCOAL = (31, 31, 31)

source = Image.open(SOURCE).convert('RGBA')
# Disregard nearly transparent isolated source-export specks outside the ink.
bounds = source.getchannel('A').point(lambda alpha: 255 if alpha >= 32 else 0).getbbox()
logo = source.crop(bounds)
logo.thumbnail((824, 824), Image.Resampling.LANCZOS)
position = ((1024 - logo.width) // 2, (1024 - logo.height) // 2)
for name, background in [('AppIcon-Light.png', CREAM), ('AppIcon-Dark.png', CHARCOAL)]:
    icon = Image.new('RGB', (1024, 1024), background)
    icon.paste(logo, position, logo)
    icon.save(ICON / name)
# Apple tints the grayscale artwork. Preserve identical silhouette/placement;
# white ink and an opaque black field provide a clean native luminance mask.
tinted = Image.new('RGB', (1024, 1024), (0, 0, 0))
tinted.paste(Image.new('RGB', logo.size, (255, 255, 255)), position, logo.getchannel('A'))
tinted.save(ICON / 'AppIcon-Tinted.png')
images = []
for name, appearance in [('AppIcon-Light.png', None), ('AppIcon-Dark.png', 'dark'), ('AppIcon-Tinted.png', 'tinted')]:
    entry = dict(filename=name, idiom='universal', platform='ios', size='1024x1024')
    if appearance:
        entry['appearances'] = [dict(appearance='luminosity', value=appearance)]
    images.append(entry)
(ICON / 'Contents.json').write_text(json.dumps(dict(images=images, info=dict(author='xcode', version=1)), indent=2) + '\n')
print(f'Prepared three opaque 1024px native icon variants; official ink bounds {bounds}.')
