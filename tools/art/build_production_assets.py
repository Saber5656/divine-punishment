"""Original clothing and modular architecture; run with Blender 5.2 LTS.

blender --background --factory-startup --python-exit-code 1 --python \
  tools/art/build_production_assets.py -- --base-kit EXTRACTED_BASE_STANDARD \
  --animation-kit EXTRACTED_ANIMATION_STANDARD --output assets
"""
import argparse
import json
import math
from pathlib import Path
import shutil
import sys
import tempfile

import bpy
from mathutils import Vector


def material(name, color, roughness=.8, metal=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = metal
    return mat


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def cube(name, loc, size, mat, bevel=.015):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new('Soft carved edge', 'BEVEL')
        mod.width = bevel
        mod.segments = 2
        bpy.ops.object.modifier_apply(modifier=mod.name)
        obj.modifiers.new('Weighted corners', 'WEIGHTED_NORMAL')
    return obj


def cylinder(name, loc, radius, depth, mat, vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def bone_bind(obj, armature, name):
    """Bind additions with identity rest transform; preserve a single common rig."""
    group = obj.vertex_groups.new(name=name)
    group.add(list(range(len(obj.data.vertices))), 1, 'REPLACE')
    modifier = obj.modifiers.new('Humanoid deformation', 'ARMATURE')
    modifier.object = armature
    obj.parent = armature


def export(path):
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB',
                             export_animations=False, export_cameras=False,
                             export_lights=False, export_extras=False)


def import_base(source):
    # Upstream Standard has two normal-map filenames with an extra `_png` suffix.
    # Resolve only these known missing references, leaving the original zip intact.
    data = json.loads(source.read_text())
    for image in data.get('images', []):
        uri = image.get('uri', '')
        if uri and not (source.parent / uri).exists():
            fixed = uri.replace('_png.png', '.png')
            if not (source.parent / fixed).is_file():
                raise FileNotFoundError(uri)
            image['uri'] = fixed
    # Import from a temporary sibling so relative texture and buffer URIs work.
    with tempfile.NamedTemporaryFile(mode='w', suffix='.gltf', dir=source.parent) as stream:
        json.dump(data, stream)
        stream.flush()
        bpy.ops.import_scene.gltf(filepath=stream.name)
    for obj in list(bpy.data.objects):
        if obj.name == 'Icosphere':
            bpy.data.objects.remove(obj, do_unlink=True)
    return next(o for o in bpy.data.objects if o.type == 'ARMATURE')


def garment_shell(body, arm, mat, role):
    from mathutils.kdtree import KDTree
    tree = KDTree(len(body.data.vertices))
    for vertex in body.data.vertices:
        tree.insert(vertex.co, vertex.index)
    tree.balance()
    vertices, faces = [], []
    def rings(sections, axis='z', center=0, count=16):
        offset = len(vertices)
        for along, radius_a, radius_b in sections:
            for index in range(count):
                angle = 2 * math.pi * index / count
                a, b = math.cos(angle)*radius_a, math.sin(angle)*radius_b
                vertices.append((center+a,b,along) if axis=='z' else (along,b,1.43+a))
        for row in range(len(sections)-1):
            for index in range(count):
                j=offset+row*count+index;k=offset+row*count+(index+1)%count
                faces.append((j,k,k+count,j+count))
        faces.append(tuple(offset+i for i in reversed(range(count))))
        faces.append(tuple(offset+(len(sections)-1)*count+i for i in range(count)))
    rings([(.91,.185,.145),(1.02,.18,.14),(1.21,.245,.16),(1.40,.265,.16),(1.49,.105,.105)])
    for side in (-1,1):
        rings([(side*.18,.13,.145),(side*.35,.14,.15),(side*.52,.13,.14),(side*.69,.095,.10)],axis='x')
        width=.135 if role=='shinobi' else .17
        rings([(.11,.065,.075),(.23,.08,.09),(.47,width,.13),(.68,width,.145),(.91,width,.15),(1.0,.11,.13)],center=side*.12)
    mesh=bpy.data.meshes.new(role+'_tailored_cloth')
    mesh.from_pydata(vertices,[],faces);mesh.update()
    import bmesh
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    garment=bpy.data.objects.new(role+'_garment',mesh)
    bpy.context.collection.objects.link(garment)
    garment.data.materials.append(mat)
    for polygon in garment.data.polygons: polygon.use_smooth=True
    groups={g.index:garment.vertex_groups.new(name=g.name) for g in body.vertex_groups}
    for vertex in garment.data.vertices:
        # Blend nearby source weights instead of hard seams at elbows and knees.
        nearest=tree.find_n(vertex.co,3)
        weights={};total=sum(1/max(distance,.001) for _,_,distance in nearest)
        for _,index,distance in nearest:
            factor=1/max(distance,.001)/total
            for group in body.data.vertices[index].groups:
                weights[group.group]=weights.get(group.group,0)+group.weight*factor
        for index,weight in weights.items():groups[index].add([vertex.index],weight,'REPLACE')
    modifier=garment.modifiers.new('Humanoid deformation','ARMATURE');modifier.object=arm;garment.parent=arm
    # Remove fully occluded body surfaces, preventing skin intersections in motion.
    import bmesh
    bm=bmesh.new();bm.from_mesh(body.data)
    covered=[face for face in bm.faces if all(vertex.co.z<1.49 and abs(vertex.co.x)<.69 for vertex in face.verts)]
    bmesh.ops.delete(bm,geom=covered,context='FACES');bm.to_mesh(body.data);bm.free()
    return garment


def character(role, source, out):
    reset()
    arm = import_base(source)
    body = next(o for o in bpy.data.objects if o.type == 'MESH' and 'SuperHero' in o.name)
    palettes = {'shinobi': ((.018, .033, .060), (.25, .055, .038)),
                'ashigaru': ((.085, .105, .075), (.24, .085, .035)),
                'magistrate': ((.18, .055, .044), (.56, .41, .17))}
    cloth_color, tie_color = palettes[role]
    cloth = material(role + '_indigo_or_earth_cloth', cloth_color)
    tie = material(role + '_woven_sash', tie_color)
    dark = material('Blackened iron and hair', (.013, .016, .019), .6)
    straw = material('Weathered straw', (.34, .245, .12))
    for obj in bpy.data.objects:
        if obj.type=='MESH' and obj.name.startswith('Eyebrows'):
            obj.data.materials.clear();obj.data.materials.append(dark)
            for polygon in obj.data.polygons:polygon.material_index=0
    garment_shell(body, arm, cloth, role)
    sash = cube('garment_obi', (0, -.005, 1.00), (.39, .31, .095), tie, .02)
    bone_bind(sash, arm, 'pelvis')
    # Lapel ribbons sit on the chest with distinctive wrap direction.
    for sign in (-1, 1):
        lapel = cube('garment_crossed_lapel', (sign * .063, -.167, 1.35), (.042, .025, .25), tie, .007)
        lapel.rotation_euler.y = sign * .45
        bone_bind(lapel, arm, 'spine_03')
    for sign, side in ((1, 'l'), (-1, 'r')):
        boot = cube('garment_tabi_' + side, (sign * .114, -.015, .08), (.145, .30, .16), dark, .025)
        bone_bind(boot, arm, 'foot_' + side)
    if role == 'shinobi':
        vertices,faces=[],[]
        for z,radius in [(1.575,.09),(1.70,.132),(1.755,.122),(1.80,.091),(1.835,.018)]:
            for i in range(24):
                angle=2*math.pi*i/24
                vertices.append((math.cos(angle)*radius,.015+math.sin(angle)*radius*1.4,z))
        for row in range(4):
            for i in range(24):
                # An open eye band faces local -Y.
                if row==1 and 14<=i<=21:continue
                j=row*24+i;k=row*24+(i+1)%24
                faces.append((j,k,k+24,j+24))
        mesh=bpy.data.meshes.new('Tailored hood');mesh.from_pydata(vertices,[],faces);mesh.update()
        hood=bpy.data.objects.new('garment_hood',mesh);bpy.context.collection.objects.link(hood);mesh.materials.append(cloth)
        bone_bind(hood,arm,'Head')
    elif role == 'ashigaru':
        bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=.30, radius2=.065, depth=.13, location=(0,.015,1.875))
        hat = bpy.context.object; hat.name = 'garment_jingasa';hat.data.materials.append(straw)
        bone_bind(hat, arm, 'Head')
        for z in (1.12, 1.20, 1.28, 1.36):
            plate = cube('garment_lamellar', (0, -.15, z), (.33,.035,.065), dark,.008)
            bone_bind(plate, arm, 'spine_03')
    else:
        hair = cylinder('garment_topknot', (0,.07,1.80), .055,.12,dark,12)
        hair.rotation_euler.x = math.pi/2
        bone_bind(hair,arm,'Head')
        for sign in (-1,1):
            panel = cube('garment_kataginu', (sign*.22,.025,1.44),(.20,.22,.065),cloth,.008)
            panel.rotation_euler.y=sign*.22
            bone_bind(panel,arm,'spine_03')
    arm.name = 'Humanoid'
    export(out/'characters'/f'{role}.glb')


