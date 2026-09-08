"""Bake in a minimal external project; requires the pinned Godot editor.

Run prepare_lightmap_scene.gd first, then:
python3 tools/lighting/bake_residence.py --godot GODOT --project OUTPUT_PROJECT
Copy verified assets/lighting/m02 back only after bake success.
"""
import argparse
from pathlib import Path
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    parser.add_argument('--project', type=Path, required=True)
    args = parser.parse_args()
    output = args.project.resolve()
    if not (output / 'assets/lighting/m02/baked_visuals.tscn').is_file():
        parser.error('Prepare the static scene first')
    if (output / 'project.godot').exists():
        parser.error('Use a fresh isolated project; existing settings are preserved')
    plugin = output / 'addons/bake'
    plugin.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(Path(__file__).with_name('bake_plugin.gd'), plugin / 'plugin.gd')
    (plugin / 'plugin.cfg').write_text('[plugin]\nname="Residence Bake"\ndescription="Isolated static light bake"\nauthor="Project"\nversion="1"\nscript="plugin.gd"\n')
    (output / 'project.godot').write_text('''config_version=5
[application]
config/name="Residence Light Bake"
run/main_scene="res://assets/lighting/m02/baked_visuals.tscn"
[display]
window/size/viewport_width=640
window/size/viewport_height=360
[editor_plugins]
enabled=PackedStringArray("res://addons/bake/plugin.cfg")
[rendering]
renderer/rendering_method="forward_plus"
textures/vram_compression/import_etc2_astc=true
''')
    subprocess.run([args.godot, '--editor', '--path', str(output),
                    'res://assets/lighting/m02/baked_visuals.tscn'], check=True)
    if not (output / 'assets/lighting/m02/residence.lmbake').is_file():
        raise RuntimeError('Editor did not produce lightmap data')


if __name__ == '__main__':
    main()
