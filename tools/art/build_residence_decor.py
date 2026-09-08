"""Project-authored tatami, fusuma and garden kit; Blender 5.2 LTS.

blender --background --factory-startup --python-exit-code 1 --python \
  tools/art/build_residence_decor.py -- --output assets/environment/residence_decor.glb
"""
import argparse
import math
from pathlib import Path
import sys
import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_production_assets import reset, material, cube, cylinder, export


def module(name, build):
    before = set(bpy.data.objects)
    build()
    parts = [o for o in bpy.data.objects if o not in before and o.type == 'MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    reset()
    straw = material('Rush straw', (.35, .34, .19))
    seam = material('Tatami indigo border', (.025, .042, .047))
    paper = material('Ivory fusuma paper', (.61, .57, .44))
    cedar = material('Dark cedar', (.09, .055, .028))
    ink = material('Ink pine silhouette', (.055, .068, .046))
    green = material('Pine needles', (.035, .095, .064))
    rock = material('Garden granite', (.23, .25, .24))
    moss = material('Moss', (.11, .16, .075))

    def tatami():
        cube('rush', (0, 0, .055), (1, 2, .11), straw, .006)
        for x in (-.48, .48):
            cube('cloth', (x, 0, .112), (.04, 2, .008), seam, .002)
        for i in range(28):
            cube('woven rib', (0, -.98 + i * .070, .113), (.91, .002, .001), straw, 0)
    module('tatami_1x2', tatami)

    def fusuma():
        cube('paper', (0, 0, 1.3), (1.9, .045, 2.5), paper, .004)
        for x in (-.97, .97):
            cube('frame', (x, 0, 1.3), (.06, .12, 2.6), cedar)
        for z in (.03, 2.57):
            cube('frame', (0, 0, z), (2, .12, .06), cedar)
        for side in (-1, 1):
            pull = cylinder('recessed pull', (.67, side * .042, 1.1), .055, .018, ink, 16)
            pull.rotation_euler.x = math.pi / 2
            # Original geometric ink landscape, not a copied painting.
            for i in range(6):
                bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1, location=(-.58 + i*.20, side*.027, .5 + math.sin(i)*.12))
                o = bpy.context.object; o.scale = (.26, .009, .08); o.data.materials.append(ink)
    module('fusuma_2m', fusuma)

    def pine():
        trunk = cylinder('trunk', (0, 0, 1.5), .13, 3, cedar)
        trunk.rotation_euler.y = -.12
        for i, (x, y, z) in enumerate([(-.5, 0, 1.7), (.6, .15, 2.15), (-.25, -.1, 2.8)]):
            branch = cylinder('branch', (x*.5, y*.5, z-.15), .065, abs(x)+.5, cedar, 8)
            branch.rotation_euler.y = math.pi / 3 * (-1 if x < 0 else 1)
            bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1, location=(x, y, z))
            o = bpy.context.object; o.scale = (.95, .75, .3); o.data.materials.append(green)
    module('garden_pine', pine)

    def stone():
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1, location=(0,0,.3))
        o = bpy.context.object; o.scale = (.8,.65,.6); o.data.materials.append(rock)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1, location=(.08,0,.72))
        o = bpy.context.object; o.scale = (.54,.48,.13); o.data.materials.append(moss)
    module('moss_stone', stone)
    export(args.output)


if __name__ == '__main__':
    main()
