# Poly Haven — fabric_pattern_07

- Original asset: https://polyhaven.com/a/fabric_pattern_07
- Asset creator/publisher: Poly Haven.
- Asset license: **CC0 1.0 Universal** — https://creativecommons.org/publicdomain/zero/1.0/
- Publisher's license statement: https://polyhaven.com/license (checked 2026-09-27).
- Download mirror: official `godotengine/godot-demo-projects`, pinned to a commit.
  Exact URLs and SHA-256 hashes are in `manifest.json`.

These are asset texture files, **not** Poly Haven's website graphics, logo or preview renders.
CC0 permits commercial use, modification and redistribution. Attribution is not required;
we retain it for provenance. This covers only these three maps, not every file in the project.

## Changes made in this project

`build_urban_assets.py` resizes the maps to 512px and desaturates/tints the albedo
into a slate-colored sleeve material. Normal and ARM maps are used on the FPS sleeves.
`build_urban_enemy.py` tints/resizes the albedo into the contractor's cloth atlas tile.
The contractor's remaining atlas tiles are the project's existing authored assets.
The asphalt, concrete and plaster textures are new deterministic authored textures,
not downloaded scans. All new geometry is authored by the project's Blender scripts.

The original JPEGs remain here for reproducibility and licensing verification.
No assets from Call of Duty or other commercial games are included.
