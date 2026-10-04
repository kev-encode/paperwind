--!strict
--[[
	LightingBlender
	Turns a clock time into a blended set of lighting values (from LightingConfig.Keyframes)
	and applies them to Lighting, its effects, and the terrain clouds.

	Used every frame by StarterPlayerScripts.LightingController. In Studio edit mode, preview
	any time from the command bar:
	  require(game.ReplicatedStorage.LightingSystem.LightingBlender).preview(17.5)
]]

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent:WaitForChild("LightingConfig"))

type Values = { [string]: any }
type Keyframe = { Time: number, Name: string, [string]: any }

local LightingBlender = {}

-- Object (child of Lighting, or Terrain for Clouds) that each keyframe group drives.
local GROUP_CLASS: { [string]: string } = {
	Atmosphere = "Atmosphere",
	ColorCorrection = "ColorCorrectionEffect",
	Bloom = "BloomEffect",
	SunRays = "SunRaysEffect",
	DepthOfField = "DepthOfFieldEffect",
	Clouds = "Clouds",
	Sky = "Sky",
}
local GROUPS = { "Lighting", "Atmosphere", "ColorCorrection", "Bloom", "SunRays", "DepthOfField", "Clouds" }

local keyframes: { Keyframe } = table.clone(Config.Keyframes :: any)
table.sort(keyframes, function(a, b)
	return a.Time < b.Time
end)

-- Catch authoring mistakes early: every keyframe must define the same properties.
do
	local first = keyframes[1]
	for _, keyframe in keyframes do
		for _, group in GROUPS do
			for property in (first[group] or {}) :: Values do
				if keyframe[group] == nil or keyframe[group][property] == nil then
					warn(string.format("[Lighting] Keyframe '%s' is missing %s.%s", keyframe.Name, group, property))
				end
			end
		end
	end
end

local targets: { [string]: Instance } = {}

local function target(group: string): Instance
	if group == "Lighting" then
		return Lighting
	end
	local cached = targets[group]
	if cached and cached.Parent then
		return cached
	end
	local className = GROUP_CLASS[group]
	local parent: Instance = if group == "Clouds" then Workspace.Terrain else Lighting
	local found = parent:FindFirstChild(group)
	if not (found and found:IsA(className)) then
		found = parent:FindFirstChildOfClass(className)
	end
	if not found then
		found = Instance.new(className)
		found.Name = group
		found.Parent = parent
	end
	targets[group] = found :: Instance
	return found :: Instance
end

local function smoothstep(t: number): number
	return t * t * (3 - 2 * t)
end

local function lerp(a: any, b: any, t: number): any
	if typeof(a) == "number" then
		return a + (b - a) * t
	elseif typeof(a) == "Color3" then
		return (a :: Color3):Lerp(b, t)
	end
	return if t < 0.5 then a else b
end

-- Blended values for a clock time: { Group = { Property = value } }
function LightingBlender.evaluate(clock: number): { [string]: Values }
	clock %= 24
	local count = #keyframes
	local nextIndex = 1
	while nextIndex <= count and keyframes[nextIndex].Time <= clock do
		nextIndex += 1
	end
	local k1 = keyframes[((nextIndex - 1) % count) + 1]
	local k0 = keyframes[((nextIndex - 2) % count) + 1]
	local span = (k1.Time - k0.Time) % 24
	if span <= 0 then
		span = 24
	end
	local alpha = smoothstep(math.clamp(((clock - k0.Time) % 24) / span, 0, 1))

	local result: { [string]: Values } = {}
	for _, group in GROUPS do
		local from, to = k0[group], k1[group]
		if from and to then
			local values: Values = {}
			for property, value in from :: Values do
				local other = (to :: Values)[property]
				values[property] = if other ~= nil then lerp(value, other, alpha) else value
			end
			result[group] = values
		end
	end
	return result
end

-- Only write properties that actually changed (cheap per-frame updates).
local applied: { [Instance]: Values } = {}

local function setProperty(instance: Instance, property: string, value: any)
	local cache = applied[instance]
	if not cache then
		cache = {}
		applied[instance] = cache
	end
	local last = cache[property]
	if last ~= nil then
		if typeof(value) == "number" then
			if math.abs(value - last) < 1e-4 then
				return
			end
		elseif typeof(value) == "Color3" then
			local l = last :: Color3
			if math.abs(value.R - l.R) + math.abs(value.G - l.G) + math.abs(value.B - l.B) < 1 / 512 then
				return
			end
		elseif value == last then
			return
		end
	end
	cache[property] = value;
	(instance :: any)[property] = value
end

-- Writes a property only if it differs. Some (LightingStyle, PrioritizeLightingQuality) can only be
-- changed in Studio, not by game scripts; they're saved in the place, so they already match at runtime.
local function setIfDifferent(instance: Instance, property: string, value: any)
	local readable, current = pcall(function()
		return (instance :: any)[property]
	end)
	if readable and current == value then
		return
	end
	local written, err = pcall(function()
		(instance :: any)[property] = value
	end)
	if not written then
		warn(string.format("[Lighting] Couldn't set %s.%s at runtime (set it in Studio): %s", instance.Name, property, tostring(err)))
	end
end

-- One-time setup: global Lighting settings and static per-object properties.
function LightingBlender.applySetup()
	for property, value in Config.Global :: Values do
		setIfDifferent(Lighting, property, value)
	end
	for group, values in Config.Static :: { [string]: Values } do
		local instance = target(group)
		for property, value in values do
			setIfDifferent(instance, property, value)
		end
	end
end

-- Apply the lighting for a clock time (also moves the sun and moon).
function LightingBlender.apply(clock: number)
	Lighting.ClockTime = clock % 24
	for group, values in LightingBlender.evaluate(clock) do
		local instance = target(group)
		for property, value in values do
			setProperty(instance, property, value)
		end
	end
end

-- Studio helper: show the full look for a clock time while editing.
function LightingBlender.preview(clock: number): string
	table.clear(applied)
	table.clear(targets)
	LightingBlender.applySetup()
	LightingBlender.apply(clock)
	return string.format("Lighting previewed at %05.2f", clock % 24)
end

return LightingBlender
