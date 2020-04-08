local Vector = require "vector"

local TileGrid = {}

TileGrid.__index = TileGrid

function TileGrid.new(cls, raw)
  local o = raw or {}
  setmetatable(o, cls)
  
  if o[1] then
    local h = #o[1]
    for i = 2,#o do
      if o[i] then
        h = math.max(h, #o[i])
      end
    end
    o._size = Vector(#o, h)
  else
    o._size = Vector()
  end

  return o
end

function TileGrid:get(x, y)
  if Vector.isvector(x) then x,y = x.x, x.y end
    
  return self[x] and self[x][y] or nil
end

function TileGrid:set(x, y, value)
  if Vector.isvector(x) then x,y,value = x.x, x.y, y end
  
  self[x] = self[x] or {}
  self[x][y] = value

  self._size = self._size:max(Vector(x,y))
end

function TileGrid:size()
  return self._size
end

local GeometryView = {}

GeometryView.__index = GeometryView

function GeometryView.new(cls, raw)
  -- list of {offset, view}
  local o = {}
  setmetatable(o, cls)
  o.geometries = {}
  
  if raw then
    o.geometries[1] = {Vector(), raw}
  end
  
  return o
end

function GeometryView:add(geometry, offset)
  offset = offset or Vector()
  table.insert(self.geometries, {offset, geometry})
  
  local origin_shift = Vector()
  if offset.x < 0 then origin_shift.x = offset.x end
  if offset.y < 0 then origin_shift.y = offset.y end
  
  if origin_shift ~= Vector() then
    for _, entry in ipairs(self.geometries) do
      entry[1] = entry[1] - origin_shift
    end
  end
  return origin_shift
end

local function _get(geometry, pos)
  if geometry.get then
    return geometry:get(pos)
  else
    return (geometry[pos.x] or {})[pos.y]
  end
end

local function _size(geometry)
  if geometry.size then
    return geometry:size()
  else
    return Vector(#geometry, #geometry[1])
  end
end

function GeometryView:get(x,y)
  if not Vector.isvector(x) then x = Vector(x,y) end
  local pos = x
  local value = nil
  for _, entry in ipairs(self.geometries) do
    local offset, geometry = unpack(entry)
    if pos >= offset and pos <= offset + _size(geometry) then
      local off = pos - offset 
      value = value or _get(geometry, off)
    end
    if value then break end
  end
  
  return value
end

function GeometryView:size()
  local size = Vector()
  
  for _, entry in ipairs(self.geometries) do
    local val = entry[1]+_size(entry[2])
    size = size:max(val)
  end
  return size
end

function GeometryView.print(view)
  local size = view:size()
  local s = ""
  for y = 0, size.y do
    local row = ""
    for x = 0, size.x do
      row = row .. tostring(view:get(x,y) or " ")
    end
    s = s .. row .. "\n"
  end
  return s
end

--local function _set(geometry, pos, value)
--  if getmetatable(geometry) == GeometryView then
--    return geometry:set(x,y,value)
--  else
--    geometry[x] = geometry[x] or {}
--    geometry[x][y] = value
--    return True
--  end
--end

--function GeometryView:set(x,y,value)
--  if not Vector.isvector(x) then
--    x = Vector(x,y)
--    value = y
--  end
--  local pos = x
  
--  --flag to see if a new geometry needs to be added
--  local modified
--  for i =1,#self.geometries do
--    local offset, geometry = unpack(self.geometries[i])
--    if pos >= offset and pos <= offset + _size(geometry) then
--      local off = pos - offset 
--      if _set(geometry, off, value) then
--        modified = true
--        break
--      end
--    end
--  end
  
--  -- If none of our target geometries are in the scope of the position
--  -- And if the value isn't nil, otherwise we'd be trying to clear an already clear position
--  -- Add a new geometry
--  -- This is getting rid of all of the benefits of a table index look up...
--  if not modified and value ~= nil then
--    self:add({value}, pos)
--  end
--end

--square = {  
--  {1, 1},
--  {1, 1},
--}

--rectangle = {
--  {2, 2, 2, 2, 2, 2},
--  {2, 2, 2, 2, 2, 2},
--}

--view = Set.new(square)

--view:add(rectangle, Vector(1,-3))

--for y = 1,10 do
--  local s = ""
--  for x = 1,4 do
--    s = s..(view:get(x, y) or "_")
--  end
--  print(s)
--end

return {TileGrid = TileGrid, GeometryView = GeometryView}