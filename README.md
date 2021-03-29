# ProcJam2019

A collection of experiments in procedural design for ProcJam 2019. Click each heading to go to the code

## [Spaceship layout generation](room-layout-packing)
![screenshot](room-layout-packing/readme_screenie.png)
I created a series of algorithms to pack rectangles together into interesting shapes.
![initial algorithm](spaceship_random.gif)

I then started grouping rectangles (rooms) together by their function, and adding doors between them
![doors](spaceship_doors.gif)

The next step involved creating a tileset system and corresponding tileset test-bed to find missing tiles. The tilesets were quickly split into 3 sets of tiles to fluidly mark room boundaries.
To complement the new interior aesthetic, ornamental "greebles" such as antennae and lights were added to the outside perimeter of the spaceships.

![tileset](tileset_editor.gif)
![greebles](greeblies.gif)

Finally, I added props to the insides of the rooms. Pieces of furniture such as crates or beds are chosen based on the room's purpose.


## [Cellular Automata](cellular)
_Implementation of conway's game of life_
![gameoflife](gameoflife.gif)

_A smoothing Cellular Automata to turn noise into cave-like structures_
![cave generation](cave_gen.gif)

## [Force-based layout](room-layout-spring-sim)
_An early attempt to generate spaceship layouts by using springs and force simulations_
![spring layout](spring_fixed.gif)
