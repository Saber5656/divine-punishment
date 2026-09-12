"""Original rainy mountain-temple kit. Run in Blender 5.2 LTS; no downloads."""
import argparse
import json
import math
from pathlib import Path
import random
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_production_assets import reset, material, cube, cylinder, export
from build_residence_decor import module
from build_port_modules import bar_between, polygon_mesh


def lathe(name, profile, mat, count=24):
    vertices = [(r*math.cos(i*math.tau/count), r*math.sin(i*math.tau/count), z)
                for z, r in profile for i in range(count)]
    faces = [(j*count+i, j*count+(i+1)%count, (j+1)*count+(i+1)%count, (j+1)*count+i)
             for j in range(len(profile)-1) for i in range(count)]
    return polygon_mesh(name, vertices, faces, mat)


def torus(name, location, radius, tube, mat, segments=24):
    bpy.ops.mesh.primitive_torus_add(major_radius=radius, minor_radius=tube,
                                   major_segments=segments, minor_segments=6,
                                   location=location)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    reset()
    rng = random.Random(63)
    stone = [material('Rain-dark granite %d' % i, (.14+i*.012, .17+i*.012, .17+i*.01), .42)
             for i in range(4)]
    mortar = material('Stone joints', (.035, .047, .045), .7)
    moss = material('Moss in the joints', (.07, .12, .065), .85)
    cedar = [material('Wet cedar %d' % i, (.10+i*.011, .057+i*.006, .026+i*.004), .5)
             for i in range(4)]
    dark = material('Charred timber', (.025, .029, .025), .6)
    plaster = material('Aged temple plaster', (.38, .37, .30), .8)
    tile = material('Wet blue-black tile', (.047, .073, .083), .28, .2)
    bronze = material('Patinated bell bronze', (.18, .20, .11), .35, .75)
    iron = material('Forged iron', (.055, .065, .065), .3, .8)
    straw = material('Oiled umbrella paper', (.30, .24, .12), .7)
    paper = material('Warm lantern paper', (.75, .62, .38), .8)
    paper.node_tree.nodes['Principled BSDF'].inputs['Emission Color'].default_value = (.8, .4, .12, 1)
    paper.node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value = .6
    ember = material('Brazier embers', (.55, .11, .018), .65)
    ember.node_tree.nodes['Principled BSDF'].inputs['Emission Color'].default_value = (1, .15, .018, 1)
    ember.node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value = 1.2
    names = []

    def make(name, build):
        module(name, build)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        names.append(name)

    def paving():
        cube('Dark joints', (0, 0, -.07), (2, 2, .12), mortar, 0)
        for row in range(4):
            for col in range(4):
                cube('Worn paving slab', (-.75+col*.5, -.75+row*.5, -.04),
                     (.488, .488, .08), stone[(row+col)%4], .012)
        for x, y in [(-.5, -.2), (.5, .6), (.12, .5)]:
            cube('Moss seam', (x, y, .001), (.018, .18, .002), moss, 0)
    make('wet_paving_2m', paving)

    def stone_wall():
        cube('Mortar backing', (0, .04, 1), (2, .24, 2), mortar, 0)
        for row in range(5):
            for col in range(4):
                cube('Rough retaining block', (-.75+col*.5, -.095, .2+row*.4),
                     (.49, .11+rng.random()*.015, .388), stone[(row+col)%4], .025)
        for x in (-.49, .51): cube('Moss run', (x, -.16, 1.2), (.018, .005, 1.2), moss, 0)
    make('stone_wall_2m', stone_wall)

    def tread():
        cube('Rounded stair nosing', (0, 0, -.075), (2, .9, .15), stone[2], .025)
        for x in (-.5, 0, .5): cube('Tread joint', (x, 0, .001), (.007, .86, .002), mortar, 0)
    make('stone_tread_2m', tread)

    def cedar_wall():
        cube('Lime wash', (0, 0, 1.8), (2, .18, 3.6), plaster, .006)
        for x in (-.94, .94): cube('Frame upright', (x, -.07, 1.8), (.12, .18, 3.6), cedar[0])
        for z in (.12, 1.25, 3.48): cube('Horizontal beam', (0, -.08, z), (2, .2, .16), dark)
        for i in range(10): cube('Lower cedar board', (-.9+i*.2, -.13, .62), (.19, .06, 1.02), cedar[i%4], .006)
    make('cedar_wall_2m', cedar_wall)

    def post():
        cube('Post', (0, 0, 1.8), (.3, .3, 3.6), cedar[1], .02)
        cube('Stone shoe', (0, 0, .12), (.38, .38, .24), stone[2], .02)
        for x in (-.08, .04): cube('Cedar grain', (x, -.151, 1.7), (.012, .004, 2.7), cedar[3], 0)
        for z in (.35, 3.2): cube('Iron strap', (0, 0, z), (.31, .31, .055), iron, .003)
    make('temple_post', post)

    def beam():
        cube('Lintel', (0, 0, 0), (2, .28, .25), cedar[1], .018)
        for z in (-.06, .05): cube('Long grain', (0, -.141, z), (1.8, .005, .012), cedar[3], 0)
    make('temple_beam_2m', beam)

    def roof():
        cube('Roof backing', (0, 0, -.05), (2, 2, .09), dark, 0)
        for row in range(4):
            for col in range(4):
                cube('Overlapping tile', (-.75+col*.5, -.75+row*.5, -.008), (.492, .51, .04), tile, .009)
            for col in range(5):
                part = cylinder('Rounded seam', (-1+col*.5, -.75+row*.5, .015), .036, .5, tile, 8)
                part.rotation_euler.x = math.pi/2
    make('temple_roof_2m', roof)

    def eave():
        cube('Eave fascia', (0, 0, 0), (2, .18, .2), cedar[1], .015)
        for x in (-.8, -.4, 0, .4, .8):
            cube('Rafter end', (x, -.08, -.08), (.10, .45, .12), dark, .01)
            cube('Carved bracket', (x, .05, -.21), (.20, .18, .13), cedar[2], .02)
        for x in (-.75, -.25, .25, .75):
            part = cylinder('Tile end cap', (x, -.1, .10), .075, .08, tile, 12)
            part.rotation_euler.x = math.pi/2
    make('eave_trim_2m', eave)

    def bell():
        lathe('Hollow bell', [(-.6,.62),(-.55,.65),(-.48,.59),(.05,.50),(.29,.37),(.40,.20),(.44,.075),
                             (.39,.075),(.35,.18),(.24,.32),(.02,.45),(-.48,.54),(-.60,.57),(-.60,.62)], bronze, 32)
        for z in (-.48, -.27, .14): torus('Bell band', (0,0,z), .59 if z < -.4 else (.55 if z < 0 else .45), .018, bronze)
        for z in (-.08, .04):
            for i in range(12):
                angle = i*math.tau/12
                bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=.04, location=(.505*math.cos(angle),.505*math.sin(angle),z))
                bpy.context.object.data.materials.append(bronze)
        loop = torus('Suspension loop', (0,0,.53), .13, .035, bronze)
        loop.rotation_euler.x = math.pi/2
        bar_between('Wooden striker', (-.9,-.78,-.15),(.9,-.78,-.15),.11,cedar[2])
    make('bronze_bell', bell)

    def grave():
        cube('Stone footing', (0,0,.12), (.74,.4,.24), stone[1], .035)
        cube('Stele', (0,0,.73), (.47,.26,1), stone[2], .035)
        cylinder('Crown', (0,0,1.25), .27, .12, stone[2], 4).rotation_euler.z = math.pi/4
        for z in (.48,.65,.82,.99): cube('Incised mark', (0,-.133,z), (.045,.005,.095), mortar, .002)
        cube('Moss base', (0,-.19,.24), (.45,.018,.012), moss, .003)
    make('grave_stone', grave)

    def lantern():
        cube('Paper shade', (0,0,0), (.44,.44,.62), paper, .02)
        for x in (-.24,.24):
            for y in (-.24,.24): cube('Lantern frame', (x,y,0), (.035,.035,.74), dark, .004)
        for z in (-.37,.37): cube('Lantern lid', (0,0,z), (.57,.57,.065), cedar[0], .01)
        for z in (-.14,.14):
            for y in (-.23,.23): cube('Paper rib', (0,y,z), (.44,.018,.018), cedar[2], .002)
        torus('Hanging ring', (0,0,.45), .08,.012,iron,16).rotation_euler.x = math.pi/2
    make('temple_lantern', lantern)

    def brazier():
        lathe('Fire basket', [(-.4,.25),(-.18,.4),(-.10,.4),(-.16,.34),(-.34,.20)],iron,16)
        for i in range(3):
            angle=i*math.tau/3
            bar_between('Tripod leg',(.19*math.cos(angle),.19*math.sin(angle),-.35),(.4*math.cos(angle),.4*math.sin(angle),-1.6),.045,iron)
        for i in range(7):
            angle=i*math.tau/7
            cube('Glowing coal',(.2*math.cos(angle),.2*math.sin(angle),-.13),(.11,.12,.10),ember,.022)
    make('temple_brazier', brazier)

    def retainer():
        cloth=material('Retainer worn indigo',(.12,.16,.20),.9)
        skin=material('Retainer skin',(.42,.27,.17),.85)
        sash=material('Retainer sash',(.25,.23,.17),.85)
        for x in (-.12,.12):
            cube('Trouser leg',(x,0,-.48),(.18,.21,.52),cloth,.035)
            cube('Sandal',(x,-.055,-.785),(.19,.31,.08),straw,.018)
        lathe('Kimono', [(-.25,.28),(.14,.26),(.33,.19)],cloth,12)
        cube('Sash',(0,-.01,-.12),(.53,.5,.11),sash,.012)
        for side in (-1,1):
            bar_between('Sleeve',(side*.20,0,.26),(side*.33,0,-.05),.10,cloth)
            bar_between('Forearm',(side*.33,0,-.05),(side*.32,-.04,-.27),.062,skin)
            bar_between('Collar',(side*.09,-.23,.28),(-side*.05,-.26,.06),.025,sash)
        cylinder('Neck',(0,0,.37),.08,.12,skin,10)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,radius=1,location=(0,0,.55))
        bpy.context.object.scale=(.14,.13,.19); bpy.context.object.data.materials.append(skin)
        for x in (-.05,.05): cube('Eye',(x,-.125,.59),(.018,.012,.014),dark,.002)
        cube('Nose',(0,-.137,.54),(.032,.034,.04),skin,.005)
        cylinder('Tied hair',(0,.04,.73),.064,.065,dark,10)
    make('temple_retainer',retainer)
    bpy.data.objects['temple_retainer'].data.transform(Matrix.Rotation(math.pi,4,'Z'))

    def umbrella():
        bar_between('Umbrella shaft',(0,0,-.25),(0,0,1.43),.022,cedar[2])
        lathe('Oiled paper canopy',[(1.1,.78),(1.30,.42),(1.40,.05),(1.42,0)],straw,24)
        for i in range(12):
            a=i*math.tau/12
            bar_between('Umbrella rib',(0,0,1.38),(.76*math.cos(a),.76*math.sin(a),1.09),.009,cedar[2])
        cylinder('Canopy tip',(0,0,1.45),.025,.12,dark,10)
    make('monk_umbrella',umbrella)

    def weapon():
        cylinder('Naginata haft',(0,0,.55),.026,2.0,cedar[0],12)
        cylinder('Iron ferrule',(0,0,1.53),.039,.13,iron,12)
        profile=[(0,1.55),(.10,1.67),(.16,1.93),(.07,2.13),(.025,1.9),(-.04,1.62)]
        verts=[(x,y,z) for y in (-.018,.018) for x,z in profile]
        faces=[tuple(range(5,-1,-1)),tuple(range(6,12))]
        faces += [(i,(i+1)%6,(i+1)%6+6,i+6) for i in range(6)]
        polygon_mesh('Curved blade',verts,faces,iron)
    make('naginata',weapon)

    def rock():
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1)
        obj=bpy.context.object; obj.name='Weathered cliff'; obj.scale=(1,.65,1.3)
        obj.data.materials.append(stone[0]);obj.data.materials.append(moss)
        for face in obj.data.polygons: face.material_index=int(face.normal.z>.6)
    make('boundary_rock',rock)

    def lattice():
        for x in (-.95,.95): cube('Frame',(x,0,1.5),(.10,.2,3),cedar[0])
        for z in (.05,2.95): cube('Rail',(0,0,z),(2,.2,.10),cedar[0])
        for x in (-.7,-.35,0,.35,.7): cube('Cell lattice',(x,0,1.5),(.055,.11,2.9),cedar[2],.006)
    make('cell_lattice_2m',lattice)

    def wheel():
        for z in (-.15,.15): torus('Wheel rim',(0,0,z),1.3,.09,cedar[0],32)
        cylinder('Hub',(0,0,0),.20,.50,cedar[1],16)
        for i in range(12):
            a=i*math.tau/12
            bar_between('Spoke',(0,0,0),(1.25*math.cos(a),1.25*math.sin(a),0),.055,cedar[2])
            paddle=cube('Water paddle',(1.3*math.cos(a),1.3*math.sin(a),0),(.18,.36,.45),cedar[i%4],.012)
            paddle.rotation_euler.z=a
    make('waterwheel',wheel)

    export(args.output)
    args.output.with_suffix('.json').write_text(json.dumps({
        'generator':'tools/art/build_temple_modules.py','blender_version':bpy.app.version_string,
        'units':'metres','source':'Project-authored original geometry and materials',
        'license':'Project license','external_assets':[],'modules':names,
    },indent=2)+'\n')


if __name__ == '__main__':
    main()
