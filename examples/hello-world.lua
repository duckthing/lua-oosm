local oosm = require "..oosm"

-- Create the machine
local solarMachine = oosm.newMachine()

-- Create the states that go into the machine
local worldState = oosm.newState()
:setCallback("greeting", function (self, parentMachine, ...)
	print("Hello world!")
end)

local moonState = oosm.newState()
:setCallback("greeting", function (self, parentMachine, ...)
	print("Hello moon!")
end)

-- Add the states into the machine
solarMachine
:addState("world", worldState)
:addState("moon", moonState)

-- Switch to the "world" state
solarMachine:swapState("world")

-- Greet it!
solarMachine:run("greeting") -- "Hello world!"

-- Switch to the "moon" state
solarMachine:swapState("moon")

-- Greet the moon!
solarMachine:run("greeting") -- "Hello moon!"