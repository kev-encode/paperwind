--!strict
--[[
	LightingBlender
	What: blends config.keyframes for clock time and applies them to Lighting, its effects, and terrain clouds
	Used by: LightingController, every frame
	Preview: require(game.ReplicatedStorage.LightingSystem.LightingBlender).preview(17.5)
]]

local lighting = game:GetService("Lighting")
local workspace = game:GetService("Workspace")
local config = require(script.Parent:WaitForChild("LightingConfig"))
type Values = { [string]: any }
type Keyframe = { time: number, name: string, [string]: any }
local blender = {}

-- note: the object each keyframe group drives, a child of lighting or terrain
local GROUP_CLASS: { [string]: string } = {
	Atmosphere = "Atmosphere",
	ColorCorrection = "ColorCorrectionEffect",
	Bloom = "BloomEffect",
	SunRays = "SunRaysEffect",
	DepthOfField = "DepthOfFieldEffect",
	Clouds = "Clouds",
	Sky = "Sky",
}

local GROUPS = {
	"Lighting",
	"Atmosphere",
	"ColorCorrection",
	"Bloom", "SunRays",
	"DepthOfField",
	"Clouds",
}

local keyframes: { Keyframe } = table.clone(config.keyframes :: any)
table.sort(keyframes, function(a, b)
	return a.time < b.time -- note: `a.time < b.time` is marked as an error in IDE
end)

-- note: every keyframe must define the same properties
do
	local first = keyframes[1]
	
	for i, keyframe in keyframes do
		for j, group in GROUPS do
			for property in (first[group] or {}) :: Values do
				if keyframe[group] == nil or keyframe[group][property] == nil then
					warn(string.format("[Lighting] Keyframe '%s' is missing %s.%s", keyframe.name, group, property))
				end
			end
		end
	end
end

local targets: { [string]: Instance } = {}

local function getTarget(group: string): Instance
	if group == "Lighting" then
		return lighting
	end
	
	local cached = targets[group]
	if cached and cached.Parent then
		return cached
	end
	
	local class_name = GROUP_CLASS[group]
	local parent: Instance = if group == "Clouds" then workspace.Terrain else lighting -- note: `workspace.Terrain` is marked as an error in IDE
	
	local found = parent:FindFirstChild(group)
	if not (found and found:IsA(class_name)) then
		found = parent:FindFirstChildOfClass(class_name)
	end
	
	if not found then
		found = Instance.new(class_name)
		found.Name = group
		found.Parent = parent
	end
	
	targets[group] = found :: Instance
	return found :: Instance
end

local function smoothstep(alpha: number): number
	return alpha * alpha * (3 - 2 * alpha)
end

local function lerp(from: any, to: any, alpha: number): any
	if typeof(from) == "number" then
		return from + (to - from) * alpha

	elseif typeof(from) == "Color3" then
		return (from :: Color3):Lerp(to, alpha)
	end
	
	return if alpha < 0.5 then from else to
end

-- note: blended values for a clock time, as { group = { property = value } }
function blender.evaluate(clock: number): { [string]: Values }
	clock %= 24
	local count = #keyframes
	local next_index = 1
	
	while next_index <= count and keyframes[next_index].time <= clock do
		next_index += 1
	end
	
	local after = keyframes[((next_index - 1) % count) + 1]
	local before = keyframes[((next_index - 2) % count) + 1]
	
	local span = (after.time - before.time) % 24
	if span <= 0 then
		span = 24
	end
	
	local alpha = smoothstep(math.clamp(((clock - before.time) % 24) / span, 0, 1))

	local result: { [string]: Values } = {}
	for i, group in GROUPS do
		local from, to = before[group], after[group]
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

-- note: only write properties that changed, so per-frame updates stay cheap
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
			local color = last :: Color3
			
			if math.abs(value.R - color.R) + math.abs(value.G - color.G) + math.abs(value.B - color.B) < 1 / 512 then
				return
			end
			
		elseif value == last then
			return
		end
	end
	
	cache[property] = value;
	(instance :: any)[property] = value
end

-- note: some properties (lightingstyle, prioritizelightingquality) can only change in studio
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

-- note: one-time setup of global settings and static per-object properties
function blender.applySetup()
	for property, value in config.global :: Values do
		setIfDifferent(lighting, property, value)
	end
	
	for group, values in config.static :: { [string]: Values } do
		local instance = getTarget(group)
		
		for property, value in values do
			setIfDifferent(instance, property, value)
		end
	end
end

-- note: applies the lighting for a clock time, which also moves the sun and moon
function blender.apply(clock: number)
	lighting.ClockTime = clock % 24
	
	for group, values in blender.evaluate(clock) do
		local instance = getTarget(group)
		
		for property, value in values do
			setProperty(instance, property, value)
		end
	end
end

-- note: studio helper that shows the full look for a clock time while editing
function blender.preview(clock: number): string
	table.clear(applied)
	table.clear(targets)
	blender.applySetup()
	blender.apply(clock)
	return string.format("Lighting previewed at %05.2f", clock % 24)
end

return blender