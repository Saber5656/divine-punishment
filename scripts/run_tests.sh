#!/usr/bin/env bash
set -euo pipefail

"${GODOT_BIN:-godot}" --headless --path . --import
"${GODOT_BIN:-godot}" --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json
