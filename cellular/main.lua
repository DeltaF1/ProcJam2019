
WIDTH = 100
HEIGHT = 100

GRID_SCALE = 5 -- px

REFRESH_RATE = 0.1 -- s

steps = 0
MAX_STEPS = 2

convMap = {}

liveColour = {0.6,1,1}
deadColour = {0.1,0.1,0}

function setGrid(grid,x,y,value)
  if x < 1 or x > WIDTH or y < 1 or y > HEIGHT then error("invalid coords passed to setGrid") end
  if value == nil then value = 1 end
  
  if not grid[x] then grid[x] = {} end
  
  grid[x][y] = value
end

function getGrid(grid,x,y)
  if x < 1 or x > WIDTH then return 0 end
  if y < 1 or y > HEIGHT then return 0 end
  if grid[x] then
    return grid[x][y] or 0
  else
    return 0
  end
end

function love.load(arg)
  if arg[#arg] == "-debug" then require("mobdebug").start() end
  
  initGrid()
end

function initGrid(chance)
  chance = 0.4
  grid = {}
  for x = 1, WIDTH do
    for y = 1,HEIGHT do
      if love.math.random() < 0.4 then
        setGrid(grid, x, y)
      end
    end
  end
  
end

total = 0

function love.update(dt)
  if steps >= MAX_STEPS then return end
  
  total = total + dt
  
  while total >= REFRESH_RATE do
    total = total - REFRESH_RATE
    
    
    grid = advanceCells()
    
    steps = steps + 1
  end
end

function neighbours(x,y)
  return {x-1,y+1, x,y+1, x+1,y+1,
          x-1,y,   x,y,   x+1,y,
          x-1,y-1, x,y-1, x+1,y-1}
end

function convMatch(grid1, grid2)
  local total = 0
  for x = 1, #grid1 do
    for y = 1, #grid1[1] do
      total = total + (grid1[x][y])*(grid2[x][y])
    end
  end
  return total
end

function rotateConvMatch(grid1, grid2)
  
end

xLine = {{0,0,0},
         {1,1,1},
         {0,0,0}}
          
yLine = {{0,1,0},
         {0,1,0},
         {0,1,0}}

function advanceCells()
  local newGrid = {}
  convMap = {}
  for x = 1,WIDTH do
    for y = 1,HEIGHT do
      local cell = getGrid(grid, x, y)
      local neighbourhood = {}
      local neighbourCoords = neighbours(x,y)
      local total = 0
      for i=1,(#neighbourCoords/2) do
        local neighbourx,neighboury = neighbourCoords[(2*i)-1], neighbourCoords[2*i]
        local neighbourval = getGrid(grid, neighbourx, neighboury)
        total = total + neighbourval 
        setGrid(neighbourhood, neighbourx-x + 2 , neighboury-y + 2, neighbourval)
      end
      local neighbourtotal = total - cell
      local conv = convMatch(neighbourhood, xLine)
      setGrid(convMap,x,y,total)
--      if (
----      if ((total == 3 and convMatch(neighbourhood, xLine) == 3 ) or
----         (total == 3 and convMatch(neighbourhood, yLine) == 3 ) or
--         (convMatch(neighbourhood, {{1,0,1},{1,0,1},{1,0,1}}) < 2))
       
--         then
--          setGrid(newGrid, x,y)
--      end
    -- game of life
      if (cell == 0 and neighbourtotal > 4) or (cell == 1 and neighbourtotal > 3) then
        setGrid(newGrid, x, y)
      end
    end
  end
  
  return newGrid
end

function love.draw()
    for x=1,WIDTH do
      for y=1,HEIGHT do
        cell = getGrid(grid,x,y)
        if cell > 0 then
          love.graphics.setColor(liveColour)
        else
          love.graphics.setColor(deadColour)
        end
        love.graphics.rectangle("fill", 50+(x*GRID_SCALE), 50+(y*GRID_SCALE), GRID_SCALE, GRID_SCALE)
      end
    end
end

function love.keypressed()
  initGrid()
  steps = 0
  liveColour = {love.math.random(),love.math.random(),love.math.random()}
end