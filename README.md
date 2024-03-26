# Lua OOSM
### Object-Oriented State Machines
A library for creating object-oriented finite state machines in the Lua programming language.

## Usage
Simply download/copy [oosm.lua](oosm.lua) into your Lua project and `require` it.

## Example
> A simpler example is available in [examples/hello-world.lua](examples/hello-world.lua). The following example shows the important aspects of the library.

```lua
local oosm = require "path.to.oosm"

-- Create the machine which will hold our states
local trafficLight = oosm.createMachine()


-- Create some states for the machine
---- Green light
local greenLight = oosm.createState()
:addCallback("printColor", function(self, parentMachine)
	print("The light is green!")
end)

---- Yellow light
local yellowLight = oosm.createState()
:addCallback("printColor", function(self, parentMachine)
	print("The light is yellow!")
end)

---- Red light
-- You can add arbitrary fields into the state
local redLight = oosm.createState()
redLight.redLightRunners = {}

redLight:addCallback("printColor", function(self, parentMachine)
	print("The light is red!")
end)
:addCallback("checkCar", function(self, parentMachine, carLicensePlate)
	-- We can have disjointed callbacks.
	-- Basically, all callbacks are optional.
	print(("%s is running the light!"):format(carLicensePlate))
	table.insert(self.redLightRunners, carLicensePlate)
end)


-- Add the states into the machine
trafficLight
:addState("green", greenLight)
:addState("yellow", yellowLight)
:addState("red", redLight)

-- Set the initial state
trafficLight:swapState("green")

-- Now we can use the machine
trafficLight:call("printColor")
-- > "The light is green!"
trafficLight:call("checkCar", "GOODCAR")
-- Nothing happens, as the callback "checkCar" does not exist
-- for the green light.
trafficLight:swapState("yellow")
trafficLight:call("printColor")
-- > "The light is yellow!"
trafficLight:swapState("red")
trafficLight:call("printColor")
-- > "The light is red!"
trafficLight:call("checkCar", "BADCAR")
-- > "BADCAR is running the light"

print(redLight.redLightRunners[1])
-- > "BADCAR"
```

> Additionally, you can control whether entering or leaving a state is valid.
> This example does not show that in order to be more clear on usage.
>
> For more information, check `Machine:swapState`, `State:setOnEntering`, and `State:setOnExiting`.

