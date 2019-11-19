local Vector = require "vector"

local GeometryView = {}

GeometryView.__index = GeometryView

function GeometryView.new(cls, raw)
  -- list of {offset, view}
  local o = {}
  setmetatable(o, GeometryView)
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
end

local function _get(geometry, pos)
  if getmetatable(geometry) == GeometryView then
    return geometry:get(pos)
  else
    return (geometry[pos.x] or {})[pos.y]
  end
end

local function _size(geometry)
  if getmetatable(geometry) == GeometryView then
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

return setmetatable({}, {
    __call = GeometryView.new
})