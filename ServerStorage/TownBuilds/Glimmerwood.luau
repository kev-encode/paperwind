--!strict
--[[
	Glimmerwood
	What: builds Glimmerwood, the starter forest north-east of Fold Haven: the forest floor, paths and clearings in the terrain,
		then Workspace.Glimmerwood with trees, undergrowth, deadwood, rocks, landmarks, lanterns and ground mist
	Used by: the studio assistant (edit mode); nothing requires it at runtime
	Needs: deps = { kit, palette, nature } (BuildKit, BuildPalette, TownBuilds.Nature), passed in because studio caches
		required modules; ServerStorage.Foliage (Roblox's Forest Pack); the outline is ReplicatedStorage.World.Regions.Glimmerwood
	Build: glimmerwood.terrain(deps) adds the rolling ground once (it marks Terrain with GlimmerwoodSculpted), then levels
		the clearings, grades the paths and repaints the floor on every run; glimmerwood.objects(deps) rebuilds everything
		else from fixed seeds; both can run any number of times
	Litter: leaf litter is terrain Salt, drawn with the LeafLitter MaterialVariant through MaterialService's base material override
	Runtime: ForestAmbience sways WindSway models and paces ForestMist emitters; TownLights lights the NightLight lanterns;
		LightingZones thickens the fog inside the outline
	Look: a bright beech wood on rolling ground: sunny glades, fern drifts, anemones, mossy deadwood and one giant old beech
	Village side: the outline runs along Fold Haven's felled ground (Regions.FoldHaven), so the wood thins to young trees and
		scrub toward it; VILLAGE_FADE thins the last few studs to nothing, and a few stumps show where the village cut it back
]]

local collection_service = game:GetService("CollectionService")
local replicated_storage = game:GetService("ReplicatedStorage")
local workspace = game:GetService("Workspace")

local regions = require(replicated_storage.World.Regions:Clone()) :: any

local rgb = Color3.fromRGB

type Deps = {
	kit: any,
	palette: any,
	nature: any,
}

type Clearing = {
	name: string,
	centre: Vector2,
	radius: number,
	purpose: string,
}

local OUTLINE: { Vector2 } = regions.Glimmerwood.outline
local VILLAGE: { Vector2 } = regions.FoldHaven.outline
local VILLAGE_FADE = 16 -- note: how far out from the village's felled ground trees take to reach the wood's edge density
local FRINGE = 60 -- note: within this many studs of the felled ground, young growth packs trees closer together
local FELLED_DEPTH = 8 -- note: how far into the felled ground stumps are left
local FELLED_STUMPS = 10
local CELL = 4
local SURFACE_DEPTH = 8
local TERRAIN_MIN = Vector3.new(24, -16, -472)
local TERRAIN_MAX = Vector3.new(424, 144, -88)
local SCULPTED = "GlimmerwoodSculpted"
local LITTER = Enum.Material.Salt
local MIN_GROUND = 9 -- note: lower land is beach

local MAIN_WIDTH = 6
local LOOP_WIDTH = 4
local PATH_SINK = 0.4

-- note: Fold Haven's lane (its LANE), painted by the village build; LANE_HALF is its painted half-width
local VILLAGE_LANE = {
	Vector2.new(36, -50),
	Vector2.new(68, -66),
	Vector2.new(100, -86),
	Vector2.new(130, -114),
	Vector2.new(158, -142),
}
local LANE_HALF = 5

-- note: the stile where the lane meets the main path; trees stand clear of its fence
local STILE = Vector2.new(158, -142)
local STILE_CLEARANCE = 18

-- note: the main path carries on from the end of Fold Haven's lane, over the stile and north through the wood
local MAIN_PATH = {
	Vector2.new(158, -142),
	Vector2.new(166, -158),
	Vector2.new(178, -180),
	Vector2.new(192, -202),
	Vector2.new(200, -224),
	Vector2.new(212, -244),
	Vector2.new(224, -262),
	Vector2.new(228, -284),
	Vector2.new(228, -306),
	Vector2.new(236, -326),
	Vector2.new(246, -346),
	Vector2.new(250, -364),
	Vector2.new(254, -384),
	Vector2.new(258, -406),
	Vector2.new(262, -428),
	Vector2.new(266, -456),
}

-- note: a footpath loops east past the woodcutter's camp, skirting its fire on the west side, and rejoins the main path
local LOOP_PATH = {
	Vector2.new(212, -244),
	Vector2.new(240, -246),
	Vector2.new(272, -256),
	Vector2.new(298, -274),
	Vector2.new(304, -298),
	Vector2.new(302, -324),
	Vector2.new(290, -346),
	Vector2.new(270, -360),
	Vector2.new(250, -364),
}

-- note: open ground for fights, the tutorial and landmarks; each is levelled in the terrain
local CLEARINGS: { Clearing } = {
	{ name = "SunGlade", centre = Vector2.new(196, -214), radius = 20, purpose = "Fight" },
	{ name = "FernGlade", centre = Vector2.new(184, -262), radius = 12, purpose = "Fold" },
	{ name = "OldBeech", centre = Vector2.new(252, -300), radius = 26, purpose = "Boss" },
	{ name = "PetGlade", centre = Vector2.new(208, -340), radius = 14, purpose = "Pet" },
	{ name = "Camp", centre = Vector2.new(318, -298), radius = 16, purpose = "Camp" },
	{ name = "Dell", centre = Vector2.new(262, -394), radius = 20, purpose = "Fight" },
}

local KNOLL = { centre = Vector2.new(252, -300), radius = 62, height = 3.5 }
local DELL = { centre = Vector2.new(262, -394), radius = 40, depth = 6 }

-- note: the pack's white woodland flower stands in for wood anemones, which carpet english beech woods in spring
local ANEMONE = "Wildflower2"
local FLOWERS = { "Wildflower1", "Wildflower3", "Wildflower4" }
local STICKS = { "Stick1", "Stick2", "Stick3", "Stick4", "Stick5" }
local PEBBLES = { "RockGroup1", "RockGroup2", "RockSmall" }
local BOULDERS = { "BoulderMoss", "BoulderMoss", "BoulderMedium", "BoulderLarge" }

local WEATHERED_OAK = rgb(112, 98, 82) -- note: grey-brown oak for posts and rails left out in the weather
local LANTERN_SPACING = 75
local LANTERN_RANGE = 22
local LANTERN_BRIGHTNESS = 1.6

local glimmerwood = {}

-- Geometry ------------------------------------------------------------------

local function smoothstep(edge0: number, edge1: number, x: number): number
	local t = math.clamp((x - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3 - 2 * t)
end

-- note: 0 on the village's felled ground, 1 from VILLAGE_FADE studs out from it
local function villageFade(point: Vector2): number
	return smoothstep(0, VILLAGE_FADE, -regions.signedDistance(VILLAGE, point))
end

-- note: 0 at the outline, 1 from 50 studs inside, thinning out toward the village
local function forestWeight(point: Vector2): number
	return smoothstep(4, 50, regions.signedDistance(OUTLINE, point)) * villageFade(point)
end

-- note: distance to a polyline, and how far along it the nearest point lies
local function polylineDistance(points: { Vector2 }, point: Vector2): (number, number)
	local best = math.huge
	local best_along = 0
	local walked = 0

	for i = 1, #points - 1 do
		local a = points[i]
		local edge = points[i + 1] - a
		local length = edge.Magnitude
		local t = math.clamp((point - a):Dot(edge) / (length * length), 0, 1)
		local distance = (point - (a + edge * t)).Magnitude
		if distance < best then
			best = distance
			best_along = walked + length * t
		end

		walked += length
	end

	return best, best_along
end

-- note: the point and direction a distance along a polyline
local function alongPolyline(points: { Vector2 }, distance: number): (Vector2, Vector2)
	local walked = 0
	for i = 1, #points - 1 do
		local edge = points[i + 1] - points[i]
		local length = edge.Magnitude
		if walked + length >= distance or i == #points - 1 then
			local t = math.clamp((distance - walked) / length, 0, 1)
			return points[i] + edge * t, edge.Unit
		end

		walked += length
	end

	return points[#points], (points[#points] - points[#points - 1]).Unit
end

local function polylineLength(points: { Vector2 }): number
	local total = 0
	for i = 1, #points - 1 do
		total += (points[i + 1] - points[i]).Magnitude
	end

	return total
end

-- note: how far a point is from the edge of the nearest path or the village lane (negative on it)
local function pathClearance(point: Vector2): number
	local main = polylineDistance(MAIN_PATH, point) - MAIN_WIDTH / 2
	local loop = polylineDistance(LOOP_PATH, point) - LOOP_WIDTH / 2
	local lane = polylineDistance(VILLAGE_LANE, point) - LANE_HALF
	return math.min(main, loop, lane)
end

local function nearestClearing(point: Vector2): (Clearing?, number)
	local nearest: Clearing? = nil
	local best = math.huge
	for _, clearing in CLEARINGS do
		local distance = (point - clearing.centre).Magnitude - clearing.radius
		if distance < best then
			best = distance
			nearest = clearing
		end
	end

	-- note: the distance returned is from the clearing's centre
	if nearest then
		return nearest, (point - nearest.centre).Magnitude
	end

	return nil, math.huge
end

-- Terrain -------------------------------------------------------------------

-- note: rolling ground, the old beech's knoll and the dell, faded in from the forest edge
local function shapeDelta(point: Vector2): number
	local weight = forestWeight(point)
	if weight <= 0 then
		return 0
	end

	local rolling = 6 * math.noise(point.X / 90, point.Y / 90, 1.7) + 2 * math.noise(point.X / 31, point.Y / 31, 4.3)
	local knoll = KNOLL.height * (1 - smoothstep(18, KNOLL.radius, (point - KNOLL.centre).Magnitude))
	local dell = -DELL.depth * (1 - smoothstep(10, DELL.radius, (point - DELL.centre).Magnitude))
	return weight * (rolling + knoll + dell)
end

-- note: the forest floor material for a column, or nil to keep what is there
local function floorMaterial(point: Vector2, slope: number, path: number): Enum.Material?
	local x = point.X
	local z = point.Y
	if path > 0.5 then
		return if math.noise(x / 11, z / 11, 2.2) > 0.3 then Enum.Material.Mud else Enum.Material.Ground
	end

	if path > 0.15 and math.noise(x / 9, z / 9, 6.1) > 0.35 then
		return Enum.Material.Mud
	end

	-- note: the village paints its own lane, a voxel wider than its half-width
	if polylineDistance(VILLAGE_LANE, point) < LANE_HALF + CELL then
		return nil
	end

	local weight = forestWeight(point)
	if weight <= 0 then
		return nil
	end

	if slope > 38 then
		return Enum.Material.Rock
	end

	local clearing, distance = nearestClearing(point)
	if clearing and distance < clearing.radius * 0.85 + 2.5 * math.noise(x / 8, z / 8, 3.3) then
		if clearing.name == "Dell" and distance < 9 then
			return Enum.Material.Mud
		end

		if clearing.name == "Camp" and distance < 7 then
			return Enum.Material.Ground
		end

		return Enum.Material.Grass
	end

	-- note: a ragged edge where the meadow grass gives way to the woodland floor
	if weight + 0.4 * math.noise(x / 23, z / 23, 5.5) < 0.45 then
		return nil
	end

	-- note: leaf litter under the densest canopy
	if math.noise(x / 38, z / 38, 7.7) > 0.05 then
		return LITTER
	end

	return Enum.Material.LeafyGrass
end

-- note: shapes the forest floor: rolling ground (first run only), levelled clearings, graded paths and its materials
function glimmerwood.terrain(deps: Deps): string
	local terrain = workspace.Terrain
	local shape = not terrain:GetAttribute(SCULPTED)
	local region = Region3.new(TERRAIN_MIN, TERRAIN_MAX)
	local channels = terrain:ReadVoxelChannels(region, CELL, { "SolidMaterial", "SolidOccupancy", "LiquidOccupancy" })
	local materials = channels.SolidMaterial
	local occupancy = channels.SolidOccupancy
	local size_x = #occupancy
	local size_y = #occupancy[1]
	local size_z = #occupancy[1][1]

	local function columnPoint(ix: number, iz: number): Vector2
		return Vector2.new(TERRAIN_MIN.X + (ix - 0.5) * CELL, TERRAIN_MIN.Z + (iz - 0.5) * CELL)
	end

	-- note: surface height of each column from its top filled voxel
	local base = table.create(size_x)
	local top_material = table.create(size_x)
	local heights = table.create(size_x)
	for ix = 1, size_x do
		base[ix] = table.create(size_z, 0)
		top_material[ix] = table.create(size_z, Enum.Material.Rock)
		heights[ix] = table.create(size_z, 0)
		for iz = 1, size_z do
			local height = TERRAIN_MIN.Y
			for iy = size_y, 1, -1 do
				local amount = occupancy[ix][iy][iz]
				if amount > 0 then
					height = TERRAIN_MIN.Y + (iy - 1) * CELL + amount * CELL
					top_material[ix][iz] = materials[ix][iy][iz]
					break
				end
			end

			base[ix][iz] = height
			heights[ix][iz] = if shape then height + shapeDelta(columnPoint(ix, iz)) else height
		end
	end

	local function sampleHeight(point: Vector2): number
		local u = math.clamp((point.X - TERRAIN_MIN.X) / CELL + 0.5, 1, size_x)
		local v = math.clamp((point.Y - TERRAIN_MIN.Z) / CELL + 0.5, 1, size_z)
		local iu = math.min(math.floor(u), size_x - 1)
		local iv = math.min(math.floor(v), size_z - 1)
		local tu = u - iu
		local tv = v - iv
		local top = heights[iu][iv] * (1 - tu) + heights[iu + 1][iv] * tu
		local bottom = heights[iu][iv + 1] * (1 - tu) + heights[iu + 1][iv + 1] * tu
		return top * (1 - tv) + bottom * tv
	end

	-- note: each clearing is levelled to its own average height, blending out past its edge
	for _, clearing in CLEARINGS do
		local total = 0
		local count = 0
		for ix = 1, size_x do
			for iz = 1, size_z do
				if (columnPoint(ix, iz) - clearing.centre).Magnitude < clearing.radius * 0.8 then
					total += heights[ix][iz]
					count += 1
				end
			end
		end

		local level = total / math.max(count, 1)
		for ix = 1, size_x do
			for iz = 1, size_z do
				local distance = (columnPoint(ix, iz) - clearing.centre).Magnitude
				local flatten = 1 - smoothstep(clearing.radius * 0.7, clearing.radius + 12, distance)
				heights[ix][iz] += (level - heights[ix][iz]) * flatten
			end
		end
	end

	-- note: each path bed follows the height of the ground beside it, smoothed over ~20 studs, and blends out over a
	-- shoulder; reading beside the bed rather than in it keeps reruns from sinking it further
	local path_mask = table.create(size_x)
	for ix = 1, size_x do
		path_mask[ix] = table.create(size_z, 0)
	end

	for _, route in { { points = MAIN_PATH, width = MAIN_WIDTH }, { points = LOOP_PATH, width = LOOP_WIDTH } } do
		local length = polylineLength(route.points)
		local half = route.width / 2
		local samples = {}
		for distance = 0, length, 2 do
			local point, direction = alongPolyline(route.points, distance)
			local across = Vector2.new(-direction.Y, direction.X) * (half + 4)
			table.insert(samples, (sampleHeight(point + across) + sampleHeight(point - across)) / 2)
		end

		local smoothed = table.create(#samples, 0)
		for i = 1, #samples do
			local total = 0
			local count = 0
			for j = math.max(i - 5, 1), math.min(i + 5, #samples) do
				total += samples[j]
				count += 1
			end
			smoothed[i] = total / count
		end

		for ix = 1, size_x do
			for iz = 1, size_z do
				local point = columnPoint(ix, iz)
				local distance, along = polylineDistance(route.points, point)
				if distance < half + 4 then
					local index = math.clamp(math.floor(along / 2 + 0.5) + 1, 1, #smoothed)
					local target = smoothed[index] - PATH_SINK
					local blend = 1 - smoothstep(half - 0.5, half + 4, distance)
					heights[ix][iz] += (target - heights[ix][iz]) * blend

					-- note: painted a little wider than the bed, since terrain blends materials across 4-stud voxels
					local ragged = distance + 1.2 * math.noise(point.X / 7, point.Y / 7, 9.1)
					local core = 1 - smoothstep(half + 0.5, half + 2.5, ragged)
					path_mask[ix][iz] = math.max(path_mask[ix][iz], core)
				end
			end
		end
	end

	-- note: rewrite only the columns that moved or change material; liquid is written back untouched
	local changed = 0
	for ix = 1, size_x do
		for iz = 1, size_z do
			local height = heights[ix][iz]
			local ix_left = math.max(ix - 1, 1)
			local ix_right = math.min(ix + 1, size_x)
			local iz_back = math.max(iz - 1, 1)
			local iz_front = math.min(iz + 1, size_z)
			local dx = (heights[ix_right][iz] - heights[ix_left][iz]) / ((ix_right - ix_left) * CELL)
			local dz = (heights[ix][iz_front] - heights[ix][iz_back]) / ((iz_front - iz_back) * CELL)
			local slope = math.deg(math.atan(math.sqrt(dx * dx + dz * dz)))
			local surface = floorMaterial(columnPoint(ix, iz), slope, path_mask[ix][iz])

			if surface or math.abs(height - base[ix][iz]) > 0.02 then
				changed += 1
				for iy = 1, size_y do
					local y0 = TERRAIN_MIN.Y + (iy - 1) * CELL
					local amount = math.clamp((height - y0) / CELL, 0, 1)
					local was_solid = occupancy[ix][iy][iz] > 0

					if amount <= 0 then
						materials[ix][iy][iz] = Enum.Material.Air
						occupancy[ix][iy][iz] = 0
					else
						if y0 + CELL > height - SURFACE_DEPTH then
							if surface then
								materials[ix][iy][iz] = surface
							elseif not was_solid then
								materials[ix][iy][iz] = top_material[ix][iz]
							end
						elseif not was_solid then
							materials[ix][iy][iz] = Enum.Material.Rock
						end

						occupancy[ix][iy][iz] = amount
					end
				end
			end
		end
	end

	terrain:WriteVoxelChannels(region, CELL, {
		SolidMaterial = materials,
		SolidOccupancy = occupancy,
		LiquidOccupancy = channels.LiquidOccupancy,
	})
	terrain:SetAttribute(SCULPTED, true)

	return string.format("terrain: %d of %d columns rewritten", changed, size_x * size_z)
end

-- Placement helpers ---------------------------------------------------------

local function freshFolder(kit, name: string): Instance
	local root = kit.folder(workspace, "Glimmerwood")
	local old = root:FindFirstChild(name)
	if old then
		old:Destroy()
	end

	return kit.folder(root, name)
end

-- note: a model that leans with the wind (ForestAmbience); atomic so its parts stream in together
local function sway(model: Model, degrees: number)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("Sway", degrees)
	collection_service:AddTag(model, "WindSway")
end

-- note: ground plants are seen close up but in numbers, so their meshes drop to automatic fidelity
local function lighten(model: Model)
	for _, part in model:GetDescendants() do
		if part:IsA("MeshPart") and part.RenderFidelity == Enum.RenderFidelity.Precise then
			part.RenderFidelity = Enum.RenderFidelity.Automatic
		end
	end
end

local function slopeAt(kit, point: Vector2): number
	local dx = kit.groundY(point.X + 3, point.Y) - kit.groundY(point.X - 3, point.Y)
	local dz = kit.groundY(point.X, point.Y + 3) - kit.groundY(point.X, point.Y - 3)
	return math.deg(math.atan(math.sqrt(dx * dx + dz * dz) / 6))
end

local function groundFrame(kit, point: Vector2): CFrame
	return CFrame.new(point.X, kit.groundY(point.X, point.Y), point.Y)
end

local function pick(random: Random, names: { string }): string
	return names[random:NextInteger(1, #names)]
end

-- note: points over the outline's bounds, none closer to another than its spacing (dart throwing on a hashed grid)
local function scatter(random: Random, tries: number, spacing: (Vector2) -> number, accept: (Vector2) -> boolean): { Vector2 }
	local min_corner = Vector2.new(math.huge, math.huge)
	local max_corner = Vector2.new(-math.huge, -math.huge)
	for _, point in OUTLINE do
		min_corner = min_corner:Min(point)
		max_corner = max_corner:Max(point)
	end

	local bucket = 12
	local grid: { [string]: { Vector2 } } = {}
	local points = {}
	for _ = 1, tries do
		local point = Vector2.new(random:NextNumber(min_corner.X - 8, max_corner.X + 8), random:NextNumber(min_corner.Y - 8, max_corner.Y + 8))
		local gap = spacing(point)
		local cell_x = math.floor(point.X / bucket)
		local cell_z = math.floor(point.Y / bucket)
		local reach = math.ceil(gap / bucket)
		local free = true

		for i = cell_x - reach, cell_x + reach do
			for j = cell_z - reach, cell_z + reach do
				for _, other in grid[i .. "," .. j] or {} do
					if (other - point).Magnitude < gap then
						free = false
						break
					end
				end

				if not free then
					break
				end
			end

			if not free then
				break
			end
		end

		if free and accept(point) then
			local key = cell_x .. "," .. cell_z
			local list = grid[key] or {}
			grid[key] = list
			table.insert(list, point)
			table.insert(points, point)
		end
	end

	return points
end

-- Trees ---------------------------------------------------------------------

-- note: young trees and maples fill the edges, tall beeches and the odd giant or dead snag fill the middle
local function chooseTree(random: Random, weight: number): (string, number)
	local roll = random:NextNumber()
	if weight < 0.35 then
		if roll < 0.5 then
			return "BeechYoung", random:NextNumber(13, 19)
		elseif roll < 0.8 then
			return "Maple", random:NextNumber(18, 24)
		end

		return "Beech", random:NextNumber(22, 28)
	end

	if roll < 0.34 then
		return "Beech", random:NextNumber(26, 32)
	elseif roll < 0.58 then
		return "BeechTall", random:NextNumber(30, 36)
	elseif roll < 0.7 then
		return "Maple", random:NextNumber(20, 26)
	elseif roll < 0.84 then
		return "BeechYoung", random:NextNumber(14, 20)
	elseif roll < 0.95 then
		return "BeechLarge", random:NextNumber(34, 40)
	end

	return "BeechSnag", random:NextNumber(18, 24)
end

function glimmerwood.trees(deps: Deps): number
	local kit, palette, nature = deps.kit, deps.palette, deps.nature
	local parent = freshFolder(kit, "Trees")
	local random = Random.new(311)

	-- note: toward the village young growth fills in the edge, so trees stand up to a third closer
	local function spacing(point: Vector2): number
		local fringe = 1 - smoothstep(VILLAGE_FADE, FRINGE, -regions.signedDistance(VILLAGE, point))
		local base = 13 + 8 * (0.5 + math.noise(point.X / 60, point.Y / 60, 2.9))
		return base * (1 - 0.35 * fringe)
	end

	local function accept(point: Vector2): boolean
		if regions.signedDistance(OUTLINE, point) < 2 then
			return false
		end

		-- note: toward the village the trees thin out to none at its felled ground
		if random:NextNumber() > (0.45 + 0.55 * forestWeight(point)) * villageFade(point) then
			return false
		end

		if pathClearance(point) < 2.5 then
			return false
		end

		if (point - STILE).Magnitude < STILE_CLEARANCE then
			return false
		end

		local clearing, distance = nearestClearing(point)
		if clearing and distance < clearing.radius + 4 then
			return false
		end

		if kit.groundY(point.X, point.Y) < MIN_GROUND then
			return false
		end

		return slopeAt(kit, point) < 28
	end

	local points = scatter(random, 6000, spacing, accept)
	for _, point in points do
		local name, height = chooseTree(random, forestWeight(point))
		local model = nature.woodlandTree(kit, palette, parent, groundFrame(kit, point), random, name, height)
		sway(model, 0.7)
	end

	return #points
end

-- Undergrowth ---------------------------------------------------------------

function glimmerwood.undergrowth(deps: Deps): number
	local kit, palette, nature = deps.kit, deps.palette, deps.nature
	local parent = freshFolder(kit, "Undergrowth")
	local random = Random.new(733)
	local placed = 0

	local function plant(point: Vector2, name: string, height: number, degrees: number)
		local model = nature.groundCover(kit, palette, parent, groundFrame(kit, point), random, name, height)
		lighten(model)
		if degrees > 0 then
			sway(model, degrees)
		end

		placed += 1
	end

	local function accept(point: Vector2): boolean
		if regions.signedDistance(OUTLINE, point) < -6 then
			return false
		end

		-- note: the village keeps its felled ground as open grass
		if villageFade(point) <= 0 then
			return false
		end

		if pathClearance(point) < 0.8 then
			return false
		end

		return kit.groundY(point.X, point.Y) >= MIN_GROUND and slopeAt(kit, point) < 32
	end

	local points = scatter(random, 9000, function()
		return 5.5
	end, accept)

	for _, point in points do
		local weight = forestWeight(point)
		local clearing, distance = nearestClearing(point)
		local roll = random:NextNumber()

		if clearing and distance < clearing.radius - 1 then
			-- note: glades are meadow: flowers and clover, kept clear round the camp fire and the old beech's trunk
			local kept_clear = (clearing.name == "Camp" or clearing.name == "OldBeech") and distance < 9
			if not kept_clear then
				if roll < 0.25 then
					plant(point, pick(random, FLOWERS), random:NextNumber(1.6, 2.4), 5)
				elseif roll < 0.45 then
					plant(point, "Clover", random:NextNumber(0.8, 1.2), 0)
				end
			end

		elseif weight > 0.05 or roll < 0.3 then
			-- note: ferns grow in drifts and anemones in carpets, both clumped by noise rather than sprinkled evenly
			local drift = math.noise(point.X / 26, point.Y / 26, 3.1)
			if drift > 0.12 then
				if roll < 0.7 then
					plant(point, "Fern", random:NextNumber(3, 4.5), 3)
				elseif roll < 0.9 then
					plant(point, "FernTall", random:NextNumber(4, 5.5), 3)
				else
					plant(point, "FernDying", random:NextNumber(2.5, 3.5), 2)
				end
			elseif drift < -0.22 then
				plant(point, ANEMONE, random:NextNumber(1.4, 2), 5)
			elseif roll < 0.08 then
				plant(point, pick(random, STICKS), random:NextNumber(0.25, 0.45), 0)
			elseif roll < 0.11 then
				plant(point, "Branch", random:NextNumber(1.2, 1.8), 0)
			elseif roll < 0.17 then
				plant(point, "BeechSapling", random:NextNumber(4, 7), 1.5)
			elseif roll < 0.21 then
				plant(point, pick(random, PEBBLES), random:NextNumber(0.6, 1.4), 0)
			elseif weight < 0.4 and roll < 0.3 then
				-- note: a shrub layer at the wood's edge
				nature.shrub(kit, palette, parent, groundFrame(kit, point), random, random:NextNumber(3, 5))
				placed += 1
			end
		end
	end

	return placed
end

-- Deadwood and rocks --------------------------------------------------------

function glimmerwood.deadwood(deps: Deps): number
	local kit, palette, nature = deps.kit, deps.palette, deps.nature
	local parent = freshFolder(kit, "Deadwood")
	local random = Random.new(919)

	local function accept(point: Vector2): boolean
		-- note: deadwood near the village has gone for firewood
		if regions.signedDistance(OUTLINE, point) < 10 or pathClearance(point) < 5 or villageFade(point) < 1 then
			return false
		end

		local clearing, distance = nearestClearing(point)
		if clearing and distance < clearing.radius + 2 then
			return false
		end

		return kit.groundY(point.X, point.Y) >= MIN_GROUND and slopeAt(kit, point) < 12
	end

	local points = scatter(random, 800, function()
		return 34
	end, accept)

	local count = 0
	for index, point in points do
		local frame = groundFrame(kit, point)
		if index <= 8 then
			local name = if random:NextNumber() < 0.65 then "FallenTreeMossy" else "FallenTree"
			nature.solidFoliage(kit, palette, parent, frame * CFrame.new(0, -0.4, 0), random, name, random:NextNumber(3.8, 5))
		elseif index <= 18 then
			nature.solidFoliage(kit, palette, parent, frame, random, "Stump", random:NextNumber(2.8, 4.2))
		else
			break
		end

		count += 1
	end

	return count
end

function glimmerwood.rocks(deps: Deps): number
	local kit, palette, nature = deps.kit, deps.palette, deps.nature
	local parent = freshFolder(kit, "Rocks")
	local random = Random.new(557)

	-- note: boulders gather on the rising ground in the north-east
	local function accept(point: Vector2): boolean
		if regions.signedDistance(OUTLINE, point) < 6 or pathClearance(point) < 3 or villageFade(point) <= 0 then
			return false
		end

		local clearing, distance = nearestClearing(point)
		if clearing and distance < clearing.radius then
			return false
		end

		local ground = kit.groundY(point.X, point.Y)
		return ground >= MIN_GROUND and random:NextNumber() < 0.25 + ground / 60
	end

	local points = scatter(random, 800, function()
		return 26
	end, accept)

	local count = 0
	for index, point in points do
		if index > 18 then
			break
		end

		local frame = groundFrame(kit, point)
		if kit.groundY(point.X, point.Y) > 30 and index % 4 == 0 then
			nature.rock(kit, palette, parent, frame, random, random:NextNumber(3.5, 5.5))
		else
			nature.solidFoliage(kit, palette, parent, frame * CFrame.new(0, -0.5, 0), random, pick(random, BOULDERS), random:NextNumber(2.5, 6))
		end

		count += 1
	end

	return count
end

-- note: a sawn stump: a bark post with a flat, pale cut on top, fresh or weathered grey
local function sawnStump(deps: Deps, parent: Instance, frame: CFrame, random: Random)
	local kit, palette = deps.kit, deps.palette
	local model = kit.model(parent, "Stump", frame)
	local height = random:NextNumber(2.2, 3)
	local diameter = random:NextNumber(1.6, 2.6)
	local sink = 0.6
	kit.post(model, height + sink, diameter, frame * CFrame.new(0, -sink, 0), palette.bark, "Bark")

	local wood = if random:NextNumber() < 0.5 then palette.oak_light else palette.driftwood
	local tilt = CFrame.Angles(random:NextNumber(-0.06, 0.06), 0, random:NextNumber(-0.06, 0.06))
	local cut = kit.cylinder(model, 0.2, diameter - 0.15, frame * CFrame.new(0, height, 0) * tilt * CFrame.Angles(0, 0, math.rad(90)), wood, "Cut")
	kit.detail(cut, true)
end

-- note: sawn stumps along the edge of the village's felled ground, where Fold Haven has cut the wood back
function glimmerwood.felling(deps: Deps): number
	local kit = deps.kit
	local parent = freshFolder(kit, "Felled")
	local random = Random.new(271)

	local function accept(point: Vector2): boolean
		local inside = regions.signedDistance(VILLAGE, point)
		if inside > FELLED_DEPTH or inside < -4 or pathClearance(point) < 3 then
			return false
		end

		return kit.groundY(point.X, point.Y) >= MIN_GROUND and slopeAt(kit, point) < 12
	end

	local points = scatter(random, 3000, function()
		return 10
	end, accept)

	local count = 0
	for _, point in points do
		if count >= FELLED_STUMPS then
			break
		end

		sawnStump(deps, parent, groundFrame(kit, point) * CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0), random)
		count += 1
	end

	return count
end

-- Landmarks -----------------------------------------------------------------

-- note: a stretch of post-and-rail fence along the wood's edge where the lane ends, a stile to climb in the middle
-- (tutorial: jump) and a shrub at each end so the fence reads as a boundary rather than a lone prop
local function stile(deps: Deps, parent: Instance)
	local kit, palette, nature = deps.kit, deps.palette, deps.nature
	local random = Random.new(17)
	local model = kit.model(parent, "Stile")
	local from = Vector3.new(130, 0, -114)
	local to = Vector3.new(STILE.X, 0, STILE.Y)
	local along = (to - from).Unit
	local centre = Vector3.new(to.X, kit.groundY(to.X, to.Z), to.Z)
	local frame = CFrame.lookAt(centre, centre + along)
	local wood = kit.tint(palette.oak, WEATHERED_OAK)
	local bay = 4.2
	local bays = 3

	-- note: each post stands on the ground below it; rails run between neighbouring posts at their mean ground height
	local function footAt(x: number): CFrame
		local spot = frame * CFrame.new(x, 0, 0)
		return kit.onGround(spot)
	end

	for _, side in { -1, 1 } do
		for index = 0, bays do
			local x = side * (2.1 + index * bay)
			kit.post(model, 4.8, 0.7, footAt(x) * CFrame.new(0, -0.6, 0), wood, "Post")

			if index < bays then
				local middle = side * (2.1 + (index + 0.5) * bay)
				local ground = (footAt(x).Y + footAt(x + side * bay).Y) / 2
				local rail_frame = frame * CFrame.new(middle, 0, 0)
				rail_frame += Vector3.new(0, ground - rail_frame.Y, 0)
				for _, y in { 1.2, 2.5, 3.7 } do
					kit.part(model, Vector3.new(bay - 0.5, 0.45, 0.25), rail_frame * CFrame.new(0, y, 0.3), wood, "Rail")
				end
			end
		end

		local end_x = side * (2.1 + bays * bay + 2.5)
		nature.shrub(kit, palette, parent, footAt(end_x), random, random:NextNumber(4.5, 5.5))
	end

	kit.part(model, Vector3.new(4.4, 0.45, 0.3), frame * CFrame.new(0, 3.1, 0.3), wood, "TopRail")
	for _, z in { -1.1, 1.1 } do
		kit.part(model, Vector3.new(3.6, 0.3, 1), frame * CFrame.new(0, 1.5, z), wood, "Step")
		for _, x in { -1.4, 1.4 } do
			kit.part(model, Vector3.new(0.35, 1.95, 0.35), frame * CFrame.new(x, 0.375, z), wood, "StepLeg")
		end
	end
end

-- note: the old beech: a giant in the middle of its ring clearing on the knoll, ferns and mossy stones round its feet
local function oldBeech(deps: Deps, parent: Instance)
	local kit, palette, nature = deps.kit, deps.palette, deps.nature
	local random = Random.new(41)
	local clearing = CLEARINGS[3]
	local tree = nature.woodlandTree(kit, palette, parent, groundFrame(kit, clearing.centre), random, "BeechLarge", 54)
	tree.Name = "OldBeech"
	sway(tree, 0.35)

	for i = 1, 5 do
		local angle = i / 5 * math.pi * 2 + random:NextNumber(-0.3, 0.3)
		local point = clearing.centre + Vector2.new(math.cos(angle), math.sin(angle)) * random:NextNumber(5, 8)
		nature.solidFoliage(kit, palette, parent, groundFrame(kit, point) * CFrame.new(0, -0.6, 0), random, "BoulderMoss", random:NextNumber(1.6, 2.6))
	end

	for i = 1, 9 do
		local angle = i / 9 * math.pi * 2 + random:NextNumber(-0.2, 0.2)
		local point = clearing.centre + Vector2.new(math.cos(angle), math.sin(angle)) * random:NextNumber(4, 7)
		local fern = nature.groundCover(kit, palette, parent, groundFrame(kit, point), random, "Fern", random:NextNumber(3, 4))
		lighten(fern)
		sway(fern, 3)
	end
end

-- note: the woodcutter's camp: a fire ring, log seats, a woodpile and a chopping block
local function camp(deps: Deps, parent: Instance)
	local kit, palette, nature = deps.kit, deps.palette, deps.nature
	local random = Random.new(97)
	local clearing = CLEARINGS[5]
	local centre = groundFrame(kit, clearing.centre).Position
	local model = kit.model(parent, "Camp", CFrame.new(centre))

	for i = 1, 9 do
		local angle = i / 9 * math.pi * 2 + random:NextNumber(-0.1, 0.1)
		local at = centre + Vector3.new(math.cos(angle) * 2.3, 0, math.sin(angle) * 2.3)
		local size = Vector3.new(random:NextNumber(0.8, 1.1), random:NextNumber(0.5, 0.7), random:NextNumber(0.7, 1))
		local tilt = CFrame.Angles(random:NextNumber(-0.15, 0.15), -angle, random:NextNumber(-0.15, 0.15))
		local stone = kit.tint(palette.boulder, palette.boulder.color:Lerp(Color3.new(), random:NextNumber(0.05, 0.25)))
		kit.part(model, size, kit.onGround(CFrame.new(at)) * CFrame.new(0, size.Y * 0.25, 0) * tilt, stone, "Stone")
	end

	local embers = kit.part(model, Vector3.new(2.4, 0.2, 2.4), CFrame.new(centre + Vector3.new(0, 0.05, 0)), palette.ember, "Embers")
	embers.Shape = Enum.PartType.Cylinder
	embers.CFrame = CFrame.new(centre + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
	embers.Size = Vector3.new(0.2, 2.4, 2.4)

	for i = 1, 3 do
		local brand = CFrame.new(centre + Vector3.new(0, 0.45, 0)) * CFrame.Angles(0, i * 2.1, 0) * CFrame.new(0.5, 0, 0) * CFrame.Angles(0, 0, math.rad(22))
		kit.cylinder(model, 2.6, 0.45, brand, palette.soot, "Brand")
	end
	kit.detail(model)

	-- note: the fire: flames, a little smoke that the wind carries off, and a warm light at night
	local fire = Instance.new("Attachment")
	fire.Name = "Fire"
	fire.Position = Vector3.new(0.6, 0, 0)
	fire.Parent = embers

	local flames = Instance.new("ParticleEmitter")
	flames.Name = "Flames"
	flames.Texture = "rbxasset://textures/particles/fire_main.dds"
	flames.Color = ColorSequence.new(rgb(255, 196, 120), rgb(230, 92, 38))
	flames.LightEmission = 1
	flames.LightInfluence = 0
	flames.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0.2) })
	flames.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	flames.Lifetime = NumberRange.new(0.7, 1.2)
	flames.Rate = 16
	flames.Speed = NumberRange.new(1.5, 2.5)
	flames.SpreadAngle = Vector2.new(12, 12)
	flames.Rotation = NumberRange.new(0, 360)
	flames.RotSpeed = NumberRange.new(-40, 40)
	flames.EmissionDirection = Enum.NormalId.Right
	flames.Parent = fire

	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(rgb(150, 146, 140))
	smoke.LightInfluence = 1
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 7) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(5, 8)
	smoke.Rate = 3
	smoke.Speed = NumberRange.new(2, 3)
	smoke.SpreadAngle = Vector2.new(8, 8)
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-10, 10)
	smoke.Drag = 0.4
	smoke.WindAffectsDrag = true
	smoke.EmissionDirection = Enum.NormalId.Right
	smoke.Parent = fire

	local light = Instance.new("PointLight")
	light.Color = rgb(255, 164, 96)
	light.Range = 24
	light.Brightness = 1.6
	light.Shadows = false
	light.Enabled = false
	light.Parent = fire
	collection_service:AddTag(light, "NightLight")

	-- note: three log seats round the fire
	for i = 1, 3 do
		local angle = i / 3 * math.pi * 2 + 0.4
		local at = centre + Vector3.new(math.cos(angle) * 5.5, 0, math.sin(angle) * 5.5)
		local seat = kit.onGround(CFrame.new(at)) * CFrame.Angles(0, -angle + math.pi / 2, 0) * CFrame.new(0, 0.55, 0)
		kit.cylinder(model, 5, 1.4, seat, palette.bark, "Seat")
	end

	-- note: a woodpile of split logs at the clearing's edge, and a chopping block beside it
	local pile = kit.onGround(CFrame.new(centre + Vector3.new(9, 0, -6)) * CFrame.Angles(0, 0.5, 0))
	local log_style = kit.tint(palette.bark, rgb(120, 98, 74))
	for row = 0, 2 do
		for column = 0, 3 - row do
			local at = pile * CFrame.new(0, 0.5 + row * 0.85, (column - (3 - row) / 2) * 0.95)
			kit.cylinder(model, 4.2, 0.9, at, log_style, "Log")
		end
	end

	nature.solidFoliage(kit, palette, model, kit.onGround(CFrame.new(centre + Vector3.new(6, 0, -10))), random, "Stump", 2)
end

-- note: a rough oak post with a hanging lantern over the path; lit at night only and without shadows, to stay cheap
local function lanternPost(deps: Deps, parent: Instance, frame: CFrame): Model
	local kit, palette = deps.kit, deps.palette
	local model = kit.model(parent, "LanternPost", frame)
	local wood = kit.tint(palette.oak, WEATHERED_OAK)
	kit.post(model, 8.2, 0.55, frame * CFrame.new(0, -0.6, 0), wood, "Post")
	kit.part(model, Vector3.new(0.4, 0.4, 2.6), frame * CFrame.new(0, 7.2, -1.1), wood, "Arm")
	kit.part(model, Vector3.new(0.25, 0.25, 1.6), frame * CFrame.new(0, 6.5, -0.55) * CFrame.Angles(math.rad(-40), 0, 0), wood, "Brace")

	local lantern = kit.placePrefab("HangingLantern", model, frame * CFrame.new(0, 7, -2.1))
	local glass = lantern:FindFirstChild("Glass") :: BasePart
	local light = lantern:FindFirstChildWhichIsA("PointLight", true) :: PointLight
	light.Parent = glass
	light.Enabled = false
	light.Shadows = false
	light.Range = LANTERN_RANGE
	light.Brightness = LANTERN_BRIGHTNESS
	collection_service:AddTag(light, "NightLight")
	collection_service:AddTag(glass, "NightLight")

	local flame = lantern:FindFirstChild("Flame")
	if flame then
		flame:Destroy()
	end

	kit.detail(lantern)
	return model
end

function glimmerwood.landmarks(deps: Deps)
	local parent = freshFolder(deps.kit, "Landmarks")
	stile(deps, parent)
	oldBeech(deps, parent)
	camp(deps, parent)
end

-- note: lanterns every LANTERN_SPACING studs along the main path, sides alternating, and one where the loop leaves it
function glimmerwood.lanterns(deps: Deps): number
	local kit = deps.kit
	local parent = freshFolder(kit, "Lanterns")
	local spots = {}
	local side = 1
	for distance = 16, polylineLength(MAIN_PATH) - 20, LANTERN_SPACING do
		table.insert(spots, { route = MAIN_PATH, distance = distance, offset = side * (MAIN_WIDTH / 2 + 2.2) })
		side = -side
	end
	table.insert(spots, { route = LOOP_PATH, distance = 12, offset = -(LOOP_WIDTH / 2 + 2) })

	for _, spot in spots do
		local point, direction = alongPolyline(spot.route, spot.distance)
		local across = Vector2.new(-direction.Y, direction.X)
		local post = point + across * spot.offset
		local foot = Vector3.new(post.X, kit.groundY(post.X, post.Y), post.Y)
		local toward = Vector3.new(point.X, foot.Y, point.Y)
		lanternPost(deps, parent, CFrame.lookAt(foot, toward))
	end

	return #spots
end

-- Mist ----------------------------------------------------------------------

-- note: a low emitter box of slow, faint smoke; ForestAmbience sets its rate by the time of day from the Rate attribute
local function mistSource(parent: Instance, centre: Vector3, size: number, rate: number)
	local part = Instance.new("Part")
	part.Name = "MistSource"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(size, 1, size)
	part.CFrame = CFrame.new(centre + Vector3.new(0, 3, 0))
	part.Parent = parent

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Mist"
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.Color = ColorSequence.new(rgb(206, 214, 206))
	emitter.LightInfluence = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 10), NumberSequenceKeypoint.new(1, 17) })
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.87),
		NumberSequenceKeypoint.new(0.7, 0.89),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(12, 16)
	emitter.Rate = rate
	emitter.Speed = NumberRange.new(0.2, 0.6)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-4, 4)
	emitter.Drag = 0.08
	emitter.WindAffectsDrag = true
	emitter:SetAttribute("Rate", rate)
	emitter.Parent = part
	collection_service:AddTag(emitter, "ForestMist")
