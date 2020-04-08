local Vector = require "vector"
local geometry = require "geometry"

local Ship = require("ship").Ship

local TileGrid = geometry.TileGrid
local Geometry = geometry.GeometryView

local TileSet = require "tileset"

function love.load(arg)
  -- ZeroBrane debugging
  if arg[#arg] == "-debug" then require("mobdebug").start() end
  
  -- Debug drawing/logging settings
  DEBUG = {
    seed = true,
    mouse_pos = true,
  }
  
  love.graphics.setDefaultFilter("nearest", "nearest")
  WINDOW_WIDTH = 1024
  WINDOW_HEIGHT = 700
  
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
  
  stardir = Vector(-1, 0.01)

  stars = {}

  for i = 1, 200 do
    stars[i] = Vector(love.math.random(1,WINDOW_WIDTH), love.math.random(1,WINDOW_HEIGHT))
  end
  
  -- janky first generation
  love.keypressed("space")
end

function love.resize(w,h)
  stars = {}
  for i = 1, 200 do
    stars[i] = Vector(love.math.random(1,w), love.math.random(1,h))
  end
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
  {name = "Storage Bay",        wrange={3,9}, hrange={3,9}, colour={0.82675021090650347, 0.1807523156814923, 0.25548658234132504}},
  {name = "Mess Hall",          wrange = {2,3}, hrange={2,3}, colour = {0.3540978676870179, 0.47236376329459961, 0.67900487187065317}},
  {name = "Sleeping quarters",  wrange = {1,2}, hrange={2,5}, colour = {0.57514179487402095, 0.79693061238668306, 0.45174307459403407}},
  {name = "Lounge",             wrange = {2,6}, hrange={2,6}, colour = {0.049609465521796903, 0.82957781845624967, 0.62650828993078767}},
  {name = "Corridor",         wrange={2,7}, hrange={1,2}, colour = {0.3,0.3,0.3}},
  {name = "Corridor",         wrange={1,2}, hrange={2,7}, colour = {0.3,0.3,0.3}},
}

local maxw,maxh = 0,0
for i = 1,#room_types do
  maxw = math.max(maxw, room_types[i].wrange[2])
  maxh = math.max(maxh, room_types[i].hrange[2])
end

MAX_ROOM_SIZE = Vector(maxw,maxh)

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

function new_room(type, random)
  local template = room_types[type]
  local room = {type=type}
  
  local size = Vector(random:random(unpack(template.wrange)), random:random(unpack(template.hrange)))
  if random:random() > 0.5 then
    size.x, size.y = size.y, size.x
  end
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

function roomAdjacency(rooms, random)
  -- 2D array storing the adjacency matrix for each room in the ship
  -- nil = no adjacency, a door object = linked by said door object
  local adjmatrix = {}
  
  -- The list of room id's to merge together
  local to_merge = {}
  
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

            local upperLeft = door.vec1:min(door.vec2)
            local bottomRight = door.vec1:max(door.vec2)

            door.vec1 = upperLeft
            door.vec2 = bottomRight

            adjmatrix[i][j] = door
          end
        end
      end
    end
  end
  
  return adjmatrix, to_merge
end

function mergeRooms(rooms, to_merge, adjmatrix)
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
end

