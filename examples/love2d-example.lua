-- This example requires LOVE2D to run.
-- Copy this file into a file called `main.lua` alongside `oosm.lua` and run it.

-- This will create a small game in which you must press space as much as possible
-- before the time limit reaches 0.

local oosm = require "oosm"

---@type Machine
local gameMachine

function love.load()
	-- Create a new Machine
	gameMachine = oosm.newMachine()
	-- Add the state that will be ran upon opening the game for the first time.
	------------------------
	------ Game Opened state
	------------------------
	:addState("game-opened",
		oosm.newState()
		:setOnEntering(
			---@param self State|table
			function (self, parentMachine, lastStateName, lastState)
				-- This will be ran when the state is entered for the first time.
				-- At the end of `love.load`, we switch to this state, running this callback.
				self.enteredAt = love.timer.getTime()
				self.stopLoadingAt = math.random(0.5, 1.5)

				-- This tells the `Machine` that entering this state is allowed.
				-- If you forget to add this, the `Machine` will consider it `true`.
				-- Basically, it's optional, but highly recommended.
				return true
			end
		)
		:setOnExiting(
			---@param self State|table
			function (self, parentMachine, nextStateName, nextState)
				-- We should clean up this state here.
				-- This shows just an example; setting this to `nil` is unnecessary.
				self.enteredAt = nil
				self.stopLoadingAt = nil
				-- Remember!
				return true
			end
		)
		:setCallback("update", function (self, parentMachine, dt)
			-- `dt` is passed in when the Machine is ran in `love.update`
			if love.timer.getTime() > 1.0 then
				parentMachine:swapState("main-menu")
			end
		end)
		:setCallback("draw", function (self, parentMachine)
			-- You can have multiple callbacks per state!
			-- We draw the UI here.
			love.graphics.print("Loading...", 0, 0)
		end)
	)
	----------------------
	------ Main Menu state
	----------------------
	:addState("main-menu",
		oosm.newState()
		-- The enter and exit callback are optional.
		:setOnEntering(function(self, parentMachine, ...)
			return true
		end)
		:setCallback("draw", function (self, parentMachine, ...)
			love.graphics.print("Main Menu", 0, 0)
			love.graphics.print("Press SPACE to play!", 0, 20)
		end)
		:setCallback("keypressed", function (self, parentMachine, key)
			if key == "space" then
				-- We can switch states inside of the state machine
				parentMachine:swapState("game")
			end
		end)
	)
	-----------------
	------ Game state
	-----------------
	:addState("game",
		oosm.newState()
		:setOnEntering(
			---@param self State|table
			function (self, parentMachine, lastStateName, lastState)
				self.score = 0
				self.stopAt = love.timer.getTime() + 5
				return true
			end
		)
		-- Lets skip the exit callback for now.
		:setCallback("keypressed",
			---@param self State|table
			function (self, parentMachine, key)
				if key == "space" then
					self.score = self.score + 1
				end
			end
		)
		:setCallback("update",
			---@param self State|table
			---@param parentMachine State|table
			function (self, parentMachine, dt)
				if love.timer.getTime() >= self.stopAt then
					-- You can add some values to the parent machine.
					-- It can get messy, though.
					parentMachine.score = self.score
					parentMachine:swapState("results")
				end
			end
		)
		:setCallback("draw",
		---@param self State|table
			function (self, parentMachine, ...)
				love.graphics.print("Press space!", 0, 0)
				love.graphics.print(("Score: %d"):format(self.score), 0, 20)
				love.graphics.print(("Time: %.1f"):format(self.stopAt - love.timer.getTime()), 0, 40)
			end
		)
	)
	--------------------
	------ Results state
	--------------------
	:addState("results",
		oosm.newState()
		:setCallback("keypressed",
			---@param self State|table
			function (self, parentMachine, key)
				if key == "backspace" then
					parentMachine:swapState("main-menu")
				end
			end
		)
		:setCallback("draw",
		---@param self State|table
			function (self, parentMachine, ...)
				love.graphics.print(("Final score: %d"):format(parentMachine.score), 0, 0)
				love.graphics.print("Press Backspace to return", 0, 20)
			end
		)
	)

	-- Don't forget! You also have to set the initial state.
	gameMachine:swapState("game-opened")
end

function love.update(dt)
	gameMachine:run("update", dt)
end

function love.draw()
	gameMachine:run("draw")
end

function love.keypressed(key)
	if key == "escape" then
		love.event.quit(0)
	else
		-- Run the state machine when a key is pressed
		gameMachine:run("keypressed", key)
	end
end