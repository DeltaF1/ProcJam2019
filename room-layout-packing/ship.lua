local Vector = require "vector"

local room_gen = require "room_gen"
local geometry = require "geometry"

local TileGrid = geometry.TileGrid
--local Geometry = geometry.GeometryView

local Ship = {}

Ship.__index = Ship

-- seed, generation type
function Ship:new(seed)
  seed = seed or os.time()
  
  self.random = love.math.newRandomGenerator(seed)
  
  return setmetatable({
    hullSpriteBatch = love.graphics.newSpriteBatch(hullTileAtlas, 100),
    wallSpriteBatch = love.graphics.newSpriteBatch(wallTileAtlas, 100),
    roomChromeSpriteBatch = love.graphics.newSpriteBatch(gridTileset, 100),
    greebleSpriteBatch = love.graphics.newSpriteBatch(greebleAtlas, 100),
    propSpriteBatch = love.graphics.newSpriteBatch(propAtlas, 100),
  }, Ship)
end

function Ship:generateSpriteBatches()
  -- Drawing to spritebatches
  ----------------------------
  self.hullSpriteBatch:clear()
  self.greebleSpriteBatch:clear()
  self.roomChromeSpriteBatch:clear()
  self.wallSpriteBatch:clear()
  self.propSpriteBatch:clear()
  
  
  -- Greebles
  -- TODO: Center greebles that are < TILE_WIDTH wide
  -- TODO: DRY
  -- Add an offset of 1 to generate hull sprites outside of the limits
  local size = self.shipGeometry:size() + Vector(1,1)
  local hullWidth = 2
  for x = 1,size.x+1 do
    for y = 1,size.y+1 do
      if not self.shipGeometry:get(x,y) then
        --empty space for greebles
        if self.random:random() > 0.2 then
          local quad = greebleQuads[self.random:random(#greebleQuads)]
          local _,_,quadWidth,quadHeight = quad:getViewport()
          if self.shipGeometry:get(x+1,y) then
            -- Pointing left
            self.greebleSpriteBatch:add(quad, (x-1)*TILE_WIDTH-(quadHeight-TILE_WIDTH)-hullWidth, (y-1)*TILE_WIDTH+quadWidth, -math.pi/2, 1, 1, 0, 0)
          elseif self.shipGeometry:get(x-1,y) then
            -- Pointing right
            self.greebleSpriteBatch:add(quad, (x-1)*TILE_WIDTH+quadHeight+hullWidth, (y-1)*TILE_WIDTH, math.pi/2, 1, 1, 0, 0)
          elseif self.shipGeometry:get(x,y+1) then
            -- Pointing up
            self.greebleSpriteBatch:add(quad, (x-1)*TILE_WIDTH, (y-1)*TILE_WIDTH-(quadHeight-TILE_WIDTH)+hullWidth, 0, 1, 1, 0, 0)
          elseif self.shipGeometry:get(x,y-1) then
            -- Pointing down
            self.greebleSpriteBatch:add(quad, (x-1)*TILE_WIDTH+quadWidth, (y-1)*TILE_WIDTH+quadHeight-hullWidth, math.pi, 1, 1, 0, 0)
          end
        end
      end
    end
  end
  
  -- Hull walls
  
  -- Make a geometry object that returns true for empty space
  local shipGeometry = self.shipGeometry
  invGeometry = {
    get = function(self, x,y)
      return not shipGeometry:get(x,y)
    end
  }
  setmetatable(invGeometry, {__index=shipGeometry})
  
  floorQuad = love.graphics.newQuad(80,122,16,16,96,128)
  
  for x = 1, size.x do
    for y = 1, size.y do
      if invGeometry:get(x,y) then 
        local quad = tileset:getQuad(invGeometry,x,y)
        if quad then
          self.hullSpriteBatch:add(quad, (x-1)*TILE_WIDTH, (y-1)*TILE_WIDTH)   
        end
      else
        -- Generate the blank floor tiles
        local quad = floorQuad
        self.hullSpriteBatch:add(quad, (x-1)*TILE_WIDTH, (y-1)*TILE_WIDTH)
      end
    end
  end
  
  local rooms = self.rooms
  local adjmatrix = self.adjmatrix
  -- Rooms
  -- generate the "chrome" (room type highlights) and "walls" (the gray walls showing room boundaries
  for i = 1,#rooms do
    local room = rooms[i]
    
    -- A geoemtry object that treats doorways as an extra tile set to true
    local doorGeometry = {
      get = function(self, x, y)
        local pos = Vector.isvector(x) and x or Vector(x,y)
        for j = 1, #rooms do
          door = adjmatrix[i][j]
          if door then
            local vec1 = door.vec1 - room.pos + Vector(1,1)
            if door.vec1.x == door.vec2.x then
              if (pos == vec1 - Vector(1,0)) or (pos == vec1) then return "d" end
            else
              if (pos == vec1 - Vector(0,1)) or (pos == vec1) then return "d" end
            end
          end
        end
        return room.geometry:get(pos)
      end
    }
    
    setmetatable(doorGeometry, {__index=room.geometry})
    
    if room then
      self.roomChromeSpriteBatch:setColor(room.colour[1], room.colour[2], room.colour[3], 0.5)
      self.wallSpriteBatch:setColor(0.3, 0.3, 0.3)
      local size = room.geometry:size()
      for x = 1, size.x do
        for y = 1, size.y do
          if room.geometry:get(x,y) then 
            local quad = tileset:getQuad(doorGeometry,x,y)
            if quad then
              self.roomChromeSpriteBatch:add(quad, (room.pos.x+x-1)*TILE_WIDTH, (room.pos.y+y-1)*TILE_WIDTH)
              self.wallSpriteBatch:add(quad, (room.pos.x+x-1)*TILE_WIDTH, (room.pos.y+y-1)*TILE_WIDTH)
            end
          end
        end
      end
    end
  end
  
  -- Props
  for i = 1, #rooms do
    local room = rooms[i]
    
    local size = room.geometry:size()
    
    -- Generate a room layout in some fashion
    props = room_gen.generate(room)
    
    -- Place each prop on the prop spritebatch layer
    for i = 1, #props do
      local prop = props[i]
      local position = prop.position
      position = position + room.pos - Vector(1,1)
      
      position = position * TILE_WIDTH
      
      position = position + prop.offset
      
      self.propSpriteBatch:add(prop.quad, position.x, position.y, prop.angle, 1, 1)
    end
  end
end

function Ship:draw()
  love.graphics.setColor(1,1,1)
  
  love.graphics.draw(self.greebleSpriteBatch)
  
  love.graphics.draw(self.hullSpriteBatch)
  love.graphics.draw(self.roomChromeSpriteBatch)
  love.graphics.draw(self.wallSpriteBatch)
  love.graphics.draw(self.propSpriteBatch)
  
  for i = 1, #self.rooms do
    for j = i, #self.rooms do
      local door = self.adjmatrix[i][j]
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
      end
    end
  end
  
  if DEBUG.rect_bounds then
    love.graphics.setColor(1,0,0)
    for i = 1,#self.rects do
      local rect = self.rects[i]
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
    local size = self.shipGeometry:size()
    for x = 1, size.x do
      for y = 1, size.y do
        if propgeometry:get(x,y) then
          love.graphics.rectangle("fill", (x-1)*TILE_WIDTH, (y-1)*TILE_WIDTH, TILE_WIDTH, TILE_WIDTH)
        end
      end
    end
  end
end

local function centerRooms(rooms)
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
  
  local center = (br-tl)/2
  
  local tl = tl - Vector(1,1)
  
  -- Offset rooms so that they are relative to the top left
  for i = 1, #rooms do
    rooms[i].pos = rooms[i].pos - tl
  end
  
  return center
end

function Ship:generate(seed)
  self.rooms = genRoomsByTetris(self.random)
  
  self.center = centerRooms(self.rooms)
  
  -- Calculate adjacency matrix for all the rooms
  self.adjmatrix, to_merge = roomAdjacency(self.rooms, self.random)
  
  -- FIXME: For debugging
  self.rects = {}
  
  for i = 1, #self.rooms do
    self.rects[#self.rects+1] = {self.rooms[i].pos:clone(), self.rooms[i].size:clone()}
  end
  
  -- NOW LEAVING THE GRID
  --
  -- Combine rooms that are adjacent and of the same type
  mergeRooms(self.rooms, to_merge, self.adjmatrix)
  
  -- Store the geometry of the spaceship as a whole
  --
  -- Useful for hull generation, as well as a fast lookup for room collision detection
  self.shipGeometry = TileGrid:new()
  
  for id, room in ipairs(self.rooms) do
    local size = room.geometry:size()
    for x = 1, size.x do
      for y = 1, size.y do
        if room.geometry:get(x, y) then
          self.shipGeometry:set(x+room.pos.x, y+room.pos.y, id)
        end
      end
    end
  end

  self:generateSpriteBatches()
end


return {Ship = Ship}