function genRoomsByCrunching(random)
  -- THE GRID
  --
  -- A DIGITAL FRONTIER
  local grid = {}
  local width,height = random:random(10,20), random:random(10, 20)
  
  local rooms = {}
  
  -- Generate one of each of the "required" rooms
  for i = 1, REQUIRED_ROOM_TYPE_OFFSET-1 do
    local index
    repeat
      index = random:random(width*height)
    until rooms[index] == nil
    rooms[index] = new_room(i, random)
  end
  
  -- Fill the remaining space with other room types
  for i = 1,width*height do
    if not rooms[i] then
      rooms[i] = new_room(random:random(REQUIRED_ROOM_TYPE_OFFSET,#room_types), random)
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
  
  -- Generate positions within each grid tile
  -- midx,midy are used to ensure alignment so that grids can collide
  local midx = math.floor(MAX_ROOM_SIZE.x / 2)
  local midy = math.floor(MAX_ROOM_SIZE.y / 2)
  for y = 1,#grid do
    for x = 1, #grid[1] do
      local room = grid[y][x]
      -- This doesn't actually matter because they're getting crammed together anyway...
      local xoff = random:random(math.max(0, midy-room.size.x), math.min(midx - 1, MAX_ROOM_SIZE.x-room.size.x))
      local yoff = random:random(math.max(0, midy-room.size.y), math.min(midy - 1, MAX_ROOM_SIZE.y-room.size.y))
      room.pos = Vector(x*MAX_ROOM_SIZE.x + xoff, y*MAX_ROOM_SIZE.y + yoff)
      
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
  
  return rooms
end

function genRoomsByTetris(random)
  local initialWidth, numRooms = random:random(1,1), random:random(10,20)
  
  local row = {}
  
  local rooms = {}
  
  -- midx,midy are used to ensure alignment so that grids can collide
  local midx = math.floor(MAX_ROOM_SIZE.x / 2)
  local midy = math.floor(MAX_ROOM_SIZE.y / 2)
  
  local collisionView = Geometry:new()
  
  -- Generate a row of rooms to start with
  local xOffset = 1
  local lowestY = 1
  for i = 1, initialWidth do
    local room = new_room(random:random(1, #room_types), random)
    
    
    local randY = random:random(math.max(1, midy-room.size.y), math.min(midy - 1, MAX_ROOM_SIZE.y-room.size.y))
    lowestY = math.max(lowestY, randY)
    room.pos = Vector(xOffset, randY)
    
    --Offset the rooms
    xOffset = xOffset + room.size.x
    
    row[i] = room
    rooms[i] = room
    
    collisionView:add(room.geometry, room.pos)
  end
  
  function calcSurfaceArea(x,y,width, height)
    local sum = 0
    for checkY = y-1, y+height do
      for checkX = x-1, x+width do
        if (checkX < x) or (checkX >= x+width) or (checkY < y) or (checkY >= y+height) then
          if collisionView:get(checkX, checkY) then
            sum = sum + 1
          end
        else 
          if collisionView:get(checkX, checkY) then
            --collision!
            return -1
          end
        end
      end
    end
    
    return sum
  end
  
  for i = 1, numRooms do
    local room = new_room(random:random(1, #room_types), random)
    local shipSize = collisionView:size()
    local initialX = random:random(1, shipSize.x)
    local x = initialX
    local bestSurfaceArea = 0
    local bestPos = Vector(x,shipSize.y+10)
    -- Start from a random X coordinate and iterate mod gridwidth
    for x = initialX, initialX + shipSize.x do
      local modX = x % (shipSize.x)
      for y = shipSize.y+1, 1, -1 do
        local surfaceArea = calcSurfaceArea(modX+1,y,room.size:unpack())
        -- This check is absolutely crucial
        --
        -- Are we trying to tetris, or are we trying to squeeze rooms in as tight as possible?
        -- If trying to squeeze them in as tight as possible then omit this check
        -- This is also means we need to to full collision checks, not just the front edge
         if surfaceArea == -1 then break end
        -- 
        if surfaceArea > bestSurfaceArea then
          bestPos = Vector(modX+1,y)
          bestSurfaceArea = surfaceArea
        end
      end
    end
    room.pos = bestPos - Vector(1,1)
    rooms[#rooms+1]=room
    collisionView:add(room.geometry, room.pos)
  end
  
  return rooms
end

function generate(seed)
  ships = {}
  for i = 1, 20 do
    local ship = Ship:new(seed)
  
    ship:generate()
    
    ship.pos = Vector(love.math.random(-1000, 1000), love.math.random(-1000, 1000))
    ship.vel = Vector(love.math.random(), love.math.random()) * 70
    
    ships[i] = ship
    
    seed = seed + 1
  end
  
  panOffset = -ships[1].center * TILE_WIDTH
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
  end
end
 
-- From https://stackoverflow.com/a/16691908
function overlap(start1,end1,start2,end2)
  return math.max(0, math.min(end1, end2) - math.max(start1, start2))
end

function minDiff(arr1, arr2, dir, offset)
  local mindiff
  local offset = offset or 0
  local offdir = dir == "x" and "y" or "x"
  local overlaps = {}
  for i = 1,#arr1 do
    local current = arr1[i]
    local currentPos = current.pos:clone()
    currentPos[offdir] = currentPos[offdir] + offset
    for j =1,#arr2 do
      local opposite = arr2[j]
      local oppositePos = opposite.pos:clone()
      oppositePos[offdir] = oppositePos[offdir] + offset
      local over = overlap(oppositePos[offdir], oppositePos[offdir]+opposite.size[offdir],
                 currentPos[offdir], currentPos[offdir]+current.size[offdir])
      local diff
      if over > 0 then
        diff = oppositePos[dir] - currentPos[dir] - current.size[dir]        
      else
        diff = 100
      end

      overlaps[diff] = (overlaps[diff] or 0) + over
      if not mindiff then
        mindiff = diff
      else
        mindiff = math.min(mindiff, diff)
      end
    end
  end
  return mindiff, overlaps
end

function merge(arr1, arr2, dir)
  dir = dir or "x"
  local offdir = dir == "x" and "y" or "x"
  
  local bestOffset = 0
  local bestOverlap = 0
  local bestDiff = 0
  for offset = 0, 0 do
    local mindiff, overlaps = minDiff(arr1, arr2, dir, offset)
    
    if overlaps[mindiff] or 0 > bestOverlap then
      bestOffset = offset
      bestOverlap = overlaps[mindiff]
      bestDiff = mindiff
    end
  end
  
  for i = 1, #arr2 do
    arr2[i].pos[dir] = arr2[i].pos[dir] - bestDiff
    arr2[i].pos[offdir] = arr2[i].pos[offdir] + bestOffset
  end
end

--function compress(arr, dir)
--  for i=1,#arr-1 do
--    merge({arr[i]}, {arr[i+1]}, dir)
--  end
--end

function compress(arr, dir)
  dir = dir or "x"
  -- Start from the middle of the rects to avoid bias to one side or the other
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
  local shipSpace = (screenSpace / viewScale) - (panOffset / (viewScale))
  local adjmatrix = ships[1].adjmatrix
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

ELAPSED_TIME = 0
panOffset = Vector()
PAN_SPEED = 150
ENGINE_SPEED = 50
ZOOM_SPEED = 2
viewScale = 3
function love.update(dt)
  ELAPSED_TIME = ELAPSED_TIME + dt
  
  if love.keyboard.isDown("left") then
    panOffset = panOffset + Vector(1, 0) * PAN_SPEED * dt * viewScale
  end
  if love.keyboard.isDown("right") then
    panOffset = panOffset + Vector(-1, 0) * PAN_SPEED * dt * viewScale
  end
  if love.keyboard.isDown("up") then
    panOffset = panOffset + Vector(0, 1) * PAN_SPEED * dt * viewScale
  end
  if love.keyboard.isDown("down") then
    panOffset = panOffset + Vector(0, -1) * PAN_SPEED * dt * viewScale
  end
  
  if love.keyboard.isDown("w") then
    ships[1].vel = ships[1].vel + Vector(0, 1) * ENGINE_SPEED * dt
  end
  if love.keyboard.isDown("s") then
    ships[1].vel = ships[1].vel + Vector(0, -1) * ENGINE_SPEED * dt
  end
  if love.keyboard.isDown("a") then
    ships[1].vel = ships[1].vel + Vector(1, 0) * ENGINE_SPEED * dt
  end
  if love.keyboard.isDown("d") then
    ships[1].vel = ships[1].vel + Vector(-1, 0) * ENGINE_SPEED * dt
  end
  
  if love.keyboard.isDown("=") then
    viewScale = viewScale + ZOOM_SPEED * dt
  end
  if love.keyboard.isDown("-") then
    viewScale = viewScale - ZOOM_SPEED * dt
  end
  
  for i = 1, #ships do
    ships[i].pos = ships[i].pos + ships[i].vel * dt
  end
end

STAR_SPEED = 1/10


function love.draw()
  love.graphics.setColor(1,1,1)
  for n = 1,3 do
    love.graphics.setPointSize(n)
    for i = n, #stars, 3  do
      -- TODO: replace with points(unpack(stars)) and love.translate
      local star = stars[i]
      local drawstar = star + ships[1].pos * STAR_SPEED * n --(stardir * ELAPSED_TIME * n * STAR_SPEED)
--      drawstar = drawstar + Vector(1,1) * n
      drawstar.x = (drawstar.x % (love.graphics.getWidth() + 20)) - 20
      drawstar.y = (drawstar.y % (love.graphics.getHeight() + 20)) - 20
      
      love.graphics.points(drawstar.x, drawstar.y)
    end
  end
  
  love.graphics.push()
  love.graphics.setPointSize(3)
  
  local viewOffset = ships[1].pos + panOffset
  
  love.graphics.translate(love.graphics.getWidth()/2, love.graphics.getHeight()/2)
  
  love.graphics.scale(viewScale)
  
  love.graphics.translate(viewOffset.x, viewOffset.y)
  
  for i = math.floor(#ships/2), math.floor(#ships/2)+#ships do
    i = (i % #ships) + 1
    local ship = ships[i]
    love.graphics.push()
    love.graphics.translate((-ship.pos):unpack())
    ship:draw()
    love.graphics.pop()
  end

  love.graphics.pop()
  
  if DEBUG.seed then
    love.graphics.setColor(1,1,1)
    love.graphics.print("seed = "..tostring(seed), 10, WINDOW_HEIGHT - 20)
  end
  
  if DEBUG.mouse_pos then
    local screenSpace = Vector(love.mouse.getX(), love.mouse.getY())
    local shipSpace = (screenSpace / viewScale) - (panOffset / (viewScale))
    love.graphics.setColor(1,1,1)
    love.graphics.print("screenSpace = "..tostring(screenSpace)..", shipSpace = "..tostring(shipSpace))
  end
  
  if DEBUG.cur_room then
    local screenSpace = Vector(love.mouse.getX(), love.mouse.getY())
    local shipSpace = (screenSpace / viewScale) - (panOffset / (viewScale))
    local id = ship.shipGeometry:get((shipSpace/TILE_WIDTH):ceil())
    love.graphics.setColor(1,1,1)
    love.graphics.print("curRoom = "..tostring(id), 0, 20)
  end
end