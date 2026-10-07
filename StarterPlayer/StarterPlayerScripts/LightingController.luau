--!strict
--[[
	LightingController
	What: renders the day/night cycle on this client
	How: at config.cycle.update_rate, reads the clock (TimeCycle) and applies the blended lighting (LightingBlender)
	Tuning: ReplicatedStorage.LightingSystem.LightingConfig
]]

local replicated_storage = game:GetService("ReplicatedStorage")
local run_service = game:GetService("RunService")

local lighting_system = replicated_storage:WaitForChild("LightingSystem")
local time_cycle = require(lighting_system:WaitForChild("TimeCycle"))
local blender = require(lighting_system:WaitForChild("LightingBlender"))
local config = require(lighting_system:WaitForChild("LightingConfig"))

local UPDATE_INTERVAL = 1 / config.cycle.update_rate

blender.applySetup()
blender.apply(time_cycle.getClockTime())

local since_update = 0

run_service.Heartbeat:Connect(function(delta_time: number)
	since_update += delta_time
	if since_update < UPDATE_INTERVAL then
		return
	end

	since_update = 0
	blender.apply(time_cycle.getClockTime())
end)