--!strict
--[[
	LightingController
	What: renders the day/night cycle on this client
	How: at config.cycle.update_rate, reads the clock (TimeCycle) and applies the blended lighting (LightingBlender)
	Zones: the camera's zone weights (LightingZones) ease toward their targets so entering a forest fades its fog in
	Tuning: ReplicatedStorage.LightingSystem.LightingConfig
]]

local replicated_storage = game:GetService("ReplicatedStorage")
local run_service = game:GetService("RunService")
local workspace = game:GetService("Workspace")

local lighting_system = replicated_storage:WaitForChild("LightingSystem")
local time_cycle = require(lighting_system:WaitForChild("TimeCycle"))
local blender = require(lighting_system:WaitForChild("LightingBlender"))
local config = require(lighting_system:WaitForChild("LightingConfig"))
local zones = require(lighting_system:WaitForChild("LightingZones"))

local UPDATE_INTERVAL = 1 / config.cycle.update_rate
local ZONE_RESPONSE = 1.2 -- note: exponential easing rate; about 2.5 s to settle

local zone_weights: { [string]: number } = {}

local function updateZoneWeights(delta_time: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local alpha = 1 - math.exp(-ZONE_RESPONSE * delta_time)
	for name, target in zones.weightsAt(camera.CFrame.Position) do
		local current = zone_weights[name] or target
		zone_weights[name] = current + (target - current) * alpha
	end
end

blender.applySetup()
updateZoneWeights(0)
blender.apply(time_cycle.getClockTime(), zone_weights)

local since_update = 0

run_service.Heartbeat:Connect(function(delta_time: number)
	since_update += delta_time
	if since_update < UPDATE_INTERVAL then
		return
	end

	updateZoneWeights(since_update)
	since_update = 0
	blender.apply(time_cycle.getClockTime(), zone_weights)
end)