end

-- note: mist pools in the dell and the deepest hollows of the rolling ground
function glimmerwood.mist(deps: Deps): number
	local kit = deps.kit
	local parent = freshFolder(kit, "Mist")
	local dell = Vector3.new(DELL.centre.X, kit.groundY(DELL.centre.X, DELL.centre.Y), DELL.centre.Y)
	mistSource(parent, dell + Vector3.new(-8, 0, 4), 34, 0.7)
	mistSource(parent, dell + Vector3.new(10, 0, -6), 30, 0.6)

	local hollows = {}
	for x = 100, 400, 24 do
		for z = -440, -160, 24 do
			local point = Vector2.new(x, z)
			if regions.signedDistance(OUTLINE, point) > 30 and (point - DELL.centre).Magnitude > 70 then
				local ground = kit.groundY(x, z)
				local around = 0
				for i = 1, 8 do
					local angle = i / 8 * math.pi * 2
					around += kit.groundY(x + math.cos(angle) * 26, z + math.sin(angle) * 26)
				end

				table.insert(hollows, { point = point, depth = around / 8 - ground })
			end
		end
	end

	table.sort(hollows, function(a, b)
		return a.depth > b.depth
	end)

	local chosen = {}
	for _, hollow in hollows do
		if #chosen >= 5 or hollow.depth < 0.8 then
			break
		end

		local spaced = true
		for _, other in chosen do
			if (other - hollow.point).Magnitude < 70 then
				spaced = false
			end
		end

		if spaced then
			table.insert(chosen, hollow.point)
			mistSource(parent, groundFrame(kit, hollow.point).Position, 30, 0.5)
		end
	end

	return 2 + #chosen
