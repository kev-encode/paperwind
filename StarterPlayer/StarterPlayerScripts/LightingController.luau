--!strict
--[[
	LightingController
	Renders the day/night cycle on this client: every frame it reads the shared clock
	(TimeCycle) and applies the blended time-of-day lighting (LightingBlender).
	Tuning lives in ReplicatedStorage.LightingSystem.LightingConfig.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LightingSystem = ReplicatedStorage:WaitForChild("LightingSystem")
local TimeCycle = require(LightingSystem:WaitForChild("TimeCycle"))
local LightingBlender = require(LightingSystem:WaitForChild("LightingBlender"))

LightingBlender.applySetup()
LightingBlender.apply(TimeCycle.getClockTime())

RunService:BindToRenderStep("PaperwindLighting", Enum.RenderPriority.First.Value, function()
	LightingBlender.apply(TimeCycle.getClockTime())
end)
