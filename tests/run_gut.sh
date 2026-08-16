#!/bin/sh
# Run GUT suite. On this macOS host `godot --headless` crashes in MoltenVK before scripts run,
# so the reliable path is Editor → GutScene → Run. This script is for Linux CI where headless works.
set -e
if [ -x /opt/homebrew/bin/godot ]; then
  GODOT=/opt/homebrew/bin/godot
else
  GODOT=godot
fi
# Linux CI invocation (works on barichello/godot-ci:4.7.1):
# $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
# Local editor fallback: open Godot and run addons/gut/GutScene.tscn
echo "To run locally: open Godot 4.7.1 → run addons/gut/GutScene.tscn → Run"
echo "On Linux CI: $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit"
