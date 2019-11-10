--local layout = {
--  [0] = {name="Helm", connected={down=1,left=2,right=3}},
--  [1] = {name="Engine", connected={left=2,right=3}},
--  [2] = {name="Quarters", connected={}},
--  [3] = {name="Storage", connected={}}
--}

--local rooms = {}

--for i,template in ipairs(layout) do
--  local room = {name=template.name}
--  if i == 1 then
--    room.x,room.y = 100,100
--  end


--  rooms[i] = room
--end

--function love.draw()
--  for _,room in ipairs(rooms) do
--    love.graphics.print(room.name, room.x, room.y)
--  end
--end

local Vector = require("vector")



--calculate distance between each quadrant

--create linkages between the positions

--for N iterations:
--  update sub_position (on an integer grid for consistent results) based on:
--    - The length of a linkage (some sort of curve centered around the optimal distance
--    - The weight of a room


MICRO_DISPLAY_SIZE = 1 -- px

MICRO_GRID_SIZE = 100


local rooms = {}

local layout = {
  {name="Helm", weight=20},     false,                      false, false, {name="EngineA", weight=1}, {name="Engine", weight=100},
  {name="Quarters", weight=100}, {name="Storage", weight=1}, false, false, {name="EngineB", weight=1}, {name="EngineC", weight=20},
  false,                       false                     , false, false, false,                       false,
  false,                       false                     , {name="Mess hall", weight=1}, {name="FooBar", weight=1}, false,                       false,
}
local width,height = 6,4

assert(width*height == #layout)

function index2xy(index, width)
  local x = (index-1) % width + 1
  local y = math.floor((index-1)/width) + 1

  return x,y
end

function xy2index(x, y, width)
  if x < 1 or y < 1 or x > width then return -1 end
  return x + width*(y-1)
end

function neighbours_moore(x,y)
  local coords = {{x-1,y+1}, {x, y+1}, {x+1,y+1},
    {x-1,y},               {x+1,y},
    {x-1,y-1}, {x, y-1}, {x+1,y-1}
  }

  return coord_iter(coords)
end

function neighbours_von_neumann(x,y)
  local coords = {        {x, y+1},
    {x-1,y},         {x+1,y},
    {x, y-1}
  }

  return coord_iter(coords)
end

function coord_iter(coords)
  local i = 0
  return function()
    i = i + 1
    if i <= #coords then 
      local coord = coords[i]
      return coord[1], coord[2]
    end
  end
end

function dist(x1,y1,x2,y2)
  return math.sqrt(math.pow(x1-x2, 2) + math.pow(y1-y2, 2))
end

function love.load(arg)
  if arg[#arg] == "-debug" then require("mobdebug").start() end
  for i,room in ipairs(layout) do
    if room then
      local x,y = index2xy(i, width)
      room.pos = Vector(x * MICRO_GRID_SIZE, y * MICRO_GRID_SIZE)
    end
    rooms[i] = room
  end

  -- Link generation step

  links = {}
  -- Store which rooms have already been fully linked
  local linked = {}

  for curIndex = 1,#rooms do
    if rooms[curIndex] then
      -- Breadth first search to find other rooms to 
      local visited = {}
      local to_visit = {curIndex}
      while #to_visit > 0 do
        local unvisited = table.remove(to_visit)
        -- If this is an empty space or
        -- If this is the starting space (special case to kickstart the search)
        if rooms[unvisited] == false or unvisited == curIndex then
          -- Add all neighbours to the search space
          for x,y in neighbours_von_neumann(index2xy(unvisited,width)) do
            local neighbourIndex = xy2index(x,y,width)
            if neighbourIndex >= 1 and neighbourIndex <= width*height then
              if not visited[neighbourIndex] then              
                table.insert(to_visit, neighbourIndex)
              end
            end
          end
          -- If we haven't already visited this index on our current BFS and
          -- If this room hasn't already linked to every valid room (including the current room)
        elseif not visited[unvisited] and not linked[unvisited] then
          local a = rooms[curIndex]
          local b = rooms[unvisited]
          local link = {["a"]=a,["b"]=b, sweetspot=a.pos:dist(b.pos)-math.abs(a.weight-b.weight)}
          links[#links+1] = link
        end
        -- Add to visited set for BFS
        visited[unvisited] = true
      end
    end
    -- Linking is complete for this index
    linked[curIndex] = true
  end

  print(links)

  for i = #rooms,1,-1 do
    if not rooms[i] then table.remove(rooms, i)
    else
      rooms[i].force = Vector()
      rooms[i].vel = Vector()
    end
  end
end

local k = 1/100
function calculate_force(link)
  local a,b = link.a, link.b
  local dist = (a.pos:dist(b.pos))

  return (dist - link.sweetspot) * k
end

local elapsed = 0
local iterations = 0
local MAX_SIMULATION_STEPS = 1500
local iteration_speed = 0.01

function love.update(dt)
  elapsed = elapsed + dt
  while elapsed >= iteration_speed do
    elapsed = elapsed - iteration_speed

    if iterations < MAX_SIMULATION_STEPS then
      iterations = iterations + 1
      for _,link in ipairs(links) do
        local f = calculate_force(link)
        local a,b = link.a, link.b

        a.force = a.force or Vector()
        b.force = b.force or Vector()

        local direction = (b.pos - a.pos):normalizeInplace()
        a.force = a.force + direction * f
        b.force = b.force + direction * f * -1
      end

      for i = 1,#rooms do
        -- update position based on force and weight
        local room = rooms[i]
        local dampingFactor = 0.05
        room.force = room.force * (1 - dampingFactor)
        room.pos = room.pos + (room.force / room.weight)
--        room.pos = room.pos + room.vel
        --room.pos = Vector(math.floor(room.pos.x), math.floor(room.pos.y))

      end

 
    end
  end
end

--local links = {}

--local linked = {}

---- First calculate the grid distance between all closest non-empty rooms
--for curIndex = 1,#rooms do
--  if rooms[curIndex] then
--    local y = math.floor((curIndex-1)/width) + 1
--    local x = (curIndex-1) % width + 1

--    --  breadth first search to find other rooms
--    local visited = {}
--    local to_visit = {curIndex}
--    while #to_visit > 0 do
--      for _,unvisited in to_visit do
--        if rooms[curIndex] == false or unvisited == curIndex then
--          for x,y in neighbours(index2xy(unvisited,width)) do
--            local neighbourIndex = xy2index(x,y,width)
--            if not visited[neighbourIndex] then              
--              table.insert(to_visit, neighbourIndex)
--            end
--          end
--        elseif linked[unvisited] then
--          -- do nothing, we're already linked to it
--        else
--          local a = rooms[curIndex]
--          local b = rooms[unvisited]
--          links[#links+1] = {a=a,b=b, factor=max(a.weight, b.weight)}
--        end
--        visited[unvisited] = true
--      end
--    end
--  end
--  linked[curIndex] = true
--end

--print(links)

--function calculate_force(link)
--  local dist = a - b

----  some function (dist) * factor
--end

--MAX_SIMULATION_STEPS = 3
--for i = 1, MAX_SIMULATION_STEPS do
--  for _,link in ipairs(links) do
--    local f = calculate_force(link)
--    a.force = f
--    b.force = f * -1
--  end

--  for i = 1,#rooms do
----    update position based on force and weight
--  end
--end

function love.draw()
  love.graphics.setColor(1,0,0)
--  for x = 1,width do
--    for y = 1,height do
--      mode = rooms[xy2index(x,y,width)] and "fill" or "line"
--      love.graphics.rectangle(mode, (x-1)*MICRO_GRID_SIZE*MICRO_DISPLAY_SIZE, (y-1)*MICRO_GRID_SIZE*MICRO_DISPLAY_SIZE, MICRO_GRID_SIZE*MICRO_DISPLAY_SIZE, MICRO_GRID_SIZE*MICRO_DISPLAY_SIZE)
--    end
--  end
  love.graphics.push()
  love.graphics.scale(MICRO_DISPLAY_SIZE)
  for i = 1,#links do
    local link = links[i]
    love.graphics.setLineWidth(1)
    love.graphics.line(link.a.pos.x, link.a.pos.y, link.b.pos.x, link.b.pos.y)
  end

  love.graphics.setColor(1,1,1)
  for _,room in ipairs(rooms) do
    -- Eventually this check can be removed. After the force simulation any empty rooms can be removed
    if room then
      love.graphics.print(room.name, room.pos.x, room.pos.y)
      love.graphics.setLineWidth(2)
      local fv = room.pos + (room.force*1000)
      love.graphics.line(room.pos.x, room.pos.y, fv.x, fv.y)
    end
  end
  love.graphics.pop()
end