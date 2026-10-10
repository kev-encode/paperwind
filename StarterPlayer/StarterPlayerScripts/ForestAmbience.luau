--!strict
--[[
	ForestAmbience
	What: wind in the woods: trees and plants lean and flutter with gusts of workspace.GlobalWind, and ground mist thickens
		through dusk, night and dawn
	How: models tagged WindSway near the camera turn about their foot, all of them in one BulkMoveTo per update, on this
		client only; resting frames are kept so models that fall out of range settle back; mist emitters tagged ForestMist
		scale their rate with the clock (TimeCycle)
	Tags: WindSway (Model; Sway attribute = lean in degrees in a full breeze), ForestMist (ParticleEmitter; Rate attribute =
		the night rate)
	Cost: only models within SWAY_DISTANCE move, SWAY_RATE times a second at most; invisible colliders never move
]]

local collection_service = game:GetService("CollectionService")
local replicated_storage = game:GetService("ReplicatedStorage")
local run_service = game:GetService("RunService")
local workspace = game:GetService("Workspace")

local time_cycle = require(replicated_storage:WaitForChild("LightingSystem"):WaitForChild("TimeCycle"))

local SWAY_DISTANCE = 140
local SWAY_RATE = 30
local SCAN_INTERVAL = 0.5
local WIND_REFERENCE = 8 -- note: GlobalWind speed, in studs per second, that counts as a full breeze
local FLUTTER = 0.35 -- note: share of the lean that flutters quickly in crowns and fronds
local MIST_INTERVAL = 2
local MIST_DAY_SHARE = 0.25 -- note: share of the night rate that lingers through the day

type Swayer = {
	foot: Vector3,
	parts: { BasePart },
	rest: { CFrame },
	leafy: { boolean },
	degrees: number,
	phase: number,
}

local swayers: { [Model]: Swayer } = {}
local active: { Swayer } = {}

-- Helpers -------------------------------------------------------------------

local function smoothstep(edge0: number, edge1: number, x: number): number
	local t = math.clamp((x - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3 - 2 * t)
end

-- note: leaf cards cut out with alpha; these flutter on top of the lean
local function isLeafy(part: BasePart): boolean
	local appearance = part:FindFirstChildOfClass("SurfaceAppearance")
	return appearance ~= nil and appearance.AlphaMode == Enum.AlphaMode.Transparency
end

-- Wind ----------------------------------------------------------------------

local function addSwayer(instance: Instance)
	if not instance:IsA("Model") then
		return
	end

	local parts = {}
	local rest = {}
	local leafy = {}
	for _, part in instance:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "Collider" then
			table.insert(parts, part)
			table.insert(rest, part.CFrame)
			table.insert(leafy, isLeafy(part))
		end
	end

	if #parts == 0 then
		return
	end

	local foot = instance:GetPivot().Position
	swayers[instance] = {
		foot = foot,
		parts = parts,
		rest = rest,
		leafy = leafy,
		degrees = instance:GetAttribute("Sway") or 1,
		phase = (foot.X * 0.13 + foot.Z * 0.07) % (math.pi * 2),
	}
end

-- note: dropped from the active list at once, so a model that streams out is never moved again
local function removeSwayer(instance: Instance)
	local swayer = swayers[instance :: Model]
	if not swayer then
		return
	end

	swayers[instance :: Model] = nil
	local index = table.find(active, swayer)
	if index then
		table.remove(active, index)
	end
end

-- note: picks the models near the camera; any that left the range go back to rest in the same pass
local function scan()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local focus = camera.CFrame.Position
	local was_active: { [Swayer]: boolean } = {}
	for _, swayer in active do
		was_active[swayer] = true
	end

	table.clear(active)
	local parts = {}
	local cframes = {}
	for _, swayer in swayers do
		if (swayer.foot - focus).Magnitude < SWAY_DISTANCE then
			table.insert(active, swayer)
		elseif was_active[swayer] then
			for index, part in swayer.parts do
				table.insert(parts, part)
				table.insert(cframes, swayer.rest[index])
			end
		end
	end

	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

local function sway(now: number)
	local wind = workspace.GlobalWind * Vector3.new(1, 0, 1)
	local speed = wind.Magnitude
	if speed < 0.01 or #active == 0 then
		return
	end

	-- note: turning about up x downwind tips the top of a model downwind
	local axis = Vector3.yAxis:Cross(wind.Unit)
	local strength = math.min(speed / WIND_REFERENCE, 1.5)
	local parts = {}
	local cframes = {}

	for _, swayer in active do
		local foot = swayer.foot
		local gust = 0.5 + 0.35 * math.sin(now * 0.7 + swayer.phase) + 0.25 * math.noise(now * 0.3, foot.X / 70, foot.Z / 70)
		local reach = math.rad(swayer.degrees) * strength
		local lean = reach * gust
		local flutter = reach * FLUTTER * math.sin(now * 2.6 + swayer.phase * 3)

		local to_origin = CFrame.new(-foot)
		local stem = CFrame.new(foot) * CFrame.fromAxisAngle(axis, lean) * to_origin
		local crown = CFrame.new(foot) * CFrame.fromAxisAngle(axis, lean + flutter) * to_origin

		for index, part in swayer.parts do
			local turn = if swayer.leafy[index] then crown else stem
			table.insert(parts, part)
			table.insert(cframes, turn * swayer.rest[index])
		end
	end

	workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Mist ----------------------------------------------------------------------

-- note: 1 through the night, easing down to MIST_DAY_SHARE by mid-morning and back up from late afternoon
local function mistFactor(clock: number): number
	local day = smoothstep(7, 10, clock) * (1 - smoothstep(16.5, 19.5, clock))
	return 1 - (1 - MIST_DAY_SHARE) * day
end

local function applyMist(instance: Instance, factor: number)
	if instance:IsA("ParticleEmitter") then
		local rate = instance:GetAttribute("Rate")
		if typeof(rate) == "number" then
			instance.Rate = rate * factor
		end
	end
end

local function updateMist()
	local factor = mistFactor(time_cycle.getClockTime())
	for _, instance in collection_service:GetTagged("ForestMist") do
		applyMist(instance, factor)
	end
end

-- Start ---------------------------------------------------------------------

-- note: deferred so a model that streams in has all its parts before its resting frames are read
collection_service:GetInstanceAddedSignal("WindSway"):Connect(function(instance)
	task.defer(addSwayer, instance)
end)
collection_service:GetInstanceRemovedSignal("WindSway"):Connect(removeSwayer)
for _, instance in collection_service:GetTagged("WindSway") do
	addSwayer(instance)
end

collection_service:GetInstanceAddedSignal("ForestMist"):Connect(function(instance)
	applyMist(instance, mistFactor(time_cycle.getClockTime()))
end)
updateMist()

local since_scan = SCAN_INTERVAL
local since_sway = 0
local since_mist = 0

run_service.Heartbeat:Connect(function(delta_time: number)
	since_scan += delta_time
	since_sway += delta_time
	since_mist += delta_time

	if since_scan >= SCAN_INTERVAL then
		since_scan = 0
		scan()
	end

	if since_sway >= 1 / SWAY_RATE then
		since_sway = 0
		sway(os.clock())
	end

	if since_mist >= MIST_INTERVAL then
		since_mist = 0
		updateMist()
	end
end)
