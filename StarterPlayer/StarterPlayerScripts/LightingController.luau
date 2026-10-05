--!strict
--[[
	LightingController
	What: renders the day/night cycle on this client
	How: each frame, reads the clock (TimeCycle) and applies the blended lighting (LightingBlender)
	Tuning: ReplicatedStorage.LightingSystem.LightingConfig
]]

local replicated_storage = game:GetService("ReplicatedStorage")
local run_service = game:GetService("RunService")

local lighting_system = replicated_storage:WaitForChild("LightingSystem")
local time_cycle = require(lighting_system:WaitForChild("TimeCycle"))
local blender = require(lighting_system:WaitForChild("LightingBlender"))

blender.applySetup()
blender.apply(time_cycle.getClockTime())

run_service:BindToRenderStep("PaperwindLighting", Enum.RenderPriority.First.Value, function()
	blender.apply(time_cycle.getClockTime())
end)