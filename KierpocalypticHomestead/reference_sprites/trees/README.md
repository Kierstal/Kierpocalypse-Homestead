# Tree / vegetation sprite atlases

Source PNGs from the PZ Modding Tools (`Tiles/` folder of the Modding Tools install).
These are the canonical 1x atlases the game's tree texture packs are built from.
Drop them into your image editor (Aseprite, Krita, Photoshop, GIMP, anything that
handles transparency) to overlay fruit on the canopies.

## Files

- **vegetation_trees_01.png** (512x1024) — the main tree atlas (oaks, maples,
  pines, etc.). Trees occupy multiple cells each because they're tall. PZ
  references individual sprites as `vegetation_trees_01_<index>` where index
  counts left-to-right, top-to-bottom starting from 0.

- **vegetation_foliage_01.png** (512x1024) — bushes, undergrowth, smaller
  shrubs. Useful if you want a "small fruit bush" look (think raspberry,
  blueberry).

- **vegetation_groundcover_01.png** (512x1024) — grass tufts, low ground
  vegetation. Probably not relevant for fruit trees but included for
  completeness.

## Cell size and indexing

PZ B42 tile cells are typically **64 wide x 128 tall** for normal tiles,
but tree atlases use tall sprites that occupy 2 vertical cells (so 64x256
effectively per tree). Check PZ's tile definition files
(`media/newtiledefinitions.tiles.txt` in the game install) for exact
sprite-name-to-coordinate mappings if you need pixel-perfect edits.

## Workflow for fruit-tree variants

1. Find a base tree sprite you like (e.g. an oak in `vegetation_trees_01_15`)
2. Copy that sprite cell to a new file at the same dimensions
3. Add fruit overlays in the canopy
4. Save as e.g. `kh_fruit_tree_apple_fruited.png` and the fruitless version
   as `kh_fruit_tree_apple_growing.png`
5. Drop into the mod's actual texture folder when you're done — I'll handle
   wiring them into the orchard system at that point

## When ready to wire it up

Tell me which tree variants you've drawn (apple, peach, cherry, etc.) and the
filenames, and I'll plug them into the orchard task (#15) implementation.
