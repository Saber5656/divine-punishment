"""Render generated characters or a separated architecture kit for visual review."""
import argparse
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

parser = argparse.ArgumentParser()
parser.add_argument('--assets', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--kind', choices=['characters', 'architecture'], default='characters')
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
bpy.ops.wm.read_factory_settings(use_empty=True)
if args.kind == 'characters':
    for index, name in enumerate(('shinobi', 'ashigaru', 'magistrate')):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(args.assets/'characters'/f'{name}.glb'))
        for obj in set(bpy.data.objects) - before:
            if not obj.parent:
                obj.location.x += (index - 1) * 2.2
    camera_location = (2, -8, 3.1)
    focus = (0, 0, 1)
    scale = 7.4
else:
    bpy.ops.import_scene.gltf(filepath=str(args.assets/'environment'/'residence_modules.glb'))
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    for i, obj in enumerate(meshes):
        obj.location += Vector(((i % 4) * 4 - 6, (i // 4) * 4 - 4, 0))
    camera_location = (12, -17, 15)
    focus = (0, 0, .5)
    scale = 19
for obj in list(bpy.data.objects):
    if obj.name.startswith('Icosphere'):
        bpy.data.objects.remove(obj, do_unlink=True)
bpy.ops.object.camera_add(location=camera_location)
camera = bpy.context.object
camera.rotation_euler = (Vector(focus) - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.type = 'ORTHO'
camera.data.ortho_scale = scale
scene = bpy.context.scene
scene.camera = camera
for location, power, size in [((2, -4, 7), 1300, 5), ((-4, 2, 5), 1800, 4)]:
    bpy.ops.object.light_add(type='AREA', location=location)
    light = bpy.context.object
    light.data.energy = power
    light.data.shape = 'DISK'
    light.data.size = size
    light.rotation_euler = (Vector(focus) - light.location).to_track_quat('-Z','Y').to_euler()
scene.world = bpy.data.worlds.new('Review world')
scene.world.color = (.16, .17, .19)
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.render.resolution_x = 1800
scene.render.resolution_y = 1000
scene.render.resolution_percentage = 100
scene.render.filepath = str(args.output)
bpy.ops.render.render(write_still=True)