## API
Every method in the library is annotated, and will appear if you use the [Lua Language Server](https://github.com/LuaLS/lua-language-server). It's manually readable otherwise.

It's safe to add arbitrary fields to both the `State` and `Machine`. That is, you can insert data into both objects as long as they don't conflict with the following:
* `Machine._states`: Keeps the states in a `[string]: State` table. Safe to modify, as long as the `State` you're removing isn't currently active.
* `Machine._curr`: Has the currently active `State`. **Not safe to modify** outside of `Machine:swapState()`.
* `State._name`: The `State`'s name. **Not safe to modify.**
* `State._enter`: The `State`'s callback that is ran on attempting to enter this `State`. Safe to modify.
* `State._exit`: The `State`'s callback that is ran on attempting to exit this `State`. Safe to modify.

### Contents
* [oosm.createMachine()](#oosmcreatemachine)
* [oosm.createMachine(baseTable)](#oosmcreatemachinebasetable)
* [Machine:addState(name: string, state: State)](#machineaddstatename-string-state-state)
* [Machine:swapState(newStateName: string)](#machineswapstatenewstatename-string)
* [Machine:run(callbackName: string, ...)](#machineruncallbackname-string)
* [oosm.createState()](#oosmcreatestate)
* [oosm.createState(baseTable)](#oosmcreatestatebasetable-table)
* [State:setCallback(callbackName: string, callback?: fun(self: State, parentMachine: Machine, ...): ...)](#statesetcallbackcallbackname-string-callback-funself-state-parentmachine-machine)
* [State:setOnEntering(callback?: fun(self: State, parentMachine: Machine, lastStateName: string?, lastState: State?): (success: boolean?))](#statesetonenteringcallback-funself-state-parentmachine-machine-laststatename-string-laststate-state-success-boolean)
* [State:setOnExiting(callback?: fun(self: State, parentMachine: Machine, nextStateName: string, nextState: State): (success: boolean?))](#statesetonexitingcallback-funself-state-parentmachine-machine-nextstatename-string-nextstate-state-success-boolean)


#### `oosm.createMachine()`
> Returns `Machine`

Returns a `Machine` that one can add states onto.

#### `oosm.createMachine(baseTable)`
> Returns `Machine`

Returns a `Machine` that one can add states onto.
`baseTable` must have `self._states` equal an empty table, or a table of states with their names as keys.
`self._curr` is optional if you'd like to set the current state.

#### `Machine:addState(name: string, state: State)`
> Returns `self: Machine`

Adds a `State` to self (`Machine`) under the name `name`. Returns itself as an easier way to chain methods.

#### `Machine:swapState(newStateName: string)`
> Returns `success: boolean`

Attempts to move from the current `State` to the `State` under `newStateName`. If the current `State`'s exit callback returns `true`/`nil` (or does not exist), and the new `State`'s enter callback returns `true`/`nil` (or does not exist). If the new `State` was swapped to, this method returns `true`, otherwise `false`.

> **WARNING**
>
> The `Machine` will error if the following occurs:
>
> 1. Initial State: Allows swapping to the new state, exits and returns `true`.
> 2. New State: The state disallows being entered/swapped to, returns `false`.
> 3. Initial State: Also doesn't allow being entered/swapped to, returns `false` even though it was the initial `State`. The `Machine` no longer has an active `State`.
>
> This will only occur if you set the enter and exit callbacks for more than 1 state.
>
> The best way to prevent this would be to make sure that all state changes are valid.

> This method is also safe to be called inside a `State`'s method, but the callback won't be called again for the new `State`. You will need to do that manually, if relevant.
>
> You can use another callback (ex: "checkSwap") if you want to manage state swapping separately.

#### `Machine:run(callbackName: string, ...)`
> Returns `(success: boolean, ...)`

Calls `callbackName` on the active state. Returns `true` if the active state exists and the callback also exists. Arbitrary parameters can be given to the state, and arbitrary return values may be received from the state.

#### `oosm.createState()`
> Returns `State`.

Creates a new `State`.

#### `oosm.createState(baseTable: table)`
> Returns `State`

Creates a new `State` from `baseTable`. No table fields are required.

#### `State:setCallback(callbackName: string, callback?: fun(self: State, parentMachine: Machine, ...): ...)`
> Returns `self: State`

Functionally equivalent to `state[callbackName] = callback`. Adds the callback into the `State` under `callbackName`, which will be ran when `Machine:call(callbackName)` is called.

If you'd like to remove a state, you can do either:
```lua
-- idiomatic
State:setCallback("removed", nil)
-- Also safe to do
State[removed] = nil
```

#### `State:setOnEntering(callback?: fun(self: State, parentMachine: Machine, lastStateName: string?, lastState: State?): (success: boolean?))`
> Returns `self: State`

Sets the callback that is ran when this `State` is being entered. Return `true` if it is allowed, and `false` if it isn't. The `Machine` won't change to this `State` and will attempt to return to the former `State`. Can be set to `nil`.

This callback is most useful for preparing new behavior.

> See the warning on `Machine:swapState`.

#### `State:setOnExiting(callback?: fun(self: State, parentMachine: Machine, nextStateName: string, nextState: State): (success: boolean?))`
> Returns `self: State`

Sets the callback that is ran when this `State` is being exited. Return `true` if it is allowed, and `false` if it isn't. The `Machine` won't change to the new state under `nextStateName` if `false` is returned. Can be set to `nil`.

This callback is most useful for cleaning up data.

> See the warning on `Machine:swapState`.

## License
Lua OOSM is open source and dual-licensed under either:

* MIT License ([LICENSE-MIT](LICENSE-MIT) or [http://opensource.org/licenses/MIT](http://opensource.org/licenses/MIT))
* Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or [http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0))

You may pick whichever license you prefer. This follows in the footsteps of the wider Rust ecosystem, but mostly Bevy's reasoning to switch to a dual-license model. ([see cart's issue on adding the Apache-2.0 License to the Bevy Engine](https://github.com/bevyengine/bevy/issues/2373)).

## Your contributions
Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in the work by you, as defined in the Apache-2.0 license, shall be dual licensed as above, without any additional terms or conditions.