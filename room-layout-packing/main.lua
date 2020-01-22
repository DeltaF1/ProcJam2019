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
    mouse_pos = false
  }
  
  love.graphics.setDefaultFilter("nearest", "nearest")
  WINDOW_WIDTH = 1024
  WINDOW_HEIGHT = 700
  love.window.setMode(WINDOW_WIDTH, WINDOW_HEIGHT)
  
  hullTileAtlas = love.graphics.newImage("tileset_inv.png")
  wallTileAtlas = love.graphics.newImage("room_0px.png")
  gridTileset = love.graphics.newImage("room_1px.png")
  greebleAtlas = love.graphics.newImage("greebles.png")
  propAtlas = love.graphics.newImage("props.png")
  
  door_open = love.graphics.newImage("door_open.png")
  door_closed = love.graphics.newImage("door_closed.png")
  
  local tilesetwidth,tilesetheight = hullTileAtlas:getDimensions()
  
  TILE_WIDTH=16
  
  tileset = TileSet(tilesetwidth, tilesetheight, TILE_WIDTH)
  
  greebleQuads = {
    love.graphics.newQuad(0,0,16,32,greebleAtlas:getDimensions()), --antenna array
    love.graphics.newQuad(16,0,16,16,greebleAtlas:getDimensions()), --light box
    -- coloured boxes
    love.graphics.newQuad(16,16,8,8,greebleAtlas:getDimensions()),
    love.graphics.newQuad(16,24,8,8,greebleAtlas:getDimensions()), 
    love.graphics.newQuad(24,16,8,8,greebleAtlas:getDimensions()), 
    love.graphics.newQuad(24,24,8,8,greebleAtlas:getDimensions()),
    -- railings
    love.graphics.newQuad(32,17,16,3,greebleAtlas:getDimensions()),
    love.graphics.newQuad(32,20,16,3,greebleAtlas:getDimensions()),
    love.graphics.newQuad(32,23,16,3,greebleAtlas:getDimensions()),
    love.graphics.newQuad(32,26,16,3,greebleAtlas:getDimensions()),
    love.graphics.newQuad(32,29,16,3,greebleAtlas:getDimensions()),
    
    love.graphics.newQuad(48,0,16,32,greebleAtlas:getDimensions()), -- antenna
  }
  
  propTypes = {
    {quad = love.graphics.newQuad(0,12,31,20,propAtlas:getDimensions()), rotate=true, rooms={[4]=true,[6]=true}}, -- table
    {quad = love.graphics.newQuad(0,0,11,12,propAtlas:getDimensions()), rotate=true, rooms={[1]=true}, frequency = 100, max=2}, -- console
    {quad = love.graphics.newQuad(31,18,14,14,propAtlas:getDimensions()), rotate=false, rooms={[3]=true}, frequency=10}, -- crate
    {quad = love.graphics.newQuad(48,21,30,10,propAtlas:getDimensions()), rotate=true, rooms={[3]=true}, frequency=10}, -- crate-long
    {quad = love.graphics.newQuad(24,0,16,9,propAtlas:getDimensions()), rotate=true, rooms={[5]=true}, frequency=10}
  }
  
  hullSpritebatch = love.graphics.newSpriteBatch(hullTileAtlas, 100)
  wallSpritebatch = love.graphics.newSpriteBatch(wallTileAtlas, 100)
  roomTileSpriteBatch = love.graphics.newSpriteBatch(gridTileset, 100)
  greebleSpriteBatch = love.graphics.newSpriteBatch(greebleAtlas, 100)
  propSpriteBatch = love.graphics.newSpriteBatch(propAtlas, 100)
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
  {name = "Engine",             wrange={2,2}, hrange={2,3}, colour={0.58330589736158589, 0.024793900080875231, 0.83640388831262813}},
  -----------------------------  ROOM_PRESELECTED_OFFSET
  {name = "Storage Bay",        wrange={3,6}, hrange={3,6}, colour={0.82675021090650347, 0.1807523156814923, 0.25548658234132504}},
  {name = "Mess Hall",          wrange = {2,3}, hrange={2,3}, colour = {0.3540978676870179, 0.47236376329459961, 0.67900487187065317}},
  {name = "Sleeping quarters",  wrange = {1,2}, hrange={1,2}, colour = {0.57514179487402095, 0.79693061238668306, 0.45174307459403407}},
  {name = "Lounge",             wrange = {2,3}, hrange={2,3}, colour = {0.049609465521796903, 0.82957781845624967, 0.62650828993078767}},
  {name = "Corridor",         wrange={2,10}, hrange={1,2}, colour = {0.3,0.3,0.3}},
  {name = "Corridor",         wrange={1,2}, hrange={2,10}, colour = {0.3,0.3,0.3}},
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

