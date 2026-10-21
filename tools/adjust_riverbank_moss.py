"""Только экспозиция прежнего Moss A; рисунок, оттенки и насыщенность не перерисовываются."""
from pathlib import Path
import numpy as np
from PIL import Image

root = Path(__file__).resolve().parents[1]
folder = root / 'assets/environment/riverbank/textures/ground/stylized_v2'
source = Image.open(folder / 'T_RB_Ground_Moss_A_BaseColor.png').convert('RGB')
srgb = np.asarray(source, dtype=np.float32) / 255.0
linear = np.where(srgb <= .04045, srgb / 12.92, ((srgb + .055) / 1.055) ** 2.4)
linear = np.clip(linear * 2 ** .4, 0, 1)
result = np.where(linear <= .0031308, linear * 12.92, 1.055 * linear ** (1 / 2.4) - .055)
Image.fromarray(np.rint(result * 255).astype(np.uint8)).save(folder / 'T_RB_Ground_Moss_A_Bright_BaseColor.png')
print('MOSS_EXPOSURE_OK: original Moss A, +0.4 EV, no generation')
