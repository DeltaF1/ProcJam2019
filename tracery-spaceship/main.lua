local Grammar = require("lua-tracery/tracery").Grammar

function love.load(arg)
  if arg[#arg] == "-debug" then require("mobdebug").start() end
  
  
  grammar = Grammar({
      origin = "Test",
      
  })
  text = grammar.generate("origin")
end

function love.keypressed()
  text = grammar.generate("origin")
end

function love.draw()
  love.graphics.setColor(0.6,1,1)
  love.graphics.print(text, 100, 100)
end