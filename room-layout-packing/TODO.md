# Structure

generate.lua creates a ship object. Ship has geometry, sub-geometry of rooms, and doors (adjmatrix?).
Ship should have a draw method to draw itself

gen_layout(room)
-> generates a room layout based on the room's type without blocking exits

fitness function
-> reachability of all props
-> doors have to be routable
-> things that are supposed to be next to each other in the grammar are close in 2D space

```
fitness(genome):
  for x,y,r,propType in genome:
    try to add to propgeometry:
      if it collides:
        increment score of collisions
        propgeometry:get(x,y)++
      else:
        propgeometry:set(x,y, 0)
      
      if it's out of bounds:
        set propgeometry to 100
      
      sum of tile values subtract from score
      
  test door-door connectivity:
    from each door pathfind to another door.
    get as close as possible and record closest pos.
    subtract len of pos to score

  fitness score based on adherence to grammar??????
  
  fitness score based on min/max of each propType per roomType

loop:
  population:breed(fitness)
  
  if not overlapping
```

# Features
- [x] Generate objects
  - [x] Crates
  - [x] Consoles
  - Chairs
- People walking around
- [x] Draw the walls on the outside instead so that rooms tiles are easier
  - [x] Need to invert the tile algorithm
- [ ] Suggestion from H: greenhouses!

- Salvaging from wrecks
  - Attach to your ship and tow them?
  
  - Go for EVA's and explore randomly generated wrecks
  
  - First episode of firefly
  
- Inspiration games
  - Captain forever
  - Duskers
  - Starsector
  - Heat signature

# Bugfixes
