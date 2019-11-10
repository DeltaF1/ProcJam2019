local Vector = require "vector"
local md5 = require "md5"
function love.load(arg)
  if arg[#arg] == "-debug" then require("mobdebug").start() end
  
  
  generate(tonumber(md5.sumhexa("foobar4"):sub(1,16),16))
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

room_types = {
  -- Special rooms that aren't chosen by the room generator
  {name = "Helm",               wrange={2,2}, hrange={2,2}, colour = {0.8,0.9,0.1,0.85}},
  -----------------------------
  {name = "Engine",             wrange={2,2}, hrange={2,3}, colour={0.58330589736158589, 0.024793900080875231, 0.83640388831262813,0.85}},
  {name = "Storage Bay",        wrange={3,6}, hrange={3,6}, colour={0.82675021090650347, 0.1807523156814923, 0.25548658234132504,0.85}},
  {name = "Mess Hall",          wrange = {2,3}, hrange={2,3}, colour = {0.3540978676870179, 0.47236376329459961, 0.67900487187065317,0.85}},
  {name = "Sleeping quarters",  wrange = {1,2}, hrange={1,2}, colour = {0.57514179487402095, 0.79693061238668306, 0.45174307459403407,0.85}},
  {name = "Lounge",             wrange = {2,3}, hrange={2,3}, colour = {0.049609465521796903, 0.82957781845624967, 0.62650828993078767,0.85}},
  {name = "Corridor",         wrange={3,10}, hrange={1,2}, colour = {0.2,0.2,0.2,0.85}},
  {name = "Corridor",         wrange={1,2}, hrange={3,10}, colour = {0.2,0.2,0.2,0.85}},
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
  
  grid = {}
  doors = {}
  seed = seed or os.time()
  
  local random = love.math.newRandomGenerator(seed)
  
  local width,height = random:random(1, 4), random:random(1, 4)
  
  function gen_room(type)
    local template = room_types[type]
    local room = {size = Vector(random:random(unpack(template.wrange)), random:random(unpack(template.hrange)))}
    room.colour = template.colour
    room.name = template.name
    
    return room
  end
  
  rooms = {}
  
  local helm_index = random:random(width*height)
  rooms[helm_index] = gen_room(1)

  for i = 1,width*height do
    if not rooms[i] then
      rooms[i] = gen_room(random:random(2,#room_types))
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
  
  -- Door generation
  -- This should segue into 
  for i = 1,#rooms do
    for j = 1,#rooms do
      if i ~= j and rooms[i].name ~= rooms[j].name then
        local vec1, vec2 = adjacency(rooms[i], rooms[j])
        if vec1 then
          local door = {}
          if vec1.x == vec2.x then
            door.vec1 = Vector(vec1.x, random:random(vec1.y, vec2.y-1))
            door.vec2 = door.vec1 + Vector(0,1)
          elseif vec1.y == vec2.y then
            door.vec1 = Vector(random:random(vec1.x, vec2.x-1), vec1.y)
            door.vec2 = door.vec1 + Vector(1,0)
          end
          doors[#doors+1] = door
        end
      end
    end
  end
end

local seed = 1573187624
function love.keypressed()
  seed = seed + 1
  generate(seed)
end

SCALE_FACTOR = 10

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
  
  -- Emergency routine for if mindiff is never found
  if not mindiff then
    print("NO MINDIFF")
    local heighest = GRID_SIZE.y
    local heighestindex = 1
    for i = 1,#arr2 do
      local height = arr2[i].pos[dir]
      if height < heighest then
        heighest = height
        heighestindex = i
      end
    end
    
    local shortest = GRID_SIZE.y
    for i = 1,#arr1 do
      shortest = math.min(shortest, arr1[i].size[dir])
    end
    
    mindiff = arr2[heighestindex].pos[dir] - (arr1[1].pos[dir] + math.floor(shortest/2))
  end
  
  for i = 1, #arr2 do
    arr2[i].pos[dir] = arr2[i].pos[dir] - mindiff
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



function love.draw()
  
  for i = 1,#room_types do
    local template = room_types[i]
    
    love.graphics.setColor(template.colour)
    
    love.graphics.rectangle("fill", 5, i*20, 10, 5)
    love.graphics.print(" - "..template.name, 15, i*20 - 5)
  end
  
  love.graphics.push()
  
  local tl,br
  
  for i = 1,#rooms do
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
  
  local center = tl + (br-tl)/2
  
  center = center * SCALE_FACTOR
  center = Vector(225,150) - center
  
  love.graphics.translate(center.x, center.y)
--  love.graphics.setColor(1,0,0)
--  love.graphics.setPointSize(5)
--  love.graphics.points(center.x, center.y)
  
  for i = 1,#rooms do
    local room = rooms[i]
    love.graphics.setColor(room.colour)
    love.graphics.rectangle("fill", room.pos.x*SCALE_FACTOR, room.pos.y*SCALE_FACTOR, room.size.x*SCALE_FACTOR, room.size.y*SCALE_FACTOR)
  end

  love.graphics.setColor(1,1,1)
  for i = 1, #doors do
    local door = doors[i]
    love.graphics.line(door.vec1.x*SCALE_FACTOR,door.vec1.y*SCALE_FACTOR,door.vec2.x*SCALE_FACTOR,door.vec2.y*SCALE_FACTOR)
  end
  love.graphics.pop()
  
  love.graphics.print("seed = "..tostring(seed), 10, 300)
end