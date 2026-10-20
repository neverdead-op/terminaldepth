"""Cut the author's single generated atlas into transparent game icons."""
from pathlib import Path
import shutil
import sys
from PIL import Image
from collections import deque

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/icons/act_one'
ROWS = [
    ['plasma_cutter','plasma_cutter_mk2','shotgun','pump_shotgun','rifle','carbine'],
    ['patrol_helmet','bastion_helmet','assault_helmet','command_helmet','sensor_helmet','emitter_crown'],
    ['vest','exoskeleton','spacesuit','drop_suit','hazmat','hive_suit'],
    ['tactical_gloves','power_gloves','combat_mitts','relay_gloves','conductor_gloves','neuro_gloves'],
    ['army_boots','servo_boots','scout_boots','relay_boots','mag_boots','grav_boots'],
]

def main(source):
    OUT.mkdir(parents=True, exist_ok=True)
    archive = ROOT / 'docs/item_concepts/act_one'
    archive.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, archive/'atlas.png')
    atlas = Image.open(source).convert('RGBA')
    # Measured empty gutters, so no neighbouring icon is included.
    columns = [
        [0,224,452,686,928,1136,atlas.width],
        [0,230,460,694,936,1150,atlas.width],
        [0,232,492,694,936,1150,atlas.width],
        [0,236,484,700,936,1150,atlas.width],
        [0,244,484,708,938,1150,atlas.width],
    ]
    ys = [0,218,437,682,889,atlas.height]
    for row, names in enumerate(ROWS):
        xs = columns[row]
        for col, name in enumerate(names):
            tile = atlas.crop((xs[col],ys[row],xs[col+1],ys[row+1]))
            # Remove tiny detached pixels from a neighbouring cell at a gutter.
            alpha = tile.getchannel('A')
            pixels = alpha.load()
            seen = set()
            groups = []
            for y in range(tile.height):
                for x in range(tile.width):
                    if (x,y) in seen or pixels[x,y] <= 20:
                        continue
                    component = []
                    queue = deque([(x,y)])
                    seen.add((x,y))
                    while queue:
                        px,py = queue.popleft()
                        component.append((px,py))
                        for nx,ny in [(px-1,py),(px+1,py),(px,py-1),(px,py+1)]:
                            if 0 <= nx < tile.width and 0 <= ny < tile.height and (nx,ny) not in seen and pixels[nx,ny] > 20:
                                seen.add((nx,ny))
                                queue.append((nx,ny))
                    groups.append(component)
            largest = max(map(len,groups))
            for component in groups:
                if len(component) < largest * .01:
                    for x,y in component:
                        tile.putpixel((x,y),(0,0,0,0))
            box = tile.getchannel('A').point(lambda a: 255 if a > 20 else 0).getbbox()
            assert box, name
            tile = tile.crop(box)
            tile.thumbnail((240,240),Image.Resampling.LANCZOS)
            result = Image.new('RGBA',(tile.width+16,tile.height+16))
            result.paste(tile,(8,8))
            result.save(OUT/(name+'.png'))
    print('Saved 30 transparent icons and original atlas.')

if __name__ == '__main__':
    main(sys.argv[1])
