local Vector = require "vector"
local Geometry = require "geometry"
local bit = require "bit"

-- Created by following https://gamedevelopment.tutsplus.com/tutorials/how-to-use-tile-bitmasking-to-auto-tile-your-level-layouts--cms-25673

-- This bitmask to tile number mapping is only valid for the tileset I constructed. Consider rearranging the tileset to match some standard pattern
local bitmask_to_tile = {
  [208] = 1, [214] = 2, [22] = 3, [80] = 4,  [66] = 5, [18] = 6,
  [248] = 7, [255]= 8,  [31] = 9, [24] = 10, [0]=11,   [250] = 12,
  [104] = 13,[107] = 14,[11] = 15,[72] = 16, [95] =17, [10]=18,
  [127] = 19,[16] = 20, [251]=21, [120]=22,  [27]=23,  [75]=24,
  [64] =25,  [90]=26,   [2]=27,   [216]=28,  [30]=29,  [106]=30,
  [223]=31,  [8]=32,   [254]=33,  [86]=34,   [210]=35, [82]=36,
  [94]=37,   [218]=38, [123]=39,  [126]=40,  [219]=41, [74]=42,
  [91]=43,   [122]=44, [222]=45,  [88]=46,   [26]=47,  [-1]=48,
}

local function print_binary(number, bits)
  local s = ""
  for i = 1, bits do
    s = (bit.band(number, 1) == bit.tobit(0) and "0" or "1")..s
    number = bit.rshift(number,1)
  end
  return s
end

local function checkbit(number, idx)
  return bit.band(number, bit.lshift(1, idx)) ~= 0
end



--local function love.load()
--  if arg[#arg] == "-debug" then require("mobdebug").start() end
--  love.graphics.setDefaultFilter("nearest", "nearest")
--  square = {
--    {1,1,1,1,1},
--    {1,1,1,1,1},
--    {1,1,nil,1,1},
--    {1,1,1,1,1},
--    {1,1,1,1,1},
--    {nil,nil,nil,1},
--    {nil, 1, nil,},
--    {1,   1, 1,1,1,1},
--    {nil, 1, nil,nil,1},
--    {nil, nil, nil,1,1},
--    }

--  geometry = Geometry(square)
  
--  tileset = love.graphics.newImage("tileset.png")
  
--  quads = {}
  
--  WIDTH, HEIGHT = tileset:getDimensions()
--  for y = 0,HEIGHT/16-1 do
--    for x = 0,WIDTH/16-1 do
--      quads[#quads+1] = love.graphics.newQuad(x*16, y*16, 16, 16, tileset:getDimensions())
--    end
--  end
  
--  spriteBatch = love.graphics.newSpriteBatch(tileset, #quads)
  

--end

--local function love.draw()
--  --spriteBatch:clear()
--  local size = geometry:size()
--  for x = 1, size.x do
--    for y = 1, size.y do
--      if geometry:get(x,y) then 
--        local index = getTileIndex(geometry,x,y)
--        if quads[bitmask_to_tile[index]] then
--          love.graphics.draw(tileset, quads[bitmask_to_tile[index] or 1], x*16*4, y*16*4, 0, 4, 4)   
--        end
--        love.graphics.print(index, x*64+32, y*64+32)
--      end
--    end
--  end
-- -- love.graphics.draw(spriteBatch, 0, 0, 0, 4, 4)
--end

--local function love.mousepressed(x,y)
--  gridpos = Vector(math.floor(x/64), math.floor(y/64))
  
--  print(gridpos)
  
--  if not square[gridpos.x] then
--    square[gridpos.x] = {}
--  end
--  square[gridpos.x][gridpos.y] = not geometry:get(gridpos)
--end

local TileSet = {}

TileSet.__index = TileSet

function TileSet.new(cls, imwidth, imheight, tile_width)
  local self = {}
  
  self.quads = {}

  for y = 0,imheight/tile_width-1 do
    for x = 0,imwidth/tile_width-1 do
      self.quads[#self.quads+1] = love.graphics.newQuad(x*tile_width, y*tile_width, tile_width, tile_width, imwidth, imheight)
    end
  end
  
  return setmetatable(self, cls)
end

function TileSet:getQuad(geometry, x, y)
  return self.quads[self:getTileIndex(geometry,x,y)]
end

function TileSet:getTileIndex(geometry,x,y)
  --[[
  Return the tile index (1->47 on a 6x8 tile layout) of a position on a piece of geometry
  ]]--
  local power = 0
  local adjacencyBitmask = 0
  local tileType = geometry:get(x,y)
  for neighbourX = x-1, x+1 do
    for neighbourY = y-1, y+1 do
      if not (neighbourX == x and neighbourY == y) then
        if geometry:get(neighbourX, neighbourY) then
          adjacencyBitmask = bit.bor(adjacencyBitmask, bit.lshift(1, power))
        end
        power = power + 1
      end
    end
  end
  
  --[[
  0   3   5
  1       6
  2   4   7
  
  Mask out the corners if one of their adjacent cardinals (NESW) is empty.
  This step reduces complexity down to 47 tiles
  
  If index 1 is empty, then corners 0 and 2 are not valid for checking

                           7654 3210   
  if not 1 -> quadIndex &= 1111 1010 (0xfa)
  if not 3 -> quadIndex &= 1101 1110 (0xde)
  if not 4 -> quadIndex &= 0111 1011 (0x7b)
  if not 6 -> quadIndex &= 0101 1111 (0x5f)
  ]]--
  

  if not checkbit(adjacencyBitmask, 1) then 
    adjacencyBitmask = bit.band(adjacencyBitmask, bit.tobit(0xfa))
  end
  if not checkbit(adjacencyBitmask, 3) then
    adjacencyBitmask = bit.band(adjacencyBitmask, bit.tobit(0xde))
  end
  if not checkbit(adjacencyBitmask, 4) then
    adjacencyBitmask = bit.band(adjacencyBitmask, bit.tobit(0x7b))
  end
  if not checkbit(adjacencyBitmask, 6) then
    adjacencyBitmask = bit.band(adjacencyBitmask, bit.tobit(0x5f))
  end
  
  -- Return the tile number for this bitmask
  return bitmask_to_tile[adjacencyBitmask]
end

return setmetatable(TileSet, {
  __call = TileSet.new,
})