local Vector = require "vector"
local Geometry = require "geometry"
local TileSet = require "tileset"

function love.load(arg)
  if arg[#arg] == "-debug" then require("mobdebug").start() end
  love.graphics.setDefaultFilter("nearest", "nearest")
  love.window.setMode(1024,1024)
  hullTileset = love.graphics.newImage("tileset.png")
  gridTileset = love.graphics.newImage("room_tileset.png")
  TILE_WIDTH=16
  local tilesetwidth,tilesetheight = hullTileset:getDimensions()
  tileset = TileSet(tilesetwidth, tilesetheight, TILE_WIDTH)
  greebleTilesetImage = love.graphics.newImage("greebles.png")
  
  greebleQuads = {
    love.graphics.newQuad(0,0,16,32,greebleTilesetImage:getDimensions()), --antenna array
    love.graphics.newQuad(16,0,16,16,greebleTilesetImage:getDimensions()), --light box
    -- coloured boxes
    love.graphics.newQuad(16,16,8,8,greebleTilesetImage:getDimensions()),
    love.graphics.newQuad(16,24,8,8,greebleTilesetImage:getDimensions()), 
    love.graphics.newQuad(24,16,8,8,greebleTilesetImage:getDimensions()), 
    love.graphics.newQuad(24,24,8,8,greebleTilesetImage:getDimensions()),
    -- railings
    love.graphics.newQuad(32,17,16,3,greebleTilesetImage:getDimensions()),
    love.graphics.newQuad(32,20,16,3,greebleTilesetImage:getDimensions()),
    love.graphics.newQuad(32,23,16,3,greebleTilesetImage:getDimensions()),
    love.graphics.newQuad(32,26,16,3,greebleTilesetImage:getDimensions()),
    love.graphics.newQuad(32,29,16,3,greebleTilesetImage:getDimensions()),
    
    love.graphics.newQuad(48,0,16,32,greebleTilesetImage:getDimensions()), -- antenna
  }
  
  floorSpriteBatch = love.graphics.newSpriteBatch(hullTileset, 100)
  gridSpriteBatch = love.graphics.newSpriteBatch(gridTileset, 100)
  greebleSpriteBatch = love.graphics.newSpriteBatch(greebleTilesetImage, 100)
  love.keypressed("space")
end

function index2xy(index, width)
  local x = (index-1) % width + 1
  local y = math.floor((index-1)/width) + 1

  return x,y
end

function xy2index(x, y, width)
  if x < 1 or y < 1 or x > width then return -1 end
  return x + width*(y-1)
end

ROOM_PRESELECTED_OFFSET = 3
room_types = {
  -- Special rooms that aren't chosen by the room generator
  {name = "Helm",               wrange={2,2}, hrange={2,2}, colour = {0.8,0.9,0.1,0.85}},
  {name = "Engine",             wrange={2,2}, hrange={2,3}, colour={0.58330589736158589, 0.024793900080875231, 0.83640388831262813,0.85}},
  -----------------------------  ROOM_PRESELECTED_OFFSET
  {name = "Storage Bay",        wrange={3,6}, hrange={3,6}, colour={0.82675021090650347, 0.1807523156814923, 0.25548658234132504,0.85}},
  {name = "Mess Hall",          wrange = {2,3}, hrange={2,3}, colour = {0.3540978676870179, 0.47236376329459961, 0.67900487187065317,0.85}},
  {name = "Sleeping quarters",  wrange = {1,2}, hrange={1,2}, colour = {0.57514179487402095, 0.79693061238668306, 0.45174307459403407,0.85}},
  {name = "Lounge",             wrange = {2,3}, hrange={2,3}, colour = {0.049609465521796903, 0.82957781845624967, 0.62650828993078767,0.85}},
  {name = "Corridor",         wrange={2,10}, hrange={1,2}, colour = {0.3,0.3,0.3,0.85}},
  {name = "Corridor",         wrange={1,2}, hrange={2,10}, colour = {0.3,0.3,0.3,0.85}},
}



local maxw,maxh = 0,0
for i = 1,#room_types do
  maxw = math.max(maxw, room_types[i].wrange[2])
  maxh = math.max(maxh, room_types[i].hrange[2])
end

GRID_SIZE = Vector(maxw,maxh)

-- Returns 2 vectors for the start and end of the adjacency
function adjacency(obj1, obj2)
  if obj1.pos.x > obj2.pos.x then obj1,obj2 = obj2,obj1 end

  if obj2.pos.x == obj1.pos.x + obj1.size.x then
    local y1,y2
    y1 = math.max(obj1.pos.y, obj2.pos.y)
    y2 = math.min(obj1.pos.y + obj1.size.y, obj2.pos.y + obj2.size.y)
    
    if y2 - y1 > 0 then
      return Vector(obj2.pos.x, y1), Vector(obj2.pos.x, y2)
    end
  end

  if obj1.pos.y > obj2.pos.y then obj1,obj2 = obj2,obj1 end
  if obj2.pos.y == obj1.pos.y + obj1.size.y then
    local x1,x2
    x1 = math.max(obj1.pos.x, obj2.pos.x)
    x2 = math.min(obj1.pos.x + obj1.size.x, obj2.pos.x + obj2.size.x)
    
    if x2 - x1 > 0 then
      return Vector(x1, obj2.pos.y), Vector(x2, obj2.pos.y)
    end
  end
  
  return nil, nil
end

function generate(seed)

  
  --[[
  grid = {
    { {size=Vector(2,2)}, {size=Vector(2,2)}, {size=Vector(3,3)} },
    { {size=Vector(6,6)}, {size=Vector(2,5)}, {size=Vector(3,2)} },
    { {size=Vector(3,6)}, {size=Vector(4,5)}, {size=Vector(3,8)} }
  }]]--
  
  -- THE GRID
  --
  -- A DIGITAL FRONTIER
  grid = {}
  
  seed = seed or os.time()
  
  local random = love.math.newRandomGenerator(seed)
  
  local width,height = random:random(1, 4), random:random(2, 4)
  
  function gen_room(type)
    local template = room_types[type]
    local room = {}
    
    local size = Vector(random:random(unpack(template.wrange)), random:random(unpack(template.hrange)))
    room.size = size
    room.colour = template.colour
    room.name = template.name
    local geometry = {}
    for i = 1, size.x do
      geometry[i] = {}
      for j = 1, size.y do
        geometry[i][j] = type
      end
    end
    room.geometry = Geometry(geometry)
    room.doors = {}
    return room
  end
  
  rooms = {}
  
  for i = 1, ROOM_PRESELECTED_OFFSET-1 do
    local index
    repeat
      index = random:random(width*height)
    until rooms[index] == nil
    rooms[index] = gen_room(i)
  end
  
  for i = 1,width*height do
    if not rooms[i] then
      rooms[i] = gen_room(random:random(ROOM_PRESELECTED_OFFSET,#room_types))
    end
  end
  
  for y = 1,height do
    grid[y] = {}
    for x = 1,width do
      grid[y][x] = rooms[xy2index(x,y,width)]
    end
  end
  
  function gen_filler() return {size = GRID_SIZE - Vector(2,2), colour={0.01,0.01,0.01}} end
  
  --[[grid = {
    {{size=Vector(2,5)}},
    {{size=Vector(2,10)}},
    {{size=Vector(2,4)}},
    {{size=Vector(2,7)}},
    }]]--
  
  local midx = math.floor(GRID_SIZE.x / 2)
  local midy = math.floor(GRID_SIZE.y / 2)
  for y = 1,#grid do
    for x = 1, #grid[1] do
      local room = grid[y][x]
      local xoff = random:random(math.max(0, midy-room.size.x), math.min(midx - 1, GRID_SIZE.x-room.size.x))
      local yoff = random:random(math.max(0, midy-room.size.y), math.min(midy - 1, GRID_SIZE.y-room.size.y))
      room.pos = Vector(x*GRID_SIZE.x + xoff, y*GRID_SIZE.y + yoff)
      
      room.colour = room.colour or {random:random(), random:random(), random:random()}
    end
  end
  

  for y = 1,#grid do
    compress(grid[y], "x")
  end

  for y = 1,#grid-1 do 
    merge(grid[y],grid[y+1],"y")
  end
  
  adjmatrix = {}
  to_merge = {}
  
  -- Door generation
  -- This should segue into 
  for i = 1,#rooms do
    if not adjmatrix[i] then
      adjmatrix[i] = {}
    end
    for j = i+1,#rooms do
      -- Don't check already checked rooms
      if not adjmatrix[j] or not adjmatrix[j][i] then
        local vec1, vec2 = adjacency(rooms[i], rooms[j])
        if vec1 then
          -- If two rooms are touching and are the same room type then merge them
          if rooms[i].name == rooms[j].name then
            if random:random(1,2) == 1 then
              to_merge[#to_merge+1]={i,j}
            else
              to_merge[#to_merge+1]={j,i}
            end
          else
            local door = {}
            if vec1.x == vec2.x then
              door.vec1 = Vector(vec1.x, random:random(vec1.y, vec2.y-1))
              door.vec2 = door.vec1 + Vector(0,1)
            elseif vec1.y == vec2.y then
              door.vec1 = Vector(random:random(vec1.x, vec2.x-1), vec1.y)
              door.vec2 = door.vec1 + Vector(1,0)
            end
            rooms[i].doors[j] = door
            adjmatrix[i][j] = door
          end
        end
      end
    end
  end
  
  function sparse_merge(arr1, arr2, length)
    local arr = {}
    for i = 1,length do
      arr[i] = arr1[i] or arr2[i]
    end
    return arr
  end

  -- FIXME: For debugging
  rects = {}
  
  for i = 1, #rooms do
    rects[#rects+1] = {rooms[i].pos:clone(), rooms[i].size:clone()}
  end
  
  -- NOW LEAVING THE GRID
    
  for _, merge_pair in ipairs(to_merge) do
    local i,j = unpack(merge_pair)
    
    local room1, room2 = rooms[i], rooms[j]
    
    assert(room1 and room2)
    
    room1.doors = sparse_merge(room1.doors, room2.doors, #rooms)
    
    room1.geometry:add(room2.geometry, room2.pos - room1.pos)
    
    room1.pos = Vector(math.min(room1.pos.x, room2.pos.x), math.min(room1.pos.y, room2.pos.y))
    
    for _, pair in ipairs(to_merge) do
      if pair[1] > j then pair[1] = pair[1] - 1 end
      if pair[2] > j then pair[2] = pair[2] - 1 end
    end
    
    table.remove(rooms, j)
  end
  
  shipGeometry = Geometry()
  
  doors = {}
  for i,room in ipairs(rooms) do
    for j = 1,#rooms do
      local door = room.doors[j]
      if door then
        door.room1 = rooms[i]
        door.room2 = rooms[j]
        doors[#doors+1] = door
      end
    end
    
    shipGeometry:add(room.geometry, room.pos)
  end
    
  -- Drawing to spritebatches
  ----------------------------

  floorSpriteBatch:clear()
  greebleSpriteBatch:clear()
  gridSpriteBatch:clear()
  
  
  -- TODO: Center greebles that are < TILE_WIDTH wide
  -- Greebles
  local size = shipGeometry:size()
  for x = 1,size.x+1 do
    for y = 1,size.y+1 do
      if not shipGeometry:get(x,y) then
        --empty space for greebles
        if random:random() > 0.4 then
          local quad = greebleQuads[random:random(#greebleQuads)]
          local _,_,quadWidth,quadHeight = quad:getViewport()
          if shipGeometry:get(x+1,y) then
            -- Pointing left
            greebleSpriteBatch:add(quad, (x-1)*TILE_WIDTH-(quadHeight-TILE_WIDTH), (y-1)*TILE_WIDTH+quadWidth, -math.pi/2, 1, 1, 0, 0)
          elseif shipGeometry:get(x-1,y) then
            -- Pointing right
            greebleSpriteBatch:add(quad, (x-1)*TILE_WIDTH+quadHeight, (y-1)*TILE_WIDTH, math.pi/2, 1, 1, 0, 0)
          elseif shipGeometry:get(x,y+1) then
            -- Pointing up
            greebleSpriteBatch:add(quad, (x-1)*TILE_WIDTH, (y-1)*TILE_WIDTH-(quadHeight-TILE_WIDTH), 0, 1, 1, 0, 0)
          elseif shipGeometry:get(x,y-1) then
            -- Pointing down
            greebleSpriteBatch:add(quad, (x-1)*TILE_WIDTH+quadWidth, (y-1)*TILE_WIDTH+quadHeight, math.pi, 1, 1, 0, 0)
          end
        end
      else
        --tilesetSpriteBatch:add(tileQuads[1], x*16, y*16)
      end
    end
  end
  
  -- Hull
  for x = 1, size.x do
    for y = 1, size.y do
      if shipGeometry:get(x,y) then 
        local quad = tileset:getQuad(shipGeometry,x,y)
        if quad then
          floorSpriteBatch:add(quad, (x-1)*TILE_WIDTH, (y-1)*TILE_WIDTH)   
        end
      end
    end
  end
  
  -- Rooms
  for i = 1,#rooms do
    local room = rooms[i]
    if room then
      gridSpriteBatch:setColor(room.colour)
      
      local size = room.geometry:size()
      for x = 1, size.x do
        for y = 1, size.y do
          if room.geometry:get(x,y) then 
            local quad = tileset:getQuad(room.geometry,x,y)
            if quad then
              gridSpriteBatch:add(quad, (room.pos.x+x-1)*TILE_WIDTH, (room.pos.y+y-1)*TILE_WIDTH)   
            end
          end
        end
      end
--      love.graphics.rectangle("line", room.pos.x*scale, room.pos.y*scale, room.geometry:size().x*scale, room.geometry:size().y*scale)
    end
  end

end

local seed = 1573187624
function love.keypressed()
  generate(seed)
  seed = seed + 1
end

-- From https://stackoverflow.com/a/16691908
function overlap(start1,end1,start2,end2)
  return math.max(0, math.min(end1, end2) - math.max(start1, start2))
end

function merge(arr1, arr2, dir)
  dir = dir or "x"
  local offdir = dir == "x" and "y" or "x"
  
  local mindiff
  for i = 1,#arr1 do
    local current = arr1[i]
    
    for j =1,#arr2 do
      local opposite = arr2[j]
      if overlap(opposite.pos[offdir], opposite.pos[offdir]+opposite.size[offdir],
                 current.pos[offdir], current.pos[offdir]+current.size[offdir]) > 0 then
        local diff = opposite.pos[dir] - current.pos[dir] - current.size[dir]
        if not mindiff then
          mindiff = diff
        else
          mindiff = math.min(mindiff, diff)
        end
      end
    end
  end
  
  for i = 1, #arr2 do
    arr2[i].pos[dir] = arr2[i].pos[dir] - mindiff
  end
end

function compress(arr, dir)
  for i=1,#arr-1 do
    merge({arr[i]}, {arr[i+1]}, dir)
  end
end

function compress(arr, dir)
  dir = dir or "x"
  local middle = math.floor(#arr/2)
  for i = middle,1,-1 do
    local current = arr[i]
    local neighbour = arr[i+1]
    
    current.pos[dir] = neighbour.pos[dir] - current.size[dir]
  end
  for i = middle+1,#arr do
    local current = arr[i]
    local neighbour = arr[i-1]
    if not neighbour then break end
    current.pos[dir] = neighbour.pos[dir] + neighbour.size[dir]
  end
end

local scale = 3

function love.draw()
  love.graphics.push()
  love.graphics.setPointSize(3)
  local tl,br
  
  for i = 1,#rooms do
    if rooms[i] then
      local current = rooms[i].pos
      if tl then
        if current.x < tl.x then
          tl.x = current.x
        end
        if current.y < tl.y then
          tl.y = current.y
        end
      else
        tl = current:clone()
      end
      if br then
        if current.x + rooms[i].size.x > br.x then
          br.x = current.x + rooms[i].size.x 
        end
        
        if current.y + rooms[i].size.y > br.y then
          br.y = current.y + rooms[i].size.y
        end
      else
        br = current + rooms[i].size
      end
    end
  end
  
  local center = tl + (br-tl)/2
  

  center = center * TILE_WIDTH * scale
  center = Vector(love.graphics.getWidth(), love.graphics.getHeight())/2 - center
  love.graphics.translate(center.x, center.y)
  love.graphics.scale(scale)
  
  love.graphics.setColor(1,1,1)
  love.graphics.draw(greebleSpriteBatch)
  
  love.graphics.draw(floorSpriteBatch)
  love.graphics.draw(gridSpriteBatch)


  for _,door in ipairs(doors) do
    local room1, room2 = door.room1, door.room2
    c1 = room1.pos + room1.geometry:size()/2
    c2 = room2.pos + room2.geometry:size()/2
    
    --love.graphics.points(c1.x*scale, c1.y*scale, c2.x*scale, c2.y*scale)
    --love.graphics.line(c1.x*scale,c1.y*scale,c2.x*scale,c2.y*scale)
    love.graphics.line(door.vec1.x*scale*TILE_WIDTH,door.vec1.y*scale*TILE_WIDTH,door.vec2.x*scale*TILE_WIDTH,door.vec2.y*scale*TILE_WIDTH)    
  end
--  for i = 1, #rooms do
--    for j = 1, #rooms do
--      local door = adjmatrix[i][j]
--      if door then
--        love.graphics.line(door.vec1.x*scale,door.vec1.y*scale,door.vec2.x*scale,door.vec2.y*scale)
--      end
--    end
--  end
  love.graphics.pop()
  
  love.graphics.print("seed = "..tostring(seed), 10, 1010)
end