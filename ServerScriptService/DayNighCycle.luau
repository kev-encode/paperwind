--[[
	DayNightCycle
	Starts Paperwind's shared day/night clock for this server.

	The lighting itself is rendered by each player's client (StarterPlayerScripts.LightingController),
	so this script never touches Lighting properties; it only stores the clock's start point.
	Other server scripts can read or change time through ReplicatedStorage.LightingSystem.TimeCycle.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TimeCycle = require(ReplicatedStorage:WaitForChild("LightingSystem"):WaitForChild("TimeCycle"))

TimeCycle.start()
