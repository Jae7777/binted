Godot repository rules (`/src`):
- Never touch Godot-generated files (`*.tsnc`, `*.godot`, `.import`, `*.uid`, etc.) as doing so will cause drift and corrupt the files in the long run.
- Only ever touch script files (`*.gdscript`)