end

-- Clearings -----------------------------------------------------------------

-- note: invisible markers for spawners and the tutorial: Radius and Purpose attributes on each
function glimmerwood.clearings(deps: Deps)
	local kit = deps.kit
	local parent = freshFolder(kit, "Clearings")
	for _, clearing in CLEARINGS do
		local marker = Instance.new("Part")
		marker.Name = clearing.name
		marker.Anchored = true
		marker.CanCollide = false
		marker.CanQuery = false
		marker.CanTouch = false
		marker.CastShadow = false
		marker.Transparency = 1
		marker.Size = Vector3.new(1, 1, 1)
		marker.CFrame = groundFrame(kit, clearing.centre) + Vector3.new(0, 0.5, 0)
		marker:SetAttribute("Radius", clearing.radius)
		marker:SetAttribute("Purpose", clearing.purpose)
		marker.Parent = parent
	end
end

-- Build ---------------------------------------------------------------------

-- note: everything above the terrain; safe to run again
function glimmerwood.objects(deps: Deps): string
	local trees = glimmerwood.trees(deps)
	local plants = glimmerwood.undergrowth(deps)
	local deadwood = glimmerwood.deadwood(deps)
	local rocks = glimmerwood.rocks(deps)
	local stumps = glimmerwood.felling(deps)
	glimmerwood.landmarks(deps)
	local lanterns = glimmerwood.lanterns(deps)
	local mist = glimmerwood.mist(deps)
	glimmerwood.clearings(deps)
	return string.format("trees %d, plants %d, deadwood %d, rocks %d, stumps %d, lanterns %d, mist %d", trees, plants, deadwood, rocks, stumps, lanterns, mist)
end

return glimmerwood
