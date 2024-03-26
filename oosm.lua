local oosm = {}

---@class State
---@field _enter? fun(self: State, parentMachine: Machine, lastStateName: string?, lastState: State?): boolean?
---@field _exit? fun(self: State, parentMachine: Machine, nextStateName: string, nextState: State): boolean?
---@field _name string?
local State = {}
local StateMetaTable = {__index = State}

---Creates a new `State` for use in a `Machine`.
---
--- If `baseTable` is not `nil`, this function will return `baseTable` as a `State`.
---@param baseTable table
---@return State
---@overload fun(): State
function oosm.newState(baseTable)
	if baseTable ~= nil then
		assert(type(baseTable) == "table", ("Expected table, got %s"):format(type(baseTable)))
		return setmetatable(baseTable, StateMetaTable)
	end

	return setmetatable({}, StateMetaTable)
end

---Sets the callback ran on `callbackName` when this state is active
---@param callbackName string
---@param callback? fun(self: State, parentMachine: Machine, ...): ...
---@return State
function State:setCallback(callbackName, callback)
	local cType = type(callback)
	assert(cType == "function" or cType == "nil", ("Expected function or nil, got %s"):format(cType))
	self[callbackName] = callback
	return self
end

---Sets the callback ran when the state is being switched to.
---
---The callback should return `true` if moving is allowed, and `false` otherwise.
---You'll almost always want to return `true` at the end of your callback.
---@param callback? fun(self: State, parentMachine: Machine, lastStateName: string?, lastState: State?): boolean?
---@return State
function State:setOnEntering(callback)
	local cType = type(callback)
	assert(cType == "function" or cType == "nil", ("Expected function or nil, got %s"):format(cType))
	self._enter = callback
	return self
end

---Sets the callback ran when a different state is being switched to.
---
---The callback should return `true` if moving is allowed, and `false` otherwise.
---You'll almost always want to return `true` at the end of your callback.
---@param callback? fun(self: State, parentMachine: Machine, nextStateName: string, nextState: State): boolean?
---@return State
function State:setOnExiting(callback)
	local cType = type(callback)
	assert(cType == "function" or cType == "nil", ("Expected function or nil, got %s"):format(cType))
	self._exit = callback
	return self
end

---!!! CALLED AUTOMATICALLY !!!
---@param newName string
function State:_setName(newName)
	if self._name and self._name ~= newName then
		-- Already has a name, attempting to set a different name
		-- You might be putting one state under different names on different machines
		warn(("Setting state name from '%' to '%'; are you accidentally reusing a state under different names?"):format(self._name, newName))
	end
	self._name = newName
end

---!!! CALLED AUTOMATICALLY !!!
---
---Returns `true` when `_enter` is not set. Otherwise, it returns the result of that callback.
---Forgetting the return value, or returning `nil`, is considered `true`
---@param parentMachine Machine
---@param lastStateName? string
---@param lastState? State
---@return boolean
function State:_onEntering(parentMachine, lastStateName, lastState)
	local _enter = self._enter
	if _enter then
		local success = _enter(self, parentMachine, lastStateName, lastState)
		if success == nil then
			-- nil is considered `true`
			return true
		end
		return success
	end
	return true
end

---!!! CALLED AUTOMATICALLY !!!
---
---Returns `true` when `_exit` is not set. Otherwise, it returns the result of that callback.
---Forgetting the return value, or returning `nil`, is considered `true`
---@param parentMachine Machine
---@param nextStateName any
---@param nextState any
---@return boolean
function State:_onExiting(parentMachine, nextStateName, nextState)
	local _exit = self._exit
	if _exit then
		local success = _exit(self, parentMachine, nextStateName, nextState)
		if success == nil then
			-- nil is considered `true`
			return true
		end
		return success
	end
	return true
end

---@class Machine
---@field _states {[string]: State}
---@field _curr? State
local Machine = {}
local MachineMetaTable = {__index = Machine}

---Creates a new Machine
---@param baseTable {_states: State[], _curr: State?}
---@return Machine
---@overload fun(): Machine
function oosm.newMachine(baseTable)
	return setmetatable({
		_states = {},
		_curr = nil,
	}, MachineMetaTable)
end

---Adds a new `State` into `Machine`
---
---You can add the same `State` to several machines, but you'll run into unexpected behavior
---if you add them under different names. If this happens, a warning will appear in your console.
---@param name string
---@param state State
---@return Machine
function Machine:addState(name, state)
	assert(type(name) == "string", ("Expected name to be string, got %s"):format(type(name)))
	assert(self._states[name] == nil, ("State '%s' already exists; are you sure your names are unique/you didn't insert twice?"):format(name))
	state:_setName(name)
	self._states[name] = state
	return self
end

---Goes to the `State` with the chosen name.
---
---The `Machine` will only switch to a state if it is valid move (the states returns `true` in both move callbacks).
---Otherwise, it will attempt to stay in the original state.
---If unable to go back to the initial state, the machine will error.
---
---This will do nothing if the target state is the same as the current state.
---@param newStateName string
---@return boolean
function Machine:swapState(newStateName)
	local formerState = self.current
	local newState = self._states[newStateName]

	assert(newState ~= nil, ("State '%s' does not exist"):format(newStateName))
	
	if formerState then
		-- The former state exists
		if formerState == newState then
			-- If it's the same, do nothing
			return true
		end
		-- Otherwise, try to switch
		local firstSuccess = formerState:_onExiting(self, newStateName, newState)
		if firstSuccess then
			-- Succeeded in switching away from the former state, go to next one
			local secondSuccess = newState:_onEntering(self, formerState._name, formerState)
			if secondSuccess then
				-- Both switches were successful, exit
				self.current = newState
				return true
			else
				-- New state could not switch, attempt to return to initial state
				-- If unable to, we have no state to go back to
				assert(formerState:_onEntering(self, newStateName, newState), ("Reached an invalid state attempting to switch from '%s' to '%s'"):format(formerState._name, newStateName))
				-- Could not switch to new state
				return false
			end
		else
			-- Could not switch to new state
			return false
		end
	else
		-- No state exists right now
		assert(newState:_onEntering(self, nil, nil), ("Could not set '%s' as the initial state"):format(newStateName))
		self.current = newState
		return true
	end
end

---Runs the state machine. It runs the chosen callback if it exists on the state.
---
---If the callback exists, this will return `true` along with any data the state might return. `false` otherwise.
---@param callbackName string
---@param ... unknown
---@return boolean, ... unknown
function Machine:run(callbackName, ...)
	local state = self.current
	if state then
		local _callback = state[callbackName]
		if _callback then
			-- Callback exists, call it with the state and parent machine
			return true, _callback(state, self, ...)
		else
			-- Callback did not exist
			return false
		end
	end
	-- No state is currently active
	return false
end

return oosm