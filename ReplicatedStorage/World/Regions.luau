--!strict
--[[
	Regions
	What: named areas of the world map as outlines on the ground (x, z in studs), shared by build tools and runtime systems
	Used by: TownBuilds.Glimmerwood (edit time), LightingSystem.LightingZones (fog inside an area)
	FoldHaven: the village and the open ground it keeps clear round its north and east sides; Glimmerwood thins out toward it
	Outlines: closed polygons; the last point joins back to the first
]]

export type Region = {
	outline: { Vector2 },
}

local regions = {}

-- Areas ---------------------------------------------------------------------

-- note: the village with its houses, gardens and harbour, and the felled ground round them, ~16 to 30 studs out from the houses
regions.FoldHaven = {
	outline = {
		Vector2.new(-160, -140),
		Vector2.new(0, -136),
		Vector2.new(40, -130),
		Vector2.new(82, -124),
		Vector2.new(106, -118),
		Vector2.new(136, -86),
		Vector2.new(140, -40),
		Vector2.new(140, 140),
		Vector2.new(-160, 140),
	},
} :: Region

-- note: the starter forest north-east of Fold Haven; its south-west edge runs just outside the village's felled ground,
-- and the lane from the village crosses it on the way to the stile
regions.Glimmerwood = {
	outline = {
		Vector2.new(44, -132),
		Vector2.new(70, -128),
		Vector2.new(100, -122),
		Vector2.new(126, -100),
		Vector2.new(162, -104),
		Vector2.new(196, -126),
		Vector2.new(230, -160),
		Vector2.new(290, -182),
		Vector2.new(330, -215),
		Vector2.new(362, -252),
		Vector2.new(386, -292),
		Vector2.new(398, -335),
		Vector2.new(398, -400),
		Vector2.new(372, -441),
		Vector2.new(300, -448),
		Vector2.new(240, -448),
		Vector2.new(210, -428),
		Vector2.new(195, -390),
		Vector2.new(172, -345),
		Vector2.new(145, -302),
		Vector2.new(118, -262),
		Vector2.new(98, -222),
		Vector2.new(80, -188),
		Vector2.new(56, -164),
	},
} :: Region

-- Geometry ------------------------------------------------------------------

-- note: distance from a point to an outline's edge, positive inside and negative outside
function regions.signedDistance(outline: { Vector2 }, point: Vector2): number
	local nearest = math.huge
	local inside = false
	local count = #outline

	for i = 1, count do
		local a = outline[i]
		local b = outline[i % count + 1]
		local edge = b - a
		local t = math.clamp((point - a):Dot(edge) / edge:Dot(edge), 0, 1)
		nearest = math.min(nearest, (point - (a + edge * t)).Magnitude)

		-- note: even-odd rule, a ray toward +x crosses the edge
		if (a.Y > point.Y) ~= (b.Y > point.Y) then
			local cross_x = a.X + (point.Y - a.Y) / (b.Y - a.Y) * edge.X
			if point.X < cross_x then
				inside = not inside
			end
		end
	end

	return if inside then nearest else -nearest
end

return regions
