--!strict
--[[
	TownLights
	What: switches town lamps on outside daytime
	How: checks TimeCycle.getPhase() once a second; only acts when the phase flips between day and not-day
	Tags: NightLight (lights get Enabled, glow parts turn to warm neon)
	Interiors: hearths, stoves, lanterns and sconces indoors stay lit all day, so their windows glow at night without a tag
]]

local collection_service = game:GetService("CollectionService")
local replicated_storage = game:GetService("ReplicatedStorage")

local time_cycle = require(replicated_storage:WaitForChild("LightingSystem"):WaitForChild("TimeCycle"))

local CHECK_INTERVAL = 1
local LAMP_COLOR = Color3.fromRGB(236, 156, 86)
local LAMP_TRANSPARENCY = 0.25

type Look = { material: Enum.Material, color: Color3, transparency: number }

local lit = false
local day_looks: { [BasePart]: Look } = {}

-- Applying ------------------------------------------------------------------

local function rememberLook(part: BasePart)
	if not day_looks[part] then
		day_looks[part] = { material = part.Material, color = part.Color, transparency = part.Transparency }
	end
end

local function setGlow(part: BasePart, on: boolean)
	rememberLook(part)
	if on then
		part.Material = Enum.Material.Neon
		part.Color = LAMP_COLOR
		part.Transparency = LAMP_TRANSPARENCY
		return
	end

	local look = day_looks[part]
	part.Material = look.material
	part.Color = look.color
	part.Transparency = look.transparency
end

local function applyNightLight(instance: Instance)
	if instance:IsA("Light") then
		instance.Enabled = lit

	elseif instance:IsA("BasePart") then
		setGlow(instance, lit)
	end
end

local function applyAll()
	for _, instance in collection_service:GetTagged("NightLight") do
		applyNightLight(instance)
	end
end

-- Start ---------------------------------------------------------------------

-- note: parts that stream in later pick up the current state
collection_service:GetInstanceAddedSignal("NightLight"):Connect(applyNightLight)

collection_service:GetInstanceRemovedSignal("NightLight"):Connect(function(instance)
	if instance:IsA("BasePart") then
		day_looks[instance] = nil
	end
end)

lit = time_cycle.getPhase() ~= "Day"
applyAll()

while true do
	task.wait(CHECK_INTERVAL)

	local should_light = time_cycle.getPhase() ~= "Day"
	if should_light ~= lit then
		lit = should_light
		applyAll()
	end
end