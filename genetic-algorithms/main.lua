local function IntDataType(min, max)
  if not min then
    
  elseif not max then
    max = min
    min = 1
  end
  
  return {
    random = function(seed)
      return math.floor(seed * (max - min + 1)) + min
    end
  }
end

local function CharDataType(chars)
  
  return {
    random = function(seed)
      seed = math.ceil(seed * #chars)
      return chars[seed]
    end
  }
end

local Genome = {}

Genome.__index = Genome

function Genome.__tostring(self)
  s = "[ "
  for i = 1, #self do
    s = s .. tostring(self[i]) .. " "
  end
  return s.."]"
end

function Genome:new(...)
  local o = {dataTypes = {...}}
  
  return setmetatable(o, self)
end

function Genome:clone()
  local new = Genome:new(unpack(self.dataTypes))
  for i, item in ipairs(self) do
    new[i] = item
  end
  return new
end

function Genome:mutate(rate, random)
  for i = 1, #self do
    if math.random() < rate then
      local idx = i % #self.dataTypes
      if idx == 0 then idx = #self.dataTypes end
      local dataType = self.dataTypes[idx]
      self[i] = dataType.random(math.random())
    end
  end
  
  return self
end

function Genome:mutated(rate, random)
  return self:clone():mutate(rate)
end

function Genome:cross(genome2, rate)
  local which = love.math.random() > 0.5
  for i = 1, #self do
    if math.random() < rate then which = not which end
    self[i] = which and self[i] or genome2[i]
  end
  
  return self
end

function Genome:crossover(genome2)
  local genome1 = self
  if #genome2 < #self then
    genome1, genome2 = genome2, genome1
  end
  
  local crossoverPoint = math.random(0, #genome1/#genome1.dataTypes)*#genome1.dataTypes + 1
  local child1 = genome1:clone()
  local child2 = genome2:clone()
  
  for i = crossoverPoint, #child2 do
    local temp = child1[i]
    child1[i]=child2[i]
    child2[i]=temp
  end
  
  return child1, child2
end

function Genome:crossed(genome2, rate)
  return self:clone():cross(genome2, rate)
end

local Population = {}

Population.__index = Population

function Population:new(dataTypes, minLength, maxLength)
  local o = {
    genomes = {},
    dataTypes = dataTypes,
    minLength = minLength,
    maxLength = maxLength
  }
  
  return setmetatable(o, self)
end

function Population:generate(size)
  for n = 1, size do
    local genome = Genome:new(unpack(self.dataTypes))
    
    for i = 1, math.random(self.minLength, self.maxLength) * #self.dataTypes do
      genome[i] = 0
    end
    
    -- Populate with random values
    genome:mutate(1)
    
    table.insert(self.genomes, genome)
  end
end

function Population:topN(fitness, n)
  local fitArr = {}
  
  for i = 1, #self.genomes do
    fitArr[i] = {i, fitness(self.genomes[i])}
  end
  
  table.sort(fitArr, function(a,b) return a[2] > b[2] end)
  
  local ret = {}
  
  for i = 1, n do
    ret[i] = self.genomes[fitArr[i][1]]
  end
  
  return ret
end

function Population:breed(fitness, parents, children, mutChance)
  local top = self:topN(fitness, parents)
  
  -- wipe out last generation
  self.genomes = {}
  
  local i, j = 1, 1
  
  while #self.genomes < children do
    i = i + 1
    if i > #top then
      i = 1
      j = j + 1
      if j > #top then j = 1 end
    end
    local g1 = top[i]
    local g2 = top[j]
    
    c1, c2 = g1:crossover(g2)
    
    table.insert(self.genomes, c1)
    table.insert(self.genomes, c2)
  end
  
  for i = 1, #self.genomes do
    self.genomes[i]:mutate(mutChance)
  end
end

local function main()
  g = Genome:new(IntDataType(-10,10), CharDataType({"x", "y", "z"}))
  for i = 1,10 do g[i] = 0 end
  g:mutate(1)
  g2 = Genome:new(IntDataType(-10,10), CharDataType({"x","y","z"}))
  for i = 1,4 do g2[i] = 0 end
  g2:mutate(1)

  c1,c2 = g:crossover(g2)

  print(g,g2,c1,c2)

  p = Population:new({IntDataType(-20,5), CharDataType({"x","y","z"})}, 10, 15)

  p:generate(100)

  function sum(genome)
    local sum = 0
    for i = 1, #genome do
      if type(genome[i]) == "number" then
        sum = sum + genome[i]
      end
    end
    return sum
  end

  function product(genome)
    local product = 1
    for i = 1, #genome do
      if type(genome[i]) == "number" then
        product = product * genome[i]
      end
    end
    return product
  end

  for i = 1, 100 do
    top = p:topN(sum, 1)
    print(top[1], sum(top[1]))
    
    p:breed(sum, 10, 100, 0.01)
    p:generate(100)
    
    os.execute("sleep "..1)
  end
  print()
end

main()

return {Population = Population, Genome = Genome, IntDataType = IntDataType, CharDataType = CharDataType}