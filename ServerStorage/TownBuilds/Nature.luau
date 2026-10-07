--!strict
--[[
	Nature
	What: builds trees, shrubs, ferns, flowers, climbers, rocks, hedgerows, Cornish hedges and stone walls straight into a parent,
		each one varied by a seeded Random so reruns give the same result
	Used by: the studio assistant (edit mode) through the TownBuilds modules; nothing requires it at runtime
	Needs: kit (BuildKit) and palette (BuildPalette), passed in because studio caches required modules;
		trees, shrubs, ferns and climbers copy the meshes in ServerStorage.Foliage (Roblox's Forest Pack)
	Frames: single pieces stand on their frame; lines of hedge or wall follow points and drop onto the terrain
	Wind: the prevailing wind comes off the sea from the south-west, so coastal trees lean toward the north-east (+x, -z)
	Cost: leaves, flowers and scrub skip collision and queries; an invisible box in each trunk and along each hedgerow keeps them solid;
		rocks are plain blocks
]]

local server_storage = game:GetService("ServerStorage")
local workspace = game:GetService("Workspace")

local rgb = Color3.fromRGB

type Style = { material: Enum.Material, color: Color3, variant: string?, transparency: number? }

local WIND = Vector3.new(1, 0, -1).Unit
local FLOWERS = {
	rgb(198, 88, 106),
	rgb(152, 122, 178),
	rgb(234, 200, 92),
	rgb(240, 236, 224),
	rgb(216, 130, 162),
	rgb(206, 96, 66),
}
local SPIKES = {
	rgb(190, 110, 170),
	rgb(228, 150, 172),
	rgb(98, 112, 190),
	rgb(240, 232, 214),
}
local APPLES = { rgb(178, 52, 42), rgb(196, 146, 52), rgb(122, 150, 58) }
local LICHEN = rgb(150, 152, 124)

-- note: SurfaceAppearance tints; a laurel tinted this way turns gorse-dark with yellow blossom, hawthorn leaves run darker,
-- and the yellow-green leaf patch becomes ivy
local GORSE_TINT = rgb(245, 204, 80)
local HAWTHORN_TINT = rgb(206, 222, 190)
local IVY_TINT = rgb(160, 196, 128)

-- note: Foliage models by role; a repeated name is picked more often
local BROADLEAVES = { "Beech", "BeechTall", "Broadleaf", "BeechYoung" }
local HAWTHORNS = { "Maple", "Dogwood" }
local SHRUBS = { "Rhododendron", "Rhododendron", "Laurel", "RhododendronBloom" }
local HEDGE_BUSHES = { "Laurel", "Laurel", "Rhododendron", "BeechSapling" }

local nature = {}

-- Helpers -------------------------------------------------------------------

local function bloomStyle(color: Color3): Style
	return { material = Enum.Material.Fabric, color = color }
end

local function pick(random: Random, names: { string }): string
	return names[random:NextInteger(1, #names)]
end

local function spin(random: Random): CFrame
	return CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
end

local function foliageSource(name: string): Model
	local library = server_storage:FindFirstChild("Foliage")
	assert(library, "ServerStorage.Foliage is missing; it holds the Forest Pack meshes")

	local source = library:FindFirstChild(name)
	assert(source and source:IsA("Model"), "ServerStorage.Foliage." .. name .. " is missing")
	return source
end

-- note: the scale that makes a Foliage model a given height
local function scaleFor(name: string, height: number): number
	return height / (foliageSource(name):GetAttribute("Height") :: number)
end

-- note: a copy of a Foliage model at a scale; its pivot, the trunk's foot or the base centre, lands on the frame
local function placeFoliage(parent: Instance, name: string, frame: CFrame, scale: number): Model
	local model = foliageSource(name):Clone()
	model:ScaleTo(model:GetScale() * scale)
	model:PivotTo(frame)
	model.Parent = parent
	return model
end

-- note: tints through each SurfaceAppearance; trunks keep their bark unless whole is set
local function tint(model: Model, color: Color3, whole: boolean?)
	for _, appearance in model:GetDescendants() do
		if appearance:IsA("SurfaceAppearance") and (whole or (appearance.Parent :: Instance).Name ~= "Trunk") then
			appearance.Color = color
		end
	end
end

-- note: the leaf-card mesh of a Foliage model, the one whose SurfaceAppearance cuts out with alpha
local function crownOf(model: Model): BasePart?
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local appearance = part:FindFirstChildOfClass("SurfaceAppearance")
			if appearance and appearance.AlphaMode == Enum.AlphaMode.Transparency then
				return part
			end
		end
	end

	return nil
end

-- note: an invisible box up the trunk from its foot, so the meshes themselves skip physics
local function trunkCollider(kit, model: Model, diameter: number, height: number)
	kit.collider(model, Vector3.new(diameter, height, diameter), model:GetPivot() * CFrame.new(0, height / 2, 0))
end

-- note: a frame on the ground at a point, sloped to follow the terrain from one point to the next
local function runFrame(kit, from: Vector3, to: Vector3): (CFrame, number)
	local ground_from = Vector3.new(from.X, kit.groundY(from.X, from.Z), from.Z)
	local ground_to = Vector3.new(to.X, kit.groundY(to.X, to.Z), to.Z)
	local along = (ground_to - ground_from).Unit
	local across = along:Cross(Vector3.yAxis).Unit
	local up = across:Cross(along)
	return CFrame.fromMatrix((ground_from + ground_to) / 2, along, up, across), (ground_to - ground_from).Magnitude
end

-- Flowers -------------------------------------------------------------------

-- note: leafy mounds with flower heads on top, colors from a cottage-garden set
function nature.flowers(kit, palette, parent: Instance, frame: CFrame, random: Random, count: number, spread: Vector2, scale: number)
	for _ = 1, count do
		local base = frame * CFrame.new(random:NextNumber(-spread.X, spread.X), 0, random:NextNumber(-spread.Y, spread.Y))
		local mound = random:NextNumber(0.8, 1.2) * scale
		local leaf = if random:NextNumber() < 0.5 then palette.leaf else palette.leaf_dark
		kit.detail(kit.ellipsoid(parent, Vector3.new(mound * 1.4, mound, mound * 1.4), base * CFrame.new(0, mound * 0.3, 0), leaf, "Leaves"))

		local bloom = bloomStyle(FLOWERS[random:NextInteger(1, #FLOWERS)])
		for _ = 1, 3 do
			local at = Vector3.new(random:NextNumber(-0.4, 0.4) * mound, mound * 0.72 + random:NextNumber(0, 0.2) * scale, random:NextNumber(-0.4, 0.4) * mound)
			kit.detail(kit.ball(parent, random:NextNumber(0.3, 0.42) * scale, base * CFrame.new(at), bloom, "Bloom"))
		end
	end
end

-- note: tall flower spikes for the back of a border, like foxgloves, hollyhocks and delphiniums
function nature.spikes(kit, palette, parent: Instance, frame: CFrame, random: Random, count: number, spread: Vector2, height: number)
	for _ = 1, count do
		local base = frame * CFrame.new(random:NextNumber(-spread.X, spread.X), 0, random:NextNumber(-spread.Y, spread.Y))
		local tall = height * random:NextNumber(0.8, 1.15)
		local bloom = bloomStyle(SPIKES[random:NextInteger(1, #SPIKES)])
		kit.detail(kit.post(parent, tall, 0.12, base, palette.leaf, "Stem"))
		kit.detail(kit.ellipsoid(parent, Vector3.new(1.1, 0.6, 1.1), base * CFrame.new(0, 0.25, 0), palette.leaf, "Rosette"))

		local blooms = math.max(math.floor(tall / 0.7), 3)
		for i = 0, blooms - 1 do
			local y = tall * 0.4 + i * (tall * 0.6 / blooms)
			local size = math.max(0.46 - i * 0.03, 0.24)
			kit.detail(kit.ball(parent, size, base * CFrame.new(random:NextNumber(-0.06, 0.06), y, random:NextNumber(-0.06, 0.06)), bloom, "Bloom"))
		end
	end
end

-- note: a cottage border: a soil bed with spikes along the back (local +z) and flowering mounds in front
function nature.border(kit, palette, parent: Instance, frame: CFrame, length: number, depth: number, random: Random)
	kit.detail(kit.part(parent, Vector3.new(length, 0.6, depth), frame * CFrame.new(0, -0.15, 0), palette.soil, "Bed"))
	local back = frame * CFrame.new(0, 0.15, depth * 0.25)
	local front = frame * CFrame.new(0, 0.15, -depth * 0.2)
	nature.spikes(kit, palette, parent, back, random, math.max(math.floor(length / 2.2), 1), Vector2.new(length / 2 - 0.6, depth * 0.15), 4.2)
	nature.flowers(kit, palette, parent, front, random, math.max(math.floor(length / 1.6), 1), Vector2.new(length / 2 - 0.6, depth * 0.15), 1)
end

-- note: a climber spread up a wall: ivy leaf patches, with roses when given a color; frame sits on the wall face at the climber's foot, local z out of the wall
function nature.climber(kit, palette, parent: Instance, frame: CFrame, random: Random, width: number, height: number, bloom: Color3?)
	local patches = math.max(math.floor(width * height / 6), 2)
	-- note: patch centres stay inside the climber's spread so the leaves end near its edges
	local reach = math.max(width / 2 - 1, 0.3)
	for _ = 1, patches do
		local y = 0.8 + (height - 2.4) * math.sqrt(random:NextNumber())
		local spread = reach * (0.4 + 0.6 * y / height)
		-- note: patches stand clear of the stem so the leaves cover it
		local at = Vector3.new(random:NextNumber(-spread, spread), y, 0.3)
		-- note: a leaf patch lies flat, so it is stood up against the wall and turned within it
		local face = frame * CFrame.new(at) * CFrame.Angles(0, 0, random:NextNumber(0, math.pi * 2)) * CFrame.Angles(math.rad(90), 0, 0)
		tint(placeFoliage(parent, "LeafPatch", face, random:NextNumber(0.16, 0.22)), IVY_TINT)

		if bloom and random:NextNumber() < 0.7 then
			for _ = 1, 2 do
				local rose = at + Vector3.new(random:NextNumber(-0.9, 0.9), random:NextNumber(-0.8, 0.8), 0.3)
				kit.detail(kit.ball(parent, random:NextNumber(0.24, 0.32), frame * CFrame.new(rose), bloomStyle(bloom), "Rose"))
			end
		end
	end

	kit.detail(kit.post(parent, height * 0.6, 0.22, frame * CFrame.new(0, 0, 0.15), palette.bark, "Stem"))
end

-- Shrubs --------------------------------------------------------------------

-- note: a garden or hedge-top bush, rhododendron or laurel, some of them in flower
function nature.shrub(kit, palette, parent: Instance, frame: CFrame, random: Random, size: number)
	local name = pick(random, SHRUBS)
	placeFoliage(parent, name, frame * spin(random) * CFrame.new(0, -0.3, 0), scaleFor(name, size * random:NextNumber(0.85, 1.1)))
end

-- note: coastal gorse: a laurel tinted dark, its blossom turned gorse-yellow
function nature.gorse(kit, palette, parent: Instance, frame: CFrame, random: Random, size: number)
	local height = size * random:NextNumber(0.85, 1.05)
	local model = placeFoliage(parent, "Laurel", frame * spin(random) * CFrame.new(0, -0.3, 0), scaleFor("Laurel", height))
	tint(model, GORSE_TINT, true)
end

-- note: a clump of fern, as on hedge banks and in shady corners
function nature.fern(kit, palette, parent: Instance, frame: CFrame, random: Random, size: number)
	local name = if random:NextNumber() < 0.3 then "FernTall" else "Fern"
	placeFoliage(parent, name, frame * spin(random) * CFrame.new(0, -0.2, 0), scaleFor(name, size))
end

-- Rocks ---------------------------------------------------------------------

-- note: a jointed granite outcrop: blocks split along joints, sunk and tipped, with loose clitter round the foot
function nature.rock(kit, palette, parent: Instance, frame: CFrame, random: Random, size: number)
	local model = kit.model(parent, "Rock", frame)
	local base = CFrame.new(frame.Position) * spin(random)

	local function stone(): Style
		local weathered = palette.boulder.color:Lerp(LICHEN, random:NextNumber(0, 0.35))
		return kit.tint(palette.boulder, weathered:Lerp(Color3.new(), random:NextNumber(0, 0.12)))
	end

	-- note: a block sunk by part of its height and tipped a little off level
	local function block(dimensions: Vector3, at: CFrame, tip: number, sink: number): Part
		local tilt = CFrame.Angles(random:NextNumber(-tip, tip), random:NextNumber(-0.25, 0.25), random:NextNumber(-tip, tip))
		local part = kit.part(model, dimensions, at * CFrame.new(0, dimensions.Y * (0.5 - sink), 0) * tilt, stone(), "Block")
		part.CanQuery = false
		return part
	end

	local core = Vector3.new(size * random:NextNumber(1, 1.3), size * random:NextNumber(0.6, 0.8), size * random:NextNumber(0.75, 0.95))
	if random:NextNumber() < 0.5 then
		-- note: a vertical joint splits the core into two blocks
		local split = random:NextNumber(0.4, 0.6)
		local gap = size * 0.06
		local left = Vector3.new(core.X * split - gap / 2, core.Y, core.Z)
		local right = Vector3.new(core.X * (1 - split) - gap / 2, core.Y * random:NextNumber(0.75, 1), core.Z * random:NextNumber(0.85, 1))
		block(left, base * CFrame.new(-core.X / 2 + left.X / 2, 0, 0), 0.1, 0.3)
		block(right, base * CFrame.new(core.X / 2 - right.X / 2, 0, random:NextNumber(-0.1, 0.1) * core.Z), 0.14, 0.32)
	else
		block(core, base, 0.1, 0.3)
	end

	-- note: a smaller block fallen against one side
	local side = if random:NextNumber() < 0.5 then -1 else 1
	local fallen = core * Vector3.new(random:NextNumber(0.4, 0.6), random:NextNumber(0.5, 0.8), random:NextNumber(0.5, 0.7))
	local fallen_at = base * CFrame.new(side * (core.X / 2 + fallen.X * 0.3), 0, random:NextNumber(-0.25, 0.25) * core.Z) * CFrame.Angles(0, 0, side * random:NextNumber(0.2, 0.4))
	block(fallen, fallen_at, 0.08, 0.25)

	-- note: a slab left lying on top, as on a tor; the core shows about 70% of its height once sunk
	if random:NextNumber() < 0.55 then
		local slab = core * Vector3.new(random:NextNumber(0.55, 0.85), random:NextNumber(0.3, 0.45), random:NextNumber(0.55, 0.85))
		local top = base * CFrame.new(random:NextNumber(-0.15, 0.15) * core.X, core.Y * 0.7, random:NextNumber(-0.15, 0.15) * core.Z)
		block(slab, top, 0.12, 0.08)
	end

	-- note: clitter: loose stones round the foot
	for _ = 1, random:NextInteger(2, 4) do
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = size * random:NextNumber(0.8, 1.3)
		local small = Vector3.new(random:NextNumber(0.5, 1), random:NextNumber(0.35, 0.7), random:NextNumber(0.5, 1)) * size * random:NextNumber(0.18, 0.3)
		local at = base * CFrame.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		kit.detail(block(small, at, 0.5, 0.4))
	end
end

-- Trees ---------------------------------------------------------------------

-- note: the broad old tree on a village green; scale 1 is about 25 studs tall and 36 across
function nature.oak(kit, palette, parent: Instance, frame: CFrame, random: Random, scale: number): Model
	local base = frame * CFrame.Angles(0, random:NextNumber(-0.3, 0.3), 0) * CFrame.new(0, -0.4, 0)
	local model = placeFoliage(parent, "Maple", base, scaleFor("Maple", 25 * scale))
	model.Name = "Oak"
	trunkCollider(kit, model, 1.8 * scale, 7 * scale)
	return model
end

-- note: a beech or similar broadleaf for lanes and field edges; scale 1 is about 24 studs tall
function nature.broadleaf(kit, palette, parent: Instance, frame: CFrame, random: Random, scale: number): Model
	local name = pick(random, BROADLEAVES)
	local model = placeFoliage(parent, name, frame * CFrame.new(0, -0.4, 0), scaleFor(name, 24 * scale))
	model.Name = "Broadleaf"
	trunkCollider(kit, model, 1.3 * scale, 7 * scale)
	return model
end

-- note: a low apple tree with fruit showing among the leaves; scale 1 is about 10 studs tall
function nature.apple(kit, palette, parent: Instance, frame: CFrame, random: Random, scale: number): Model
	local model = placeFoliage(parent, "Broadleaf", frame * spin(random) * CFrame.new(0, -0.3, 0), scaleFor("Broadleaf", 10 * scale))
	model.Name = "AppleTree"
	trunkCollider(kit, model, 0.7 * scale, 3 * scale)

	local crown = crownOf(model)
	if not crown then
		return model
	end

	-- note: each apple sits just inside the crown, found by casting in toward its middle
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { crown }
	crown.CanQuery = true

	local fruit = { material = Enum.Material.SmoothPlastic, color = APPLES[random:NextInteger(1, #APPLES)] }
	local middle = crown.Position
	local reach = crown.Size.Magnitude
	for _ = 1, 10 do
		local direction = Vector3.new(random:NextNumber(-1, 1), random:NextNumber(-0.6, 0.4), random:NextNumber(-1, 1)).Unit
		local result = workspace:Raycast(middle + direction * reach, -direction * reach, params)
		if result then
			kit.detail(kit.ball(model, 0.42 * scale, CFrame.new(result.Position - direction * 0.35 * scale), fruit, "Apple"))
		end
	end

	crown.CanQuery = false
	return model
end

-- note: a hawthorn shaped by the sea wind, leaning toward the north-east; scale 1 is about 11 studs tall
function nature.hawthorn(kit, palette, parent: Instance, frame: CFrame, random: Random, scale: number): Model
	local lean = CFrame.fromAxisAngle(Vector3.yAxis:Cross(WIND), math.rad(random:NextNumber(10, 18)))
	local name = pick(random, HAWTHORNS)
	local base = CFrame.new(frame.Position) * lean * spin(random) * CFrame.new(0, -0.4, 0)
	local model = placeFoliage(parent, name, base, scaleFor(name, 11 * scale))
	model.Name = "Hawthorn"
	tint(model, HAWTHORN_TINT)
	trunkCollider(kit, model, 0.9 * scale, 3.5 * scale)
	return model
end

-- Lines ---------------------------------------------------------------------

-- note: a hedgerow along points: bushes of uneven height shoulder to shoulder, with an invisible wall inside that still blocks the way
function nature.hedge(kit, palette, parent: Instance, points: { Vector3 }, random: Random, height: number)
	for i = 1, #points - 1 do
		local frame, length = runFrame(kit, points[i], points[i + 1])
		kit.collider(parent, Vector3.new(length, height, 2.4), frame * CFrame.new(0, height / 2 - 0.4, 0))

		local steps = math.max(math.floor(length / 3), 1)
		for step = 0, steps - 1 do
			local x = -length / 2 + (step + 0.5) * length / steps
			local at = frame:PointToWorldSpace(Vector3.new(x + random:NextNumber(-0.6, 0.6), 0, random:NextNumber(-0.3, 0.3)))
			local foot = Vector3.new(at.X, kit.groundY(at.X, at.Z) - 0.4, at.Z)
			local name = pick(random, HEDGE_BUSHES)
			placeFoliage(parent, name, CFrame.new(foot) * spin(random), scaleFor(name, height * random:NextNumber(0.85, 1.15)))
		end
	end
end

-- note: a Cornish hedge: a stone-faced earth bank, wider at the foot, turfed on top with gorse, scrub, foxgloves and ferns along it
function nature.cornishHedge(kit, palette, parent: Instance, points: { Vector3 }, random: Random, height: number)
	local top_width = 3
	local batter = 0.9 -- note: how far each face leans out at the foot
	local sink = 0.8
	for i = 1, #points - 1 do
		local frame, length = runFrame(kit, points[i], points[i + 1])
		local centre_y = height / 2 - sink
		kit.part(parent, Vector3.new(length + 0.4, height, top_width), frame * CFrame.new(0, centre_y, 0), palette.rubble, "Bank")
		for _, side in { -1, 1 } do
			-- note: a wedge is full height at its +z end, so each face wedge points back at the bank
			local face = frame * CFrame.new(0, centre_y, side * (top_width / 2 + batter / 2)) * CFrame.Angles(0, if side > 0 then math.pi else 0, 0)
			kit.wedge(parent, Vector3.new(length + 0.4, height, batter), face, palette.rubble, "Face")
		end

		kit.part(parent, Vector3.new(length + 0.4, 0.5, top_width + 0.2), frame * CFrame.new(0, height - sink + 0.15, 0), palette.turf, "Turf")

		local steps = math.max(math.floor(length / 3), 1)
		for step = 0, steps - 1 do
			local x = -length / 2 + (step + 0.5) * length / steps
			local on_top = frame * CFrame.new(x + random:NextNumber(-0.6, 0.6), height - sink + 0.3, random:NextNumber(-0.5, 0.5))
			local roll = random:NextNumber()
			if roll < 0.25 then
				nature.gorse(kit, palette, parent, on_top, random, random:NextNumber(2.2, 3.2))
			elseif roll < 0.6 then
				nature.shrub(kit, palette, parent, on_top, random, random:NextNumber(2.2, 3.4))
			elseif roll < 0.75 then
				nature.spikes(kit, palette, parent, on_top, random, 2, Vector2.new(0.6, 0.4), 2.6)
			elseif roll < 0.9 then
				nature.fern(kit, palette, parent, on_top, random, random:NextNumber(1.6, 2.4))
			end
		end

		if i > 1 then
			-- note: a square stone pier, turned to split the corner, hides the joint where two runs meet
			local corner = points[i]
			local ground = kit.groundY(corner.X, corner.Z)
			local before = ((corner - points[i - 1]) * Vector3.new(1, 0, 1)).Unit
			local after = ((points[i + 1] - corner) * Vector3.new(1, 0, 1)).Unit
			local split = before + after
			local turn = CFrame.new(corner.X, ground, corner.Z) * CFrame.Angles(0, math.atan2(split.X, split.Z), 0)
			local pier = top_width + batter
			kit.part(parent, Vector3.new(pier, height, pier), turn * CFrame.new(0, height / 2 - sink, 0), palette.rubble, "Pier")
			kit.part(parent, Vector3.new(pier + 0.4, 0.5, pier + 0.4), turn * CFrame.new(0, height - sink + 0.15, 0), palette.turf, "Turf")
		end
	end
end

-- note: a low mortared garden wall with a dressed coping, following points
function nature.stoneWall(kit, palette, parent: Instance, points: { Vector3 }, height: number)
	local sink = 0.6
	for i = 1, #points - 1 do
		local frame, length = runFrame(kit, points[i], points[i + 1])
		kit.part(parent, Vector3.new(length + 0.3, height, 1.3), frame * CFrame.new(0, height / 2 - sink, 0), palette.rubble, "Wall")
		kit.part(parent, Vector3.new(length + 0.3, 0.4, 1.6), frame * CFrame.new(0, height - sink + 0.2, 0), palette.dressed_stone, "Coping")
		if i > 1 then
			local corner = points[i]
			local ground = kit.groundY(corner.X, corner.Z)
			kit.part(parent, Vector3.new(1.6, height + 0.4, 1.6), CFrame.new(corner.X, ground - sink + (height + 0.4) / 2, corner.Z), palette.rubble, "Pier")
		end
	end
end

return nature