def architecture(out):
    reset()
    wood = material('Ink stained cedar', (.048,.029,.023))
    edge = material('Worn cedar grain', (.13,.082,.045))
    plaster = material('Warm lime plaster', (.62,.57,.44))
    paper = material('Washi', (.78,.69,.49))
    tile = material('Indigo ceramic tile', (.045,.067,.09),.65)
    stone = material('Weathered foundation stone', (.22,.235,.23))
    metal = material('Black iron', (.014,.018,.021),.5,.55)
    modules=[]
    def module(name, build):
        before=set(bpy.data.objects)
        build()
        parts=[o for o in bpy.data.objects if o not in before and o.type=='MESH']
        bpy.ops.object.select_all(action='DESELECT')
        for p in parts:p.select_set(True)
        bpy.context.view_layer.objects.active=parts[0]
        bpy.ops.object.join()
        obj=bpy.context.object;obj.name=name
        bpy.context.scene.cursor.location=(0,0,0)
        bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
        modules.append(obj)
    def floor():
        for i in range(8):cube('plank',(-.875+i*.25,0,.08),(.242,2,.16),edge,.008)
        for y in (-.86,.86):cube('joist',(0,y,-.06),(2,.14,.14),wood)
    module('floor_2m',floor)
    module('post_2p8m',lambda:cube('post',(0,0,1.4),(.19,.19,2.8),wood))
    module('beam_2m',lambda:cube('beam',(0,0,0),(2,.18,.22),wood))
    def frame(infill, lattice=False):
        cube('infill',(0,.015,1.3),(1.85,.04,2.5),infill,.003)
        for x in (-.96,.96):cube('stile',(x,0,1.3),(.08,.12,2.6),wood,.008)
        for z in (.04,2.56):cube('rail',(0,0,z),(2,.12,.08),wood,.008)
        if lattice:
            for x in (-.64,-.32,0,.32,.64):cube('kumiko',(x,-.035,1.3),(.023,.025,2.48),edge,.002)
            for z in (.36,.68,1.,1.32,1.64,1.96,2.28):cube('kumiko',(0,-.039,z),(1.86,.025,.023),edge,.002)
    module('shoji_2m',lambda:frame(paper,True))
    module('plaster_2m',lambda:frame(plaster))
    def engawa():
        for y in range(5):cube('deck',(0,-.4+y*.2,.08),(2,.19,.16),edge,.008)
        for x in (-.85,.85):cube('support',(x,0,-.16),(.13,.85,.3),wood)
    module('engawa_2m',engawa)
    def roof():
        # Tile strips follow a gently curved eave in local Y, all one mesh/module.
        for row in range(8):
            y=-.875+row*.25;z=.11+.25*((y+1)/2)**2
            for col in range(8):
                x=-.875+col*.25
                obj=cube('ceramic',(x,y,z),(.242,.30,.052),tile,.012)
                obj.rotation_euler.x=.24*((y+1)/2)
                crest=cylinder('round tile seam',(x+.105,y,z+.024),.036,.295,tile,10)
                crest.rotation_euler.x=math.pi/2+.24*((y+1)/2)
        cube('eave',(0,-1.02,.04),(2.1,.12,.13),wood)
    module('roof_2m',roof)
    def ridge():
        cap=cylinder('ridge',(0,0,.08),.11,2,tile,12);cap.rotation_euler.y=math.pi/2
    module('ridge_2m',ridge)
    def gate():
        for x in (-1.9,1.9):cube('gatepost',(x,0,1.4),(.26,.3,2.8),wood)
        cube('lintel',(0,0,2.55),(4.3,.32,.3),wood)
        for x in (-.91,.91):
            cube('gateleaf',(x,0,1.15),(1.77,.13,2.2),edge)
            for z in (.40,1.85):cube('ironband',(x,-.075,z),(1.72,.022,.055),metal,.002)
    module('gate_4m',gate)
    def fence():
        for x in (-.95,.95):cube('fencepost',(x,0,.65),(.1,.1,1.3),wood)
        for z in (.25,1.05):cube('rail',(0,0,z),(2,.08,.07),wood)
        for i in range(11):cube('slat',(-.9+i*.18,-.015,.64),(.045,.055,1.05),edge,.004)
    module('fence_2m',fence)
    def lantern():
        cube('paperbox',(0,0,.45),(.32,.32,.46),paper)
        for x in (-.17,.17):
            for y in (-.17,.17):cube('corner',(x,y,.45),(.035,.035,.50),wood,.004)
        for z in (.2,.7):cube('rim',(0,0,z),(.39,.39,.055),wood,.008)
        cube('base',(0,0,.09),(.26,.26,.18),stone)
        cube('cap',(0,0,.76),(.45,.45,.06),tile)
    module('lantern',lantern)
    module('stone_step',lambda:cube('stone',(0,0,.12),(1.4,.55,.24),stone,.045))
    export(out/'environment'/'residence_modules.glb')
    return [o.name for o in modules]


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--base-kit',type=Path,required=True)
    parser.add_argument('--animation-kit',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    source=next(args.base_kit.rglob('Superhero_Male_FullBody.gltf'))
    for role in ('shinobi','ashigaru','magistrate'):character(role,source,args.output)
    modules=architecture(args.output)
    animation=next(args.animation_kit.rglob('UAL1_Standard.glb'))
    (args.output/'animations').mkdir(parents=True,exist_ok=True)
    shutil.copyfile(animation,args.output/'animations'/'quaternius_standard.glb')
    shutil.copyfile(next(args.animation_kit.rglob('License.txt')),args.output/'animations'/'QUATERNIUS-LICENSE.txt')
    shutil.copyfile(next(args.base_kit.rglob('License_Standard.txt')),args.output/'characters'/'QUATERNIUS-LICENSE.txt')
    manifest={'generator':'tools/art/build_production_assets.py','blender_version':bpy.app.version_string,
              'units':'metres','character_origin':'feet; model adapter applies capsule-centre offset',
              'character_forward':'+Z in glTF; rotate visual model by PI around Y to match gameplay -Z',
              'modules':modules,'upstream':[
        {'name':'Quaternius Universal Base Characters Standard','license':'CC0-1.0',
         'source':'https://quaternius.itch.io/universal-base-characters',
         'archive_sha256':'fdbf1804c90dfc1ea03e992bff7da2dfd1a79318e13270a660180f9308455f40'},
        {'name':'Quaternius Universal Animation Library Standard','license':'CC0-1.0',
         'source':'https://quaternius.itch.io/universal-animation-library',
         'archive_sha256':'cc73fc4e495b82958207316596317a3f40b9fa38065bde1027937452da537724'}]}
    (args.output/'production-assets.json').write_text(json.dumps(manifest,indent=2)+'\n')

if __name__=='__main__':main()