-- Merge two sparse arrays of the specified length
function sparse_merge(arr1, arr2, length)
  local arr = {}
  for i = 1,length do
    arr[i] = arr1[i] or arr2[i]
  end
  return arr
end

-- Debug method
function print_adj()
  local header = "   "
  for i = 1, #adjmatrix do
    header = header..("%2d"):format(i).." "
  end
  print(header)
  for j = 1, #rooms do
    -- row label
    local s = ("%3d"):format(j).." "
    for i = 1, #adjmatrix do
      local c = adjmatrix[i][j] and "D" or "_"
      s = s .. c .. "  "
    end
    print(s)
  end
end

function generate(seed)  
  -- THE GRID
  --
  -- A DIGITAL FRONTIER
  grid = {}
  
  seed = seed or os.time()
  
  local random = love.math.newRandomGenerator(seed)
  
  local width,height = random:random(1, 4), random:random(2, 4)
  
  function gen_room(type)
    local template = room_types[type]
    local room = {type=type}
    
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
  
  -- Slam the rects together

  for y = 1,#grid do
    compress(grid[y], "x")
  end

  for y = 1,#grid-1 do 
    merge(grid[y],grid[y+1],"y")
  end
  
  -- Update room positions to be relative to the new bounding box
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
  
  tl = tl - Vector(1,1)
  
  for i = 1, #rooms do
    rooms[i].pos = rooms[i].pos - tl
  end
  
  adjmatrix = {}
  to_merge = {}
  
  -- Door generation
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
            -- Generate a random 1-wide line across the intersection surface
            if vec1.x == vec2.x then
              door.vec1 = Vector(vec1.x, random:random(vec1.y, vec2.y-1))
              door.vec2 = door.vec1 + Vector(0,1)
            elseif vec1.y == vec2.y then
              door.vec1 = Vector(random:random(vec1.x, vec2.x-1), vec1.y)
              door.vec2 = door.vec1 + Vector(1,0)
            end
            adjmatrix[i][j] = door
          end
        end
      end
    end
  end
  
  -- FIXME: For debugging
  rects = {}
  
  for i = 1, #rooms do
    rects[#rects+1] = {rooms[i].pos:clone(), rooms[i].size:clone()}
  end
  
  -- NOW LEAVING THE GRID
  
  for _, merge_pair in ipairs(to_merge) do
    local i, j = unpack(merge_pair)
    if i ~= j then
      if i > j then i,j = j,i end
      
      local room1, room2 = rooms[i], rooms[j]
      
      assert(room1 and room2, "No nil merges")
      
      -- Merge the tile geometry of the two rooms together.
      -- If merging the rooms would change the upper-left corner,
      -- then update room1's position so that relative positions are preserved
      local origin_shift = room1.geometry:add(room2.geometry, room2.pos - room1.pos)
      room1.pos = room1.pos + origin_shift
      
      -- Update the room ids in the set of merge pairs since the array has shifted
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
      
      -- Merge the door set into room 1
      adjmatrix[i] = sparse_merge(adjmatrix[i], adjmatrix[j], #rooms)
      
      for room=1,#rooms do
        -- Merge the door set into room 1
        adjmatrix[room][i] = adjmatrix[room][i] or adjmatrix[room][j]
        
        -- Delete the old row
        for idx = j,#rooms do
          adjmatrix[room][idx]=adjmatrix[room][idx+1]
        end
      end
      
      -- Delete the old column
      table.remove(adjmatrix, j)
      
      -- Delete the old room
      table.remove(rooms, j)
    end
  end
  
  -- Mirror the whole matrix along the diagonal
  for i = 1,#adjmatrix do
    for j = i,#adjmatrix do
      adjmatrix[i][j] = adjmatrix[j][i] or adjmatrix[i][j]
      adjmatrix[j][i] = adjmatrix[j][i] or adjmatrix[i][j]
    end
  end
  
  shipGeometry = Geometry:new()
  
  for i,room in ipairs(rooms) do
    shipGeometry:add(room.geometry, room.pos)
  end
    
  -- Drawing to spritebatches
  ----------------------------

  hullSpritebatch:clear()
  greebleSpriteBatch:clear()
  roomTileSpriteBatch:clear()
  wallSpritebatch:clear()
  propSpriteBatch:clear()
  
  -- TODO: Center greebles that are < TILE_WIDTH wide
  -- Greebles
  
  -- Add an offset of 1 to generate hull sprites outside of the limits
  local size = shipGeometry:size() + Vector(1,1)
  local hullWidth = 2
  for x = 1,size.x+1 do
    for y = 1,size.y+1 do
      if not shipGeometry:get(x,y) then
        --empty space for greebles
        if random:random() > 0.2 then
          local quad = greebleQuads[random:random(#greebleQuads)]
          local _,_,quadWidth,quadHeight = quad:getViewport()
          if shipGeometry:get(x+1,y) then
            -- Pointing left
            greebleSpriteBatch:add(quad, (x-1)*TILE_WIDTH-(quadHeight-TILE_WIDTH)-hullWidth, (y-1)*TILE_WIDTH+quadWidth, -math.pi/2, 1, 1, 0, 0)
          elseif shipGeometry:get(x-1,y) then
            -- Pointing right
            greebleSpriteBatch:add(quad, (x-1)*TILE_WIDTH+quadHeight+hullWidth, (y-1)*TILE_WIDTH, math.pi/2, 1, 1, 0, 0)
          elseif shipGeometry:get(x,y+1) then
            -- Pointing up
            greebleSpriteBatch:add(quad, (x-1)*TILE_WIDTH, (y-1)*TILE_WIDTH-(quadHeight-TILE_WIDTH)+hullWidth, 0, 1, 1, 0, 0)
          elseif shipGeometry:get(x,y-1) then
            -- Pointing down
            greebleSpriteBatch:add(quad, (x-1)*TILE_WIDTH+quadWidth, (y-1)*TILE_WIDTH+quadHeight-hullWidth, math.pi, 1, 1, 0, 0)
          end
        end
      else
        --tilesetSpriteBatch:add(tileQuads[1], x*16, y*16)
      end
    end
  end
  
  invGeometry = {
    get = function(self, x,y)
      return not shipGeometry:get(x,y)
    end
  }
  setmetatable(invGeometry, {__index=shipGeometry})
  
  floorQuad = love.graphics.newQuad(80,122,16,16,96,128)
  -- Walls
  for x = 1, size.x do
    for y = 1, size.y do
      if invGeometry:get(x,y) then 
        local quad = tileset:getQuad(invGeometry,x,y)
        if quad then
          hullSpritebatch:add(quad, (x-1)*TILE_WIDTH, (y-1)*TILE_WIDTH)   
        end
      else
        local quad = floorQuad
        hullSpritebatch:add(quad, (x-1)*TILE_WIDTH, (y-1)*TILE_WIDTH)
      end
    end
  end
  
  -- Rooms
  for i = 1,#rooms do
    local room = rooms[i]
    if room then
      roomTileSpriteBatch:setColor(room.colour[1], room.colour[2], room.colour[3], 0.5)
      wallSpritebatch:setColor(0.3, 0.3, 0.3)
      local size = room.geometry:size()
      for x = 1, size.x do
        for y = 1, size.y do
          if room.geometry:get(x,y) then 
            local quad = tileset:getQuad(room.geometry,x,y)
            if quad then
              roomTileSpriteBatch:add(quad, (room.pos.x+x-1)*TILE_WIDTH, (room.pos.y+y-1)*TILE_WIDTH)
              wallSpritebatch:add(quad, (room.pos.x+x-1)*TILE_WIDTH, (room.pos.y+y-1)*TILE_WIDTH)
            end
          end
        end
      end
    end
  end
  
  props = {}
  FREQUENCY = 5
  propgeometry = TileGrid:new()
  
  for i = 1, #rooms do
    local room = rooms[i]
    local size = room.geometry:size()
    for propType = 1, #propTypes do
      local prop = propTypes[propType]
      if not prop.rooms or prop.rooms[room.type] then
        count = 0
        for i = 1, prop.frequency or FREQUENCY do
          if prop.max and count >= prop.max then break end
          
          local roomX = random:random(1, size.x)
          local roomY = random:random(1, size.y)
          
          local _, _, pixelWidth, pixelHeight = prop.quad:getViewport()
          
          if prop.rotate then
            rot = random:random(4)
          else
            rot = 1
          end

          local angle = ({0,math.rad(90),math.rad(180),math.rad(270)})[rot]
          local offset = ({Vector(0,0), Vector(pixelHeight,0), Vector(pixelWidth,pixelHeight), Vector(0,pixelWidth)})[rot]

          if rot % 2 == 0 then
            pixelWidth,pixelHeight = pixelHeight,pixelWidth
          end
          
          local gridWidth = math.ceil(pixelWidth/TILE_WIDTH)
          local gridHeight = math.ceil(pixelHeight/TILE_WIDTH)
          
          local br = false
          for checkX = roomX, roomX+gridWidth-1 do
            for checkY = roomY, roomY+gridHeight-1 do
              if not room.geometry:get(checkX, checkY) or propgeometry:get(checkX+room.pos.x,checkY+room.pos.y) then
                br = true
              end
              if br then break end
            end
            if br then break end
          end
          
          -- Placement is unobstructed!
          if not br then
            roomX = roomX + room.pos.x
            roomY = roomY + room.pos.y
            for setX = roomX, roomX+gridWidth-1 do
              for setY = roomY, roomY+gridHeight-1 do
                propgeometry:set(setX, setY, "p")
              end
            end
            
            local jitter = Vector(random:random(1,(gridWidth*TILE_WIDTH)-pixelWidth), random:random(1,(gridHeight*TILE_WIDTH)-pixelHeight))
            jitter = jitter - Vector(1,1)
            offset = offset + jitter
            
            pos = Vector(roomX,roomY)
            props[#props+1] = {quad=prop.quad, position = pos}
            propSpriteBatch:add(prop.quad, ((pos.x-1)*TILE_WIDTH)+offset.x, ((pos.y-1)*TILE_WIDTH)+offset.y, angle, 1, 1)
            count = count + 1
          end
        end
      end
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
  elseif key == "t" then
    DEBUG.rect_bounds = not DEBUG.rect_bounds
  elseif key == "n" then
    DEBUG.tile_numbers = not DEBUG.tile_numbers
  elseif key == "p" then
    DEBUG.prop_grid = not DEBUG.prop_grid
  elseif key == "=" then
    viewScale = viewScale + 0.2
  elseif key == "-" then
    viewScale = viewScale - 0.2
  elseif key == "a" then
    print_adj()
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

-- https://stackoverflow.com/a/1501725
function line_segment_min(a, b, point)
  local l2 = a:dist2(b)
  if l2 == 0 then
    return a:dist(point)
  end
  
  local t = math.max(0, math.min(1, (point-a) * (b-a) / l2))
  local projection = a + t * (b - a)
  return point:dist(projection)
end

function love.mousepressed(x,y,button)
  local screenSpace = Vector(x,y)
  
  -- Position in ship pixel space
  local shipSpace = (screenSpace / viewScale) - (viewOffset / (viewScale))
  
  local door
  local br = false
  for i = 1, #adjmatrix do
    for j = i, #adjmatrix do
      door = adjmatrix[i][j]
      if door then
        if line_segment_min(door.vec1 * TILE_WIDTH, door.vec2 * TILE_WIDTH, shipSpace) < 2 then
          br = true
          door.open = not door.open
          break
        end
      end
    end
    if br then break end
  end
end

viewScale = 3

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
  
  center = center * TILE_WIDTH * viewScale
  center = Vector(love.graphics.getWidth(), love.graphics.getHeight())/2 - center
  viewOffset = center
  love.graphics.translate(viewOffset.x, viewOffset.y)
  love.graphics.scale(viewScale)
  
  love.graphics.setColor(1,1,1)
  love.graphics.draw(greebleSpriteBatch)
  
  love.graphics.draw(hullSpritebatch)
  love.graphics.draw(roomTileSpriteBatch)
  love.graphics.draw(wallSpritebatch)
  love.graphics.draw(propSpriteBatch)
  
  for i = 1, #rooms do
    for j = i, #rooms do
      local door = adjmatrix[i][j]
      if door then
        local vec1, vec2 = door.vec1, door.vec2
        local upperLeft = vec1:min(vec2)
        local bottomRight = vec1:max(vec2)
        local drawPos = upperLeft*TILE_WIDTH
        if vec1.x == vec2.x then
          r = math.pi/2
          drawPos = drawPos + Vector(1,0)
        else
          r = 0
          drawPos = drawPos + Vector(0,-1)
        end
        
        love.graphics.draw(door.open and door_open or door_closed, drawPos.x, drawPos.y, r)
        --love.graphics.line(door.vec1.x*TILE_WIDTH,door.vec1.y*TILE_WIDTH,door.vec2.x*TILE_WIDTH,door.vec2.y*TILE_WIDTH)
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
  
  if DEBUG.prop_grid then
    love.graphics.setColor(1,1,1,0.3)
    local size = shipGeometry:size()
    for x = 1, size.x do
      for y = 1, size.y do
        if propgeometry:get(x,y) then
          love.graphics.rectangle("fill", (x-1)*TILE_WIDTH, (y-1)*TILE_WIDTH, TILE_WIDTH, TILE_WIDTH)
        end
      end
    end
  end
  
  love.graphics.pop()
  love.graphics.push()
  love.graphics.translate(center.x, center.y)
  if DEBUG.tile_numbers then
    local size = invGeometry:size()
    for x = 1, size.x do
      for y = 1, size.y do
        local number = tileset:getTileIndex(invGeometry, x, y)
        love.graphics.print(number, (x-1)*viewScale*TILE_WIDTH, (y-1)*viewScale*TILE_WIDTH)
      end
    end
  end
  love.graphics.pop()
  if DEBUG.seed then
    love.graphics.setColor(1,1,1)
    love.graphics.print("seed = "..tostring(seed), 10, WINDOW_HEIGHT - 20)
  end
  
  if DEBUG.mouse_pos then
    local screenSpace = Vector(love.mouse.getX(), love.mouse.getY())
    local shipSpace = (screenSpace / viewScale) - (center / (viewScale))
    love.graphics.setColor(1,1,1)
    love.graphics.print("screenSpace = "..tostring(screenSpace)..", shipSpace = "..tostring(shipSpace))
  end
end