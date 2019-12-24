local Vector = require "vector"
local geometry = require "geometry"
local TileGrid = geometry.TileGrid
local Geometry = geometry.GeometryView

local TileSet = require "tileset"

function love.load(arg)
  -- ZeroBrane debugging
  if arg[#arg] == "-debug" then require("mobdebug").start() end
  
  -- Debug drawing/logging settings
  DEBUG = {
    seed = true,
  }
  
  love.graphics.setDefaultFilter("nearest", "nearest")
  WINDOW_WIDTH = 1024
  WINDOW_HEIGHT = 700
  love.window.setMode(WINDOW_WIDTH, WINDOW_HEIGHT)
  
  hullTileset = love.graphics.newImage("tileset.png")
  gridTileset = love.graphics.newImage("room_tileset.png")
  greebleTilesetImage = love.graphics.newImage("greebles.png")
  
  local tilesetwidth,tilesetheight = hullTileset:getDimensions()
  
  TILE_WIDTH=16
  
  tileset = TileSet(tilesetwidth, tilesetheight, TILE_WIDTH)
  
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
  
  wallSpriteBatch = love.graphics.newSpriteBatch(hullTileset, 100)
  roomTileSpriteBatch = love.graphics.newSpriteBatch(gridTileset, 100)
  greebleSpriteBatch = love.graphics.newSpriteBatch(greebleTilesetImage, 100)
  
  -- janky first generation
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

REQUIRED_ROOM_TYPE_OFFSET = 3
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
    room.geometry = Geometry:new(geometry)
    room.doors = {}
    return room
  end
  
  rooms = {}
  
  -- Generate one of each of the "required" rooms
  for i = 1, REQUIRED_ROOM_TYPE_OFFSET-1 do
    local index
    repeat
      index = random:random(width*height)
    until rooms[index] == nil
    rooms[index] = gen_room(i)
  end
  
  -- Fill the remaining space with other room types
  for i = 1,width*height do
    if not rooms[i] then
      rooms[i] = gen_room(random:random(REQUIRED_ROOM_TYPE_OFFSET,#room_types))
    end
  end
  
  -- Fill the grid
  -- TODO: A better way of spatial partitioning here?
  for y = 1,height do
    grid[y] = {}
    for x = 1,width do
      grid[y][x] = rooms[xy2index(x,y,width)]
    end
  end
  
  function gen_filler() return {size = GRID_SIZE - Vector(2,2), colour={0.01,0.01,0.01}} end
  
  -- Generate positions within each grid tile
  -- midx,midy are used to ensure alignment so that grids can collide
  local midx = math.floor(GRID_SIZE.x / 2)
  local midy = math.floor(GRID_SIZE.y / 2)
  for y = 1,#grid do
    for x = 1, #grid[1] do
      local room = grid[y][x]
      -- This doesn't actually matter because they're getting crammed together anyway...
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
    if i ~= j then
      --if i > j then i,j = j,i end
      
      local room1, room2 = rooms[i], rooms[j]
      
      assert(room1 and room2, "No nil merges")
      
      room1.doors = sparse_merge(room1.doors, room2.doors, #rooms)
      
      local origin_shift = room1.geometry:add(room2.geometry, room2.pos - room1.pos)
      room1.pos = room1.pos + origin_shift
      
      for _, pair in ipairs(to_merge) do
        if pair[1] > j then
          pair[1] = pair[1] - 1 
        elseif pair[1] == j then
          pair[1] = i
        end
        
        if pair[2] > j then
          pair[2] = pair[2] - 1
        elseif pair[2] == j then
          pair[2] = i
        end
      end
      
      table.remove(rooms, j)
    end
  end
  
  shipGeometry = Geometry:new()
  
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

  wallSpriteBatch:clear()
  greebleSpriteBatch:clear()
  roomTileSpriteBatch:clear()
  
  
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
  
  -- Walls
  for x = 1, size.x do
    for y = 1, size.y do
      if shipGeometry:get(x,y) then 
        local quad = tileset:getQuad(shipGeometry,x,y)
        if quad then
          wallSpriteBatch:add(quad, (x-1)*TILE_WIDTH, (y-1)*TILE_WIDTH)   
        end
      end
    end
  end
  
  -- Rooms
  for i = 1,#rooms do
    local room = rooms[i]
    if room then
      roomTileSpriteBatch:setColor(room.colour)
      
      local size = room.geometry:size()
      for x = 1, size.x do
        for y = 1, size.y do
          if room.geometry:get(x,y) then 
            local quad = tileset:getQuad(room.geometry,x,y)
            if quad then
              roomTileSpriteBatch:add(quad, (room.pos.x+x-1)*TILE_WIDTH, (room.pos.y+y-1)*TILE_WIDTH)   
            end
          end
        end
      end
--      love.graphics.rectangle("line", room.pos.x*scale, room.pos.y*scale, room.geometry:size().x*scale, room.geometry:size().y*scale)
    end
  end

end

local seed = 1573187721
function love.keypressed(key)
  if key == "space" then
    generate(seed)
    seed = seed + 1
  elseif key == "r" then
    DEBUG.room_bounds = not DEBUG.room_bounds
  end
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
  
  love.graphics.draw(wallSpriteBatch)
  love.graphics.draw(roomTileSpriteBatch)


  for _,door in ipairs(doors) do
    local room1, room2 = door.room1, door.room2
    c1 = room1.pos + room1.geometry:size()/2
    c2 = room2.pos + room2.geometry:size()/2
    
    --love.graphics.points(c1.x*scale, c1.y*scale, c2.x*scale, c2.y*scale)
    --love.graphics.line(c1.x*scale,c1.y*scale,c2.x*scale,c2.y*scale)
    love.graphics.line(door.vec1.x*scale*TILE_WIDTH,door.vec1.y*scale*TILE_WIDTH,door.vec2.x*scale*TILE_WIDTH,door.vec2.y*scale*TILE_WIDTH)    
  end
  for i = 1, #rooms do
    for j = 1, #rooms do
      local door = adjmatrix[i][j]
      if door then
        love.graphics.line(door.vec1.x*scale,door.vec1.y*scale,door.vec2.x*scale,door.vec2.y*scale)
      end
    end
  end
  if DEBUG.rect_bounds then
    love.graphics.setColor(1,0,0)
    for i = 1,#rects do
      local rect = rects[i]
      love.graphics.rectangle("line", rect[1].x*TILE_WIDTH, rect[1].y*TILE_WIDTH, rect[2].x*TILE_WIDTH, rect[2].y*TILE_WIDTH)
    end
  end
  
  if DEBUG.room_bounds then
    for i = 1,#rooms do
      local room = rooms[i]
      love.graphics.setColor(room.colour)
      love.graphics.rectangle("line", room.pos.x*TILE_WIDTH, room.pos.y*TILE_WIDTH, (room.geometry:size()*TILE_WIDTH):unpack())
    end
  end
  
  love.graphics.pop()
  if DEBUG.seed then
    love.graphics.setColor(1,1,1)
    love.graphics.print("seed = "..tostring(seed), 10, WINDOW_HEIGHT - 20)
  end
end