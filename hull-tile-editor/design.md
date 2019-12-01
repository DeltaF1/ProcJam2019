# Tab/slot design doc
## Editor TODO

- add drag'n'drop for adding a sprite
- add grid overlay/editing mode to define custom shape

## System design

tabs/slots

Jigsaw : {
  image : Image,
  shape : TileGrid, -- default 1x1
  slots : { Direction : { Slot } },
  tabs: { Direction : { Tab } },
}

Slot, Tab : {
  direction : Direction,
  pos: Vector, -- In terms of image/tile pixel coordinates. Positions the image based on this position,
               -- but also centers the tile shape (pos // TILE_WIDTH):floor() gives "origin" tile coordinate
  type: string,
}

Direction: "N"|"S"|"E"|"W"

Slot : {
  tabTypes : { string }
}

## Generation psueocode

first fill all of the existing tiles with randomly chosen 1x1 seed Jigsaws

for tile in tiles do
  if empty neighbour then
    if tile.slots[direction] then
      choose random piece with corresponding slots in that direction
      
      if the shape fits in the grid then
        add to the tile grid (thereby blocking further slots to that space)
        seal the tab/slots on both pieces