local Vector = require "vector"
io.stdout:setvbuf('no')
ANCHOR_TYPES = {
  {"source", colour={1,1,1}},
  {"sink", colour={1,0,0}},
  {"sink", colour={1,1,0}},
  {"sink", colour={1,0,1}},
  {"sink", colour={0,0,1}},
  {"sink", colour={0,1,1}},
}


Anchor = {}

Anchor.__index = Anchor

function newAnchor(pos, type)
  local anchor = setmetatable({type=type}, Anchor)
  anchor:setPos(pos)
  return anchor
end

TOLERANCE = 0.20

function Anchor:setPos(pos)
  -- round 
  local rounded = pos:floor()
  local diff = rounded-pos
  pos = rounded
  if math.abs(diff.x) >= 0.5-TOLERANCE and math.abs(diff.x) <= 0.5+TOLERANCE then
    pos.x = pos.x + 0.5
  elseif math.abs(diff.x) > 0.5+TOLERANCE then
    pos.x = pos.x + 1
  end
  
  if math.abs(diff.y) >= 0.5-TOLERANCE and math.abs(diff.y) <= 0.5+TOLERANCE then
    pos.y = pos.y + 0.5
  elseif math.abs(diff.y) > 0.5+TOLERANCE then
    pos.y = pos.y + 1
  end
  
  self.pos = pos
end

function love.load()
  if arg[#arg] == "-debug" then require("mobdebug").start() end

  love.graphics.setDefaultFilter("nearest", "nearest")
  image = love.graphics.newImage("assets/tile1.png")
  anchorImage = love.graphics.newImage("anchor.png")
  highlightImage = love.graphics.newImage("anchor_highlight.png")
  point = Vector(8.5,8.5)
  
  scale = 10
  
  anchors = {newAnchor(Vector(7.5,7.5), 1)}
  curAnchor = 1
end

PROXIMITY = 1

function love.mousepressed(x,y,button)
  local imagePos = (Vector(x,y) - offset)/scale
  if button == 1 then
    local switched = false
    
    -- This code is broken up into 2 for loops so that you can cycle through anchors that are overlapping
    for i = curAnchor+1,#anchors do
      local anchor = anchors[i]
      if anchor.pos:dist(imagePos) < PROXIMITY then
        curAnchor = i
        switched = true
        break
      end
    end
    if not switched then
      for i = 1,curAnchor do
        local anchor = anchors[i]
        if anchor.pos:dist(imagePos) < PROXIMITY then
          curAnchor = i
          break
        end
      end
    end
  elseif button == 2 then
    local point = imagePos - Vector(0.5,0.5)
    anchors[curAnchor]:setPos(point)
    print(anchors[curAnchor].pos.x, anchors[curAnchor].pos.y)
  end
end

function love.keypressed(key)
  if key == "a" then
    local anchor = newAnchor((Vector(love.mouse.getX(), love.mouse.getY()) - offset)/scale - Vector(0.5,0.5), love.math.random(#ANCHOR_TYPES))
    anchors[#anchors+1] = anchor
    curAnchor = #anchors
  elseif key == "r" or key == "delete" then
    table.remove(anchors, curAnchor)
    curAnchor = curAnchor - 1
  end
end

function love.wheelmoved(x,y)
  scale = scale + y
end

function love.draw()
  love.graphics.push()
  offset = (Vector(love.graphics.getWidth(), love.graphics.getHeight()) - Vector(image:getWidth(), image:getHeight())*scale)/2
  love.graphics.translate(offset:unpack())
  love.graphics.scale(scale)
  love.graphics.setColor(1,1,1)
  love.graphics.draw(image)


  
  for i = 1,#anchors do
    if i ~= curAnchor then
      local anchor = anchors[i]
      love.graphics.setColor(ANCHOR_TYPES[anchor.type].colour)
      love.graphics.draw(anchorImage, anchor.pos.x, anchor.pos.y, 0,1/3,1/3,1,1)
    end
  end
  
  -- Always draw the selected anchor on top
  if curAnchor > 0 then
    local anchor = anchors[curAnchor]
    love.graphics.setColor(ANCHOR_TYPES[anchor.type].colour)
    love.graphics.draw(anchorImage, anchor.pos.x, anchor.pos.y, 0,1/3,1/3,1,1)
    love.graphics.setColor(1,1,1)
    love.graphics.draw(highlightImage, anchor.pos.x, anchor.pos.y, 0, 1/3,1/3,2,2)
  end
  
  love.graphics.pop()
  
  for x = 1, 256 do
    love.graphics.line(x*scale,0,x*scale,256*scale)
    for y = 1, 256 do
      love.graphics.line(0,y*scale,256*scale,y*scale)
    end
  end
  
  love.graphics.setColor(1,0,0)
  love.graphics.line(love.graphics.getWidth()/2, 0, love.graphics.getWidth()/2, love.graphics.getHeight())
  love.graphics.line(0, love.graphics.getHeight()/2, love.graphics.getWidth(), love.graphics.getHeight()/2)
  
  love.graphics.print(love.mouse.getX()..","..love.mouse.getY())
  local point = (Vector(love.mouse.getX(),love.mouse.getY()) - offset)/scale
  love.graphics.print(point.x..","..point.y,0,10)
  point = point + Vector(0.5,0.5)
  love.graphics.print(point.x..","..point.y,0,20)
end