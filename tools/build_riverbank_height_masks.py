"""Технические маски переходов из цветовых областей; не физические карты глубины."""
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / 'assets/environment/riverbank/textures/ground/stylized_v2'

def smooth(low, high, value):
    t = np.clip((value-low)/(high-low), 0, 1)
    return t*t*(3-2*t)

for name in ['Flagstone', 'BrokenSlate']:
    rgb = np.asarray(Image.open(FOLDER / f'T_RB_Ground_{name}_A_BaseColor.png').convert('RGB'), dtype=float)/255
    r,g,b = rgb.transpose(2,0,1)
    if name == 'Flagstone':
        # Тёмные швы ниже светлых плоскостей плит, без зависимости от итогового освещения.
        luminance = r*.2126+g*.7152+b*.0722
        height = .12+.78*smooth(.22,.34,luminance)
    else:
        # Холодный сланец выше тёплой земли; зелёные растения не считаем камнем.
        stone = smooth(-.035,.035,b-r)*smooth(.0,.055,b-g)
        height = .18+.7*stone
    output = FOLDER / f'T_RB_Ground_{name}_A_Height.png'
    Image.fromarray(np.uint8(np.clip(height,0,1)*255)).filter(ImageFilter.GaussianBlur(1.2)).save(output)
    print(output.relative_to(ROOT))
