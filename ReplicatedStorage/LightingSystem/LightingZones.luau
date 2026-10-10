--!strict
--[[
	LightingZones
	What: local changes to the blended lighting inside named regions, such as thicker fog under a forest's canopy
	How: weightsAt(position) gives each zone a weight from 0 to 1 by how far inside its region's outline the point is;
		adjust(values, weights) adds each zone's offsets and multiplies in its tints, scaled by the weight
	Used by: LightingBlender.apply, with weights eased by LightingController
	Tuning: LightingConfig.zones; outlines come from ReplicatedStorage.World.Regions
]]

local replicated_storage = game:GetService("ReplicatedStorage")

local config = require(script.Parent:WaitForChild("LightingConfig"))
local regions = require(replicated_storage:WaitForChild("World"):WaitForChild("Regions"))

type Values = { [string]: any }

local zones = {}

local function smoothstep(edge0: number, edge1: number, x: number): number
	local t = math.clamp((x - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3 - 2 * t)
end

-- note: each zone's weight at a world position, as { zone name = 0 to 1 }
function zones.weightsAt(position: Vector3): { [string]: number }
	local weights = {}
	local point = Vector2.new(position.X, position.Z)

	for name, zone in config.zones :: { [string]: any } do
		local region = (regions :: any)[zone.region]
		if region then
			local inside = regions.signedDistance(region.outline, point)
			weights[name] = smoothstep(zone.fade[1], zone.fade[2], inside)
		end
	end

	return weights
end

-- note: changes blended keyframe values in place, { group = { property = value } } as LightingBlender.evaluate returns them
function zones.adjust(values: { [string]: Values }, weights: { [string]: number })
	for name, weight in weights do
		local zone = (config.zones :: any)[name]
		if zone and weight > 0.001 then
			for group, offsets in zone.add or {} do
				local target = values[group]
				if target then
					for property, amount in offsets :: Values do
						if target[property] ~= nil then
							target[property] += amount * weight
						end
					end
				end
			end

			for group, tints in zone.tint or {} do
				local target = values[group]
				if target then
					for property, tint in tints :: Values do
						local color = target[property]
						if typeof(color) == "Color3" then
							local tinted = Color3.new(color.R * tint.R, color.G * tint.G, color.B * tint.B)
							target[property] = color:Lerp(tinted, weight)
						end
					end
				end
			end
		end
	end
end

return zones
