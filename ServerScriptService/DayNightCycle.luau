--[[
	DayNightCycle
	What: starts the shared day/night clock for this server
	How: only stores the clock's start point; each client renders the lighting
	See: ReplicatedStorage.LightingSystem.TimeCycle
]]

local replicated_storage = game:GetService("ReplicatedStorage")
local time_cycle = require(replicated_storage:WaitForChild("LightingSystem"):WaitForChild("TimeCycle"))
time_cycle.start()