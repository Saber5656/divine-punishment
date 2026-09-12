"""Original Edo cargo-port modules. Run in Blender 5.2 LTS; no external assets."""
import argparse
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_production_assets import reset, material, cube, cylinder, export
from build_residence_decor import module


def bar_between(name, start, end, radius, mat):
    start, end = Vector(start), Vector(end)
    obj = cylinder(name, (start + end) * .5, radius, (end - start).length, mat, 8)
    obj.rotation_euler = (end - start).to_track_quat('Z', 'Y').to_euler()
    return obj


def polygon_mesh(name, vertices, faces, mat):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--preview-dir', type=Path)
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    reset()
    cedar = [material('Weathered cedar %d' % i, (.22+i*.005, .15+i*.004, .09+i*.003)) for i in range(4)]
    dark = material('Tarred timber', (.055, .045, .035))
    plaster = material('Oyster lime plaster', (.62, .60, .50))
    tile = material('Indigo fired tile', (.08, .12, .16), .65)
    iron = material('Blackened iron', (.075, .08, .075), .45, .7)
    rope = material('Hemp rope', (.44, .34, .18))
    paper = material('Rice paper', (.76, .65, .42))
    sail = material('Weathered canvas', (.67, .63, .49))
    ink = material('Merchant indigo', (.045, .08, .12))
    names = []

    def make(name, build):
        module(name, build)
        # Runtime batches use mesh resources directly; bake the chosen join object
        # transform so arbitrary set iteration cannot rotate/scale the module.
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        names.append(name)

    def planks():
        cube('Backing', (0, 0, -.08), (2, 2, .1), dark, 0)
        for i in range(7):
            x = -1+(i+.5)*2/7
            cube('Plank', (x, 0, -.035), (2/7-.004, 2, .07), cedar[i%4], .006)
            for y in (-.78, .78): cylinder('Nail', (x, y, .001), .012, .008, iron, 6)
    make('quay_planks_2m', planks)

    def pile():
        cylinder('Pile', (0, 0, -1), .18, 2.4, cedar[0], 12)
        for z in (-.12, -.26, -.4):
            bpy.ops.mesh.primitive_torus_add(major_radius=.183, minor_radius=.022,
                                           major_segments=16, minor_segments=6, location=(0, 0, z))
            bpy.context.object.data.materials.append(rope)
    make('quay_pile', pile)

    def panel():
        cube('Plaster', (0, 0, 1.2), (2, .18, 2.4), plaster, .01)
        for x in (-.95, .95): cube('Upright', (x, -.035, 1.2), (.1, .25, 2.4), dark, .005)
        for z in (.08, .42, 2.32): cube('Rail', (0, -.045, z), (2, .25, .12), cedar[0], .005)
        for i in range(8): cube('Lower cladding', (-.875+i*.25, -.12, .24), (.235, .035, .3), cedar[i%4], .003)
    make('storehouse_panel_2m', panel)

    def roof():
        cube('Roof backing', (0, 0, -.055), (2, 2, .1), dark, 0)
        for row in range(5):
            for col in range(8):
                part = cube('Overlapping tile', (-.875+col*.25, -.8+row*.4, -.013),
                            (.244, .41, .065), tile, .014)
                part.rotation_euler.x = .04
            for col in range(9):
                ridge = cylinder('Rounded seam', (-1+col*.25, -.8+row*.4, .015), .035, .4, tile, 8)
                ridge.rotation_euler.x = math.pi/2
    make('port_roof_2m', roof)

    def shoji():
        cube('Paper', (0, 0, 1.2), (1.88, .06, 2.25), paper, .005)
        for x in (-.96, .96): cube('Frame', (x, 0, 1.2), (.08, .18, 2.4), cedar[0])
        for z in (.05, 2.35): cube('Frame', (0, 0, z), (2, .18, .1), cedar[0])
        for x in (-.6, -.2, .2, .6): cube('Lattice', (x, -.045, 1.2), (.027, .07, 2.26), dark, .003)
        for z in (.4, .8, 1.2, 1.6, 2): cube('Lattice', (0, -.045, z), (1.88, .07, .027), dark, .003)
    make('house_shoji_2m', shoji)
    make('house_post', lambda: cube('Square post', (0, 0, 1.2), (.18, .18, 2.4), cedar[0]))

    def crate():
        cube('Box', (0, 0, .5), (.98, .98, 1), cedar[1], .015)
        for x in (-.36, .36): cube('Lid battens', (x, 0, 1.012), (.08, 1, .04), cedar[0], .005)
        for side in (-1, 1):
            for z in (.12, .88): cube('Band', (0, side*.497, z), (1, .025, .035), iron, .002)
            brace = cube('Diagonal brace', (0, side*.52, .5), (.1, .05, 1.16), cedar[0], .006)
            brace.rotation_euler.y = .72
        cube('Shipping mark', (0, -.526, .52), (.22, .008, .25), ink, 0)
    make('port_crate', crate)

    def barrel():
        vertices, faces = [], []
        for z, radius in [(0, .31), (.1, .37), (.42, .41), (.75, .37), (.84, .31)]:
            for i in range(16):
                angle = i*math.tau/16
                vertices.append((math.cos(angle)*radius, math.sin(angle)*radius, z))
        for row in range(4):
            for i in range(16): faces.append((row*16+i, row*16+(i+1)%16, (row+1)*16+(i+1)%16, (row+1)*16+i))
        faces.extend([tuple(range(15, -1, -1)), tuple(range(64, 80))])
        polygon_mesh('Staves', vertices, faces, cedar[2])
        for z in (.12, .7):
            bpy.ops.mesh.primitive_torus_add(major_radius=.376, minor_radius=.024,
                                           major_segments=16, minor_segments=6, location=(0, 0, z))
            bpy.context.object.data.materials.append(iron)
    make('port_barrel', barrel)

    def coil():
        for i in range(5):
            bpy.ops.mesh.primitive_torus_add(major_radius=.12+i*.055, minor_radius=.027,
                                           major_segments=24, minor_segments=6, location=(0, 0, .035))
            bpy.context.object.data.materials.append(rope)
    make('coiled_rope', coil)

    def hull():
        # Broad cargo sailing barge, fitted to the existing 12 x 14 x 3.8 hull.
        ring = [(-5, -7), (5, -7), (6, -6), (6, 6), (5, 7), (-5, 7), (-6, 6), (-6, -6)]
        vertices = [(x*.84, y*.88, -1.9) for x, y in ring]+[(x, y, 1.9) for x, y in ring]
        faces = [tuple(range(7, -1, -1)), tuple(range(8, 16))]
        for i in range(8): faces.append((i, (i+1)%8, (i+1)%8+8, i+8))
        polygon_mesh('Tarred hull', vertices, faces, dark)
        for band in range(7):
            z = -1.7+band*.55
            scale = .84+(z+1.9)/3.8*.16
            for i in range(8):
                a, b = ring[i], ring[(i+1)%8]
                bar_between('Clinker seam', (a[0]*scale, a[1]*scale, z), (b[0]*scale, b[1]*scale, z), .045, cedar[0])
        for i in range(30): cube('Deck plank', (-5.8+i*.4, 0, 1.92), (.388, 12, .1), cedar[i%4], .004)
        for x in (-5.7, 5.7):
            for y in range(-5, 6, 2): cylinder('Rail post', (x, y, 2.35), .08, .85, cedar[0], 8)
            bar_between('Gunwale', (x, -5.8, 2.75), (x, 5.8, 2.75), .08, cedar[0])
        for y in (-5.8, 5.8): bar_between('End rail', (-5.7, y, 2.75), (5.7, y, 2.75), .08, cedar[0])
        # Small stern deckhouse makes the working barge silhouette readable.
        cube('Deckhouse walls', (0, 4, 3.1), (4.6, 2.5, 2.3), cedar[1], .02)
        for x in (-1.65, -.55, .55, 1.65):
            cube('Cabin shutter', (x, 2.735, 3.25), (.85, .045, 1.1), dark, .01)
            for z in (2.9, 3.2, 3.5): cube('Shutter slat', (x, 2.69, z), (.9, .06, .07), cedar[0], .005)
        for x in (-1.3, 1.3):
            part = cube('Cabin roof', (x, 4, 4.3), (2.8, 3.1, .12), tile, .015)
            part.rotation_euler.y = .12 if x > 0 else -.12
        bar_between('Deckhouse ridge', (0, 2.45, 4.47), (0, 5.55, 4.47), .07, tile)

    make('cargo_ship_hull', hull)

    def rig():
        cylinder('Mast', (0, 0, 6.1), .16, 8.4, cedar[0], 12)
        for z in (3.9, 5.1, 6.3, 7.5, 8.7): bar_between('Sail batten', (-4.2, -.18, z), (4.2, -.18, z), .045, cedar[0])
        for row in range(4):
            z = 3.9+row*1.2
            polygon_mesh('Canvas panel', [(-4.1, -.16, z), (4.1, -.16, z), (4.1, -.16, z+1.2), (-4.1, -.16, z+1.2), (0, -.6, z+.6)],
                         [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4)], sail)
        for x in (-5.3, 5.3):
            for y in (-5, 5): bar_between('Standing rigging', (0, 0, 10), (x, y, 2.1), .022, rope)
        cube('Indigo sail seal', (0, -.625, 6.2), (1.25, .018, 1.25), ink, .005)
    make('cargo_ship_rig', rig)

    def lantern():
        cube('Paper shade', (0, 0, .45), (.38, .38, .6), paper, .025)
        for x in (-.2, .2):
            for y in (-.2, .2): cube('Corner', (x, y, .45), (.035, .035, .68), dark, .003)
        for z in (.12, .78): cube('Lid', (0, 0, z), (.48, .48, .07), cedar[0])
        cylinder('Stem', (0, 0, -.1), .065, .4, cedar[0], 8)
    make('port_lantern', lantern)

    def desk():
        # Closed counting cabinet fills the existing 1.1 x .8 x .7 solid.
        cube('Cabinet', (0, 0, -.02), (1.08, .68, .76), dark, .015)
        cube('Top', (0, 0, .36), (1.1, .7, .08), cedar[2], .01)
        for z in (-.22, .02, .25):
            cube('Drawer', (0, -.345, z), (1, .025, .19), cedar[0], .005)
            cube('Pull', (0, -.365, z), (.12, .035, .025), iron, .003)
        for x in (-.49, .49): cube('Corner', (x, -.355, -.01), (.04, .03, .7), cedar[3], .003)
    make('counting_desk', desk)

    def worker():
        skin = material('Worker skin', (.40, .25, .13))
        cloth = material('Worker hemp coat', (.15, .18, .19))
        trousers = material('Worker trousers', (.07, .085, .095))
        # Metre-height worker, origin at the original capsule centre (.825 m).
        for x in (-.13, .13):
            cube('Trouser leg', (x, 0, -.48), (.18, .2, .52), trousers, .035)
            cube('Straw sandal', (x, -.045, -.785), (.2, .32, .08), rope, .02)
        bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=.29, radius2=.25, depth=.58, location=(0,0,.055))
        bpy.context.object.data.materials.append(cloth)
        cube('Obi', (0, 0, -.045), (.53, .51, .10), ink, .018)
        for side in (-1, 1):
            bar_between('Sleeve', (side*.22, 0, .27), (side*.33, 0, -.07), .105, cloth)
            bar_between('Forearm', (side*.33, 0, -.07), (side*.32, -.04, -.25), .065, skin)
        cylinder('Neck', (0, 0, .37), .08, .12, skin, 10)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=1, location=(0,0,.55))
        bpy.context.object.scale=(.14,.13,.19)
        bpy.context.object.data.materials.append(skin)
        for x in (-.052,.052): cube('Eye', (x,-.124,.58), (.022,.012,.018), dark, .003)
        cube('Nose', (0,-.132,.54), (.035,.035,.045), skin, .006)
        bpy.ops.mesh.primitive_cone_add(vertices=20, radius1=.31, radius2=.035, depth=.14, location=(0,0,.755))
        bpy.context.object.data.materials.append(rope)
        for side in (-1, 1): bar_between('Collar', (side*.09,-.245,.30), (-side*.06,-.25,.08), .026, paper)
    make('port_worker', worker)
    # Blender +Y exports to Godot -Z, matching civilian sight direction.
    bpy.data.objects['port_worker'].data.transform(Matrix.Rotation(math.pi, 4, 'Z'))

    export(args.output)
    args.output.with_suffix('.json').write_text(json.dumps({
        'generator': 'tools/art/build_port_modules.py', 'blender_version': bpy.app.version_string,
        'units': 'metres', 'source': 'Project-authored original geometry and materials',
        'license': 'Project license', 'external_assets': [], 'modules': names,
    }, indent=2)+'\n')
    if args.preview_dir:
        args.preview_dir.mkdir(parents=True, exist_ok=True)
        for obj in bpy.data.objects:
            obj.hide_render = obj.name not in ('cargo_ship_hull', 'cargo_ship_rig')
        scene = bpy.context.scene
        scene.render.engine = 'CYCLES'
        scene.cycles.samples = 32
        scene.render.resolution_x = 1000
        scene.render.resolution_y = 800
        scene.render.resolution_percentage = 100
        scene.world = bpy.data.worlds.new('Review dusk')
        scene.world.use_nodes = True
        scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.12, .16, .22, 1)
        scene.world.node_tree.nodes['Background'].inputs[1].default_value = .7
        bpy.ops.object.light_add(type='AREA', location=(3, -8, 17))
        bpy.context.object.data.energy = 2200
        bpy.context.object.data.shape = 'DISK'
        bpy.context.object.data.size = 12
        bpy.ops.object.camera_add(location=(19, -25, 17))
        camera = bpy.context.object
        camera.rotation_euler = (Vector((0, 0, 3))-camera.location).to_track_quat('-Z', 'Y').to_euler()
        camera.data.type = 'ORTHO'
        camera.data.ortho_scale = 26
        scene.camera = camera
        scene.render.filepath = str(args.preview_dir/'ship.png')
        bpy.ops.render.render(write_still=True)


if __name__ == '__main__':
    main()
