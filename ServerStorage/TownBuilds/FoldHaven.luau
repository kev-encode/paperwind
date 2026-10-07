--!strict
--[[
	FoldHaven
	What: rebuilds Fold Haven into Workspace.FoldHaven: the four trade buildings, five cottages, the net loft, the harbor,
		the green, gardens, Cornish hedges, trees, lanes and lamps; interiors come from FoldHavenInteriors
	Used by: the studio assistant (edit mode); nothing requires it at runtime
	Needs: deps = { kit, palette, nature, interiors } (BuildKit, BuildPalette, TownBuilds.Nature, TownBuilds.FoldHavenInteriors),
		passed in because studio caches required modules; build the prefabs first (Prefabs.build, then Furniture.build)
	Site: plateau at ground Y ~12 around the origin; the harbor cove lies south around (40, 0, 85); the only lane out runs north-east
	Look: English seaside meets countryside: stone and whitewashed cottages, thatch and slate, Cornish hedges, a small harbor
	Frames: a building's base sits on its floor centre; local -z is the front and +x is to the right seen from inside
]]

local workspace = game:GetService("Workspace")

local T = 1.6 -- note: wall thickness; the window and door prefabs are made for it
local PARTITION = 0.8
local SEA_LEVEL = 0

type Deps = {
	kit: any,
	palette: any,
	nature: any,
	interiors: any,
}

export type Building = {
	model: Model,
	base: CFrame, -- note: floor centre of the ground storey
	length: number,
	width: number,
	height: number,
	interior: Instance,
	details: Instance,
	upper: CFrame?, -- note: floor centre of the storey above, when it is furnished
	upper_width: number?,
	upper_height: number?,
	style: string?,
	seed: number?,
}

local town = {}

-- Helpers -------------------------------------------------------------------

local function root(deps: Deps): Instance
	return deps.kit.folder(workspace, "FoldHaven")
end

local function freshFolder(deps: Deps, name: string): Instance
	local parent = root(deps)
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end

	return deps.kit.folder(parent, name)
end

-- note: a fresh building model with folders for its shell, fittings (windows and doors), interior and details
local function newBuilding(deps: Deps, group: string, name: string): (Model, Instance, Instance, Instance, Instance)
	local kit = deps.kit
	local parent = kit.folder(root(deps), group)
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end

	local model = kit.model(parent, name)
	return model, kit.folder(model, "Shell"), kit.folder(model, "Fittings"), kit.folder(model, "Interior"), kit.folder(model, "Details")
end

local function facing(x: number, z: number, direction: Vector3): CFrame
	local position = Vector3.new(x, 0, z)
	return CFrame.lookAt(position, position + direction)
end

local function window(x: number, y: number, prefab: string?)
	return { x = x, y = y, w = 4, h = 5.4, prefab = prefab or "Window" }
end

local function wideWindow(x: number, y: number)
	return { x = x, y = y, w = 6, h = 5.4, prefab = "WindowWide" }
end

local function smallWindow(x: number, y: number)
	return { x = x, y = y, w = 3, h = 3.4, prefab = "WindowSmall" }
end

local function louvre(x: number, y: number)
	return { x = x, y = y, w = 4, h = 5, prefab = "LouvreVent" }
end

local function door(x: number, prefab: string, label: string?)
	return { x = x, y = 0, w = 5.6, h = 8.4, prefab = prefab, label = label }
end

-- note: height of a gable roof's top surface at the ridge, above the eave
local function ridgeHeight(span: number, rise: number, thickness: number): number
	return rise + thickness / math.cos(math.atan(rise / (span / 2)))
end

-- note: a frame on a wall's outer face: local z outward, x to the right seen from outside, y on the floor
local function outerFace(base: CFrame, length: number, width: number, side: string): CFrame
	if side == "front" then
		return base * CFrame.new(0, 0, -width / 2) * CFrame.Angles(0, math.pi, 0)
	elseif side == "back" then
		return base * CFrame.new(0, 0, width / 2)
	elseif side == "left" then
		return base * CFrame.new(-length / 2, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0)
	end

	return base * CFrame.new(length / 2, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)
end

local function face(building: Building, side: string): CFrame
	return outerFace(building.base, building.length, building.width, side)
end

local function setLabels(model: Instance, text: string)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("TextLabel") then
			descendant.Text = text
		end
	end
end

-- note: a beam between two points, local z along it
local function beamBetween(kit, parent: Instance, from: Vector3, to: Vector3, size: Vector2, style, name: string)
	local span = (to - from).Magnitude
	return kit.part(parent, Vector3.new(size.X, size.Y, span), CFrame.lookAt((from + to) / 2, to), style, name)
end

-- note: open roof trusses (tie beam, king post, principal rafters) plus purlins and a ridge beam; eave sits on the wall tops
local function trusses(deps: Deps, parent: Instance, eave: CFrame, length: number, span: number, rise: number, xs: { number })
	local kit, palette = deps.kit, deps.palette
	local inner = span / 2 - T
	local angle = math.atan(rise / (span / 2))
	local drop = 0.55 / math.cos(angle) -- note: how far a rafter's centre hangs below the roof's underside

	local function underside(z: number): number
		return rise * (1 - math.abs(z) / (span / 2))
	end

	for _, x in xs do
		kit.part(parent, Vector3.new(0.9, 1, inner * 2), eave * CFrame.new(x, 0.5, 0), palette.timber, "TieBeam")
		kit.part(parent, Vector3.new(0.8, rise - 1.8, 0.8), eave * CFrame.new(x, 1 + (rise - 1.8) / 2, 0), palette.timber, "KingPost")
		for _, side in { -1, 1 } do
			local from = eave:PointToWorldSpace(Vector3.new(x, underside(inner) - drop, side * inner))
			local to = eave:PointToWorldSpace(Vector3.new(x, underside(0) - drop, 0))
			beamBetween(kit, parent, from, to, Vector2.new(0.8, 0.9), palette.timber, "Rafter")
		end
	end

	for _, side in { -1, 1 } do
		local z = side * span / 4
		kit.part(parent, Vector3.new(length - T * 2, 0.8, 0.8), eave * CFrame.new(0, underside(z) - drop, z) * CFrame.Angles(side * angle, 0, 0), palette.timber, "Purlin")
	end
	kit.part(parent, Vector3.new(length - T * 2, 1, 0.8), eave * CFrame.new(0, rise - 1.1, 0), palette.timber, "RidgeBeam")
end

-- note: open intervals along a wall that stay clear of its openings
local function clearRuns(span: number, openings: { any }, margin: number): { Vector2 }
	local runs = { Vector2.new(-span / 2, span / 2) }
	for _, hole in openings do
		local left = hole.x - hole.w / 2 - margin
		local right = hole.x + hole.w / 2 + margin
		local kept = {}
		for _, run in runs do
			if right <= run.X or left >= run.Y then
				table.insert(kept, run)
			else
				if left > run.X then
					table.insert(kept, Vector2.new(run.X, left))
				end
				if right < run.Y then
					table.insert(kept, Vector2.new(right, run.Y))
				end
			end
		end
		runs = kept
	end

	return runs
end

-- note: close-studded timber framing over a rendered storey: sole plate, wall plate, a mid rail and studs that skip openings
local function timberFrame(deps: Deps, parent: Instance, face: CFrame, span: number, height: number, openings: { any })
	local kit, palette = deps.kit, deps.palette
	local depth = 0.22
	for _, y in { 0.3, height - 0.3 } do
		kit.part(parent, Vector3.new(span, 0.55, depth), face * CFrame.new(0, y, depth / 2), palette.timber, "Plate")
	end

	for _, run in clearRuns(span, openings, 0.45) do
		local length = run.Y - run.X
		if length > 0.6 then
			kit.part(parent, Vector3.new(length, 0.45, depth), face * CFrame.new((run.X + run.Y) / 2, height * 0.45, depth / 2), palette.timber, "Rail")
			local studs = math.floor(length / 2)
			for i = 0, studs do
				local x = run.X + 0.25 + i * (length - 0.5) / math.max(studs, 1)
				kit.part(parent, Vector3.new(0.45, height - 0.6, depth), face * CFrame.new(x, height / 2, depth / 2), palette.timber, "Stud")
			end
		end
	end
end

-- note: a balustrade along a line on a floor: rails, balusters and end posts
local function balustrade(deps: Deps, parent: Instance, from: Vector3, to: Vector3)
	local kit, palette = deps.kit, deps.palette
	local up = Vector3.new(0, 1, 0)
	beamBetween(kit, parent, from + up * 3.2, to + up * 3.2, Vector2.new(0.3, 0.3), palette.oak, "Handrail")
	beamBetween(kit, parent, from + up * 0.4, to + up * 0.4, Vector2.new(0.25, 0.25), palette.oak, "BottomRail")
	for _, point in { from, to } do
		kit.part(parent, Vector3.new(0.5, 3.6, 0.5), CFrame.new(point + up * 1.8), palette.oak, "Newel")
	end

	local count = math.floor((to - from).Magnitude / 1.1)
	for i = 1, count - 1 do
		local point = from:Lerp(to, i / count)
		kit.detail(kit.part(parent, Vector3.new(0.18, 2.8, 0.18), CFrame.new(point + up * 1.8), palette.oak, "Baluster"), true)
	end
end

-- note: an interior partition with doorways; the frame sits on the floor at the wall's centre line
local function partition(deps: Deps, shell: Instance, fittings: Instance, frame: CFrame, length: number, height: number, doors: { number })
	local kit, palette = deps.kit, deps.palette
	local openings = {}
	for _, x in doors do
		table.insert(openings, { x = x, y = 0, w = 4.8, h = 8 })
	end

	kit.wall(shell, frame, length, height, PARTITION, palette.plaster, openings)
	for _, x in doors do
		kit.placePrefab("DoorInterior", fittings, frame * CFrame.new(x, 4, 0))
	end
end

local function makeBuilding(model: Model, base: CFrame, length: number, width: number, height: number, interior: Instance, details: Instance): Building
	model.WorldPivot = base
	return { model = model, base = base, length = length, width = width, height = height, interior = interior, details = details }
end

-- Folding Workshop ----------------------------------------------------------

local function dryingYard(deps: Deps, building: Building)
	local kit, palette, nature = deps.kit, deps.palette, deps.nature
	local parent = kit.folder(building.details, "DryingYard")
	local base = building.base
	local function at(x: number, z: number): Vector3
		return base:PointToWorldSpace(Vector3.new(x, 0, z))
	end

	-- note: a walled yard behind the workshop, open toward its back door
	nature.stoneWall(kit, palette, parent, { at(-5, 14.5), at(-5, 31), at(-35, 31), at(-35, 14.5) }, 3)
	for _, z in { 19, 23.5, 28 } do
		kit.placePrefab("PaperLine", parent, kit.onGround(base * CFrame.new(-20, 0, z)))
	end

	kit.placePrefab("Basket", parent, kit.onGround(base * CFrame.new(-9, 0, 22)))
	kit.placePrefab("Basket", parent, kit.onGround(base * CFrame.new(-31, 0, 26) * CFrame.Angles(0, 0.6, 0)))
	kit.placePrefab("WaterButt", parent, kit.onGround(base * CFrame.new(-31.5, 0, 17)))
	nature.border(kit, palette, parent, kit.onGround(base * CFrame.new(-20, 0, 29.6)), 26, 2.2, Random.new(31))
end

local function workshopDetails(deps: Deps, building: Building)
	local kit = deps.kit
	local details = building.details
	local front = outerFace(building.base, building.length, building.width, "front")

	local sign = kit.placePrefab("HangingSign", details, front * CFrame.new(7.2, 11.9, 0))
	setLabels(sign, "Folding Workshop")
	for _, x in { -6.4, 6.4 } do
		kit.placePrefab("WallLantern", details, front * CFrame.new(x, 8.3, 0))
	end

	for _, x in { -17, -9, 9, 17 } do
		kit.placePrefab("WindowBox", details, front * CFrame.new(x, 3.1, 0))
	end

	kit.placePrefab("Bench", details, kit.onGround(front * CFrame.new(-13, 0, 1.9)))
	for _, x in { -6.8, 6.8 } do
		kit.placePrefab("FlowerTub", details, kit.onGround(front * CFrame.new(x, 0, 2.6)))
	end

	dryingYard(deps, building)
end

function town.workshop(deps: Deps): Building
	local kit, palette = deps.kit, deps.palette
	local length, width, height, rise, thatch = 44, 26, 13, 11, 2.8
	local model, shell, fittings, interior, details = newBuilding(deps, "Buildings", "FoldingWorkshop")
	local look = facing(0, -82, Vector3.zAxis)
	local floor_y = kit.plinth(shell, look, length, width, palette.rubble)
	local base = look + Vector3.new(0, floor_y, 0)

	kit.storey(shell, base, {
		length = length,
		width = width,
		height = height,
		thickness = T,
		style = palette.stone,
		lining = palette.plaster,
		floor = palette.boards,
		fittings = fittings,
		openings = {
			front = { { x = 0, y = 0, w = 9.4, h = 10.4, prefab = "DoubleDoor", label = "Folding Workshop" }, window(-9, 3.5), window(9, 3.5), window(-17, 3.5), window(17, 3.5) },
			back = { window(14, 3.5), window(2, 3.5), door(-12, "DoorOak", "Drying Yard") },
			left = { window(0, 3.5) },
			right = { window(-6, 3.5) },
		},
	})
	kit.quoins(shell, base, length, width, height, palette.dressed_stone)

	-- note: no ceiling; the workshop is open to its trusses and the underside of the thatch
	local eave = base * CFrame.new(0, height, 0)
	kit.thatchRoof(shell, eave, { length = length, span = width, rise = rise, eave = 2.2, gable = 1.6, thickness = thatch, style = palette.thatch, ridge = palette.thatch_ridge, trim = palette.timber, wall = T }, palette.stone)
	kit.gableEnds(shell, eave, length, width, rise, T, palette.stone)
	trusses(deps, shell, eave, length, width, rise, { -11, 0, 11 })
	kit.placePrefab("ChimneyBrick", shell, eave * CFrame.new(15, ridgeHeight(width, rise, thatch) - 2.4, 0))

	local building = makeBuilding(model, base, length, width, height, interior, details)
	deps.interiors.workshop(deps, building)
	workshopDetails(deps, building)
	return building
end

-- The Folded Crane Inn ------------------------------------------------------

-- note: the stair climbs the right gable wall from the front toward the back; the stairwell is cut from the upper floor
local INN = {
	length = 46,
	width = 28,
	lower = 13,
	upper = 11,
	rise = 12,
	jetty = 1.2,
	stair = { x = 19.4, z = -11, width = 4, steps = 13, run = 1.15 },
}

local function innDetails(deps: Deps, building: Building)
	local kit, nature, palette = deps.kit, deps.nature, deps.palette
	local details = building.details
	local front = outerFace(building.base, building.length, building.width, "front")

	local sign = kit.placePrefab("HangingSign", details, front * CFrame.new(-12.5, 11.2, 0))
	setLabels(sign, "The Folded Crane Inn")
	for _, x in { -4.2, 4.2 } do
		kit.placePrefab("WallLantern", details, front * CFrame.new(x, 8.6, 0))
		kit.placePrefab("FlowerTub", details, kit.onGround(front * CFrame.new(x * 1.08, 0, 2.2)))
	end

	for _, x in { -8, 8 } do
		kit.placePrefab("Bench", details, kit.onGround(front * CFrame.new(x, 0, 2)))
	end

	kit.placePrefab("Barrel", details, kit.onGround(front * CFrame.new(-20.6, 0, 1.9)))
	kit.placePrefab("Barrel", details, kit.onGround(front * CFrame.new(-18.2, 0, 2.4) * CFrame.Angles(0, 0.4, 0)))
	kit.placePrefab("Crate", details, kit.onGround(front * CFrame.new(20.4, 0, 2) * CFrame.Angles(0, 0.2, 0)))
	nature.climber(kit, palette, details, front * CFrame.new(-20.6, 0, 0), Random.new(41), 4, 10, Color3.fromRGB(214, 120, 140))
end

-- note: the inn's back garden: apple trees, trestle tables and a Cornish hedge around it
local function innGarden(deps: Deps, building: Building)
	local kit, nature, palette = deps.kit, deps.nature, deps.palette
	local parent = kit.folder(building.details, "Garden")
	local base = building.base
	local random = Random.new(17)
	local function at(x: number, z: number): Vector3
		return base:PointToWorldSpace(Vector3.new(x, 0, z))
	end

	nature.cornishHedge(kit, palette, parent, { at(-24, 15.5), at(-24, 36), at(24, 36), at(24, 15.5) }, random, 3.6)
	for _, spot in { Vector2.new(-15, 24), Vector2.new(-3, 30), Vector2.new(10, 25), Vector2.new(18, 31) } do
		nature.apple(kit, palette, parent, kit.onGround(base * CFrame.new(spot.X, 0, spot.Y)), random, random:NextNumber(0.9, 1.1))
	end

	for _, spot in { Vector2.new(-8, 22), Vector2.new(4, 32) } do
		local frame = kit.onGround(base * CFrame.new(spot.X, 0, spot.Y) * CFrame.Angles(0, random:NextNumber(-0.2, 0.2), 0))
		kit.placePrefab("Table", parent, frame)
		kit.placePrefab("Bench", parent, frame * CFrame.new(0, 0, -2.6))
		kit.placePrefab("Bench", parent, frame * CFrame.new(0, 0, 2.6) * CFrame.Angles(0, math.pi, 0))
	end

	nature.border(kit, palette, parent, kit.onGround(base * CFrame.new(-14, 0, 16.6)), 12, 2.4, random)
end

function town.inn(deps: Deps): Building
	local kit, palette = deps.kit, deps.palette
	local length, width, lower, upper, rise, jetty = INN.length, INN.width, INN.lower, INN.upper, INN.rise, INN.jetty
	local model, shell, fittings, interior, details = newBuilding(deps, "Buildings", "FoldedCraneInn")
	local look = facing(-62, -28, Vector3.xAxis)
	local floor_y = kit.plinth(shell, look, length, width, palette.rubble)
	local base = look + Vector3.new(0, floor_y, 0)

	kit.storey(shell, base, {
		length = length,
		width = width,
		height = lower,
		thickness = T,
		style = palette.stone,
		lining = palette.plaster,
		floor = palette.flagstone,
		fittings = fittings,
		openings = {
			front = { { x = 0, y = 0, w = 6, h = 10.2, prefab = "DoorInn", label = "The Folded Crane Inn" }, wideWindow(-8, 3), wideWindow(8, 3), window(-17, 3), window(17, 3) },
			back = { door(12, "DoorOak", "Garden"), window(-16, 3), window(-6, 3) },
			right = { window(-6, 3) },
		},
	})
	kit.quoins(shell, base, length, width, lower, palette.dressed_stone)

	-- note: the upper storey is jettied out over the front by jetty, so its frame shifts forward by half of it
	local upper_width = width + jetty
	local upper_base = base * CFrame.new(0, lower, -jetty / 2)
	local stair = INN.stair
	local top_z = stair.z + stair.steps * stair.run
	local well_from = stair.z + 5.2 * stair.run
	local hole = { x = stair.x - 0.1, z = (well_from + top_z) / 2 + jetty / 2, w = stair.width + 0.2, d = top_z - well_from }
	kit.beamedCeiling(shell, upper_base * CFrame.new(0, -lower, 0), length - T * 2, upper_width - T * 2, lower + 0.05, palette.boards, palette.timber, 3.4, hole)
	kit.stairs(shell, base * CFrame.new(stair.x, 0, stair.z), stair.width, stair.steps, 1, stair.run, palette.boards, palette.oak, -1)

	local upper_openings = {
		-- note: a front wall's x runs opposite to the building's, so these sit at local x -13, 3 and 15
		front = { window(13, 2.2, "WindowTimber"), window(-3, 2.2, "WindowTimber"), window(-15, 2.2, "WindowTimber") },
		back = { window(-10, 2.2, "WindowTimber"), window(4, 2.2, "WindowTimber") },
		left = { window(0, 2.2, "WindowTimber") },
		right = { window(6, 2.2, "WindowTimber") },
	}
	kit.storey(shell, upper_base, { length = length, width = upper_width, height = upper, thickness = T, style = palette.render_cream, lining = palette.plaster, fittings = fittings, openings = upper_openings })
	for side, holes in upper_openings do
		local span = if side == "front" or side == "back" then length else upper_width
		timberFrame(deps, shell, outerFace(upper_base, length, upper_width, side), span, upper, holes)
	end

	-- note: the bressumer carries the jetty, with the floor joists' ends showing beneath it
	local overhang_z = -width / 2 - jetty / 2
	kit.part(shell, Vector3.new(length + 0.2, 0.8, jetty + 0.1), base * CFrame.new(0, lower - 0.4, overhang_z - 0.05), palette.timber, "Bressumer")
	for i = 0, 24 do
		local x = -length / 2 + 0.9 + i * (length - 1.8) / 24
		kit.part(shell, Vector3.new(0.5, 0.5, jetty + 0.6), base * CFrame.new(x, lower - 1.05, overhang_z + 0.25), palette.timber, "JoistEnd")
	end

	-- note: upstairs, a corridor runs along the back with two bedrooms in front; the stair arrives at the landing on the right
	local inner_x = length / 2 - T
	local inner_z = upper_width / 2 - T
	local corridor_z = 7
	local corridor_length = (10 + inner_x)
	partition(deps, shell, fittings, upper_base * CFrame.new(-inner_x + corridor_length / 2, 0, corridor_z), corridor_length, upper, { -13 + inner_x - corridor_length / 2, 3 + inner_x - corridor_length / 2 })
	for _, x in { -4, 10 } do
		local run = corridor_z - PARTITION / 2 + inner_z
		kit.wall(shell, upper_base * CFrame.new(x, 0, -inner_z + run / 2) * CFrame.Angles(0, math.pi / 2, 0), run, upper, PARTITION, palette.plaster)
	end

	local well_z0 = hole.z - hole.d / 2
	local well_z1 = hole.z + hole.d / 2
	local well_x = hole.x - hole.w / 2
	local floor = lower + 0.05
	balustrade(deps, shell, base:PointToWorldSpace(Vector3.new(well_x, floor, well_z0 - jetty / 2)), base:PointToWorldSpace(Vector3.new(well_x, floor, well_z1 - jetty / 2 - 0.4)))
	balustrade(deps, shell, base:PointToWorldSpace(Vector3.new(well_x, floor, well_z0 - jetty / 2)), base:PointToWorldSpace(Vector3.new(inner_x - 0.2, floor, well_z0 - jetty / 2)))
	kit.beamedCeiling(shell, upper_base, length - T * 2, upper_width - T * 2, upper, palette.plaster, palette.timber, 4.6)

	local eave = upper_base * CFrame.new(0, upper, 0)
	kit.slateRoof(shell, eave, { length = length, span = upper_width, rise = rise, eave = 1.4, gable = 1, thickness = 0.8, style = palette.slate_roof, ridge = palette.ridge_tile, trim = palette.timber, wall = T }, palette.render_cream)
	kit.gableEnds(shell, eave, length, upper_width, rise, T, palette.render_cream)
	local ridge = ridgeHeight(upper_width, rise, 0.8)
	kit.placePrefab("ChimneyBrick", shell, eave * CFrame.new(-20, ridge - 2.2, 0))
	kit.placePrefab("ChimneyBrick", shell, eave * CFrame.new(17, ridge - 2.2, 0))

	local building = makeBuilding(model, base, length, width, lower, interior, details)
	building.upper = upper_base
	building.upper_width = upper_width
	building.upper_height = upper
	deps.interiors.inn(deps, building, INN)
	innDetails(deps, building)
	innGarden(deps, building)
	return building
end

-- General Store -------------------------------------------------------------

local function storeDetails(deps: Deps, building: Building)
	local kit, palette = deps.kit, deps.palette
	local details = building.details
	local front = outerFace(building.base, building.length, building.width, "front")

	-- note: a painted fascia board with gilt lettering across the shop front
	local fascia = kit.part(details, Vector3.new(24.6, 1.7, 0.3), front * CFrame.new(0, 11.4, 0.15), palette.paint_green, "Fascia")
	for _, y in { 10.5, 12.3 } do
		kit.part(details, Vector3.new(25, 0.16, 0.42), front * CFrame.new(0, y, 0.2), palette.frame_white, "FasciaTrim")
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 1
	local text = Instance.new("TextLabel")
	text.Name = "Label"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 0.8)
	text.Position = UDim2.fromScale(0, 0.1)
	text.Font = Enum.Font.Fondamento
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(228, 206, 152)
	text.Text = "General Store"
	text.Parent = gui
	gui.Parent = fascia

	-- note: painted pilasters frame the door and the two shop windows
	for _, x in { -12.6, -3.35, 3.35, 12.6 } do
		kit.part(details, Vector3.new(0.7, 10.3, 0.25), front * CFrame.new(x, 5.15, 0.12), palette.paint_green, "Pilaster")
	end

	-- note: striped canvas awnings over the shop windows
	local canvas = { kit.tint(palette.linen, Color3.fromRGB(70, 104, 86)), palette.linen }
	for _, x in { -8, 8 } do
		local slope = front * CFrame.new(x, 9.35, 1.6) * CFrame.Angles(math.rad(-24), 0, 0)
		for i = 0, 5 do
			local stripe = slope * CFrame.new(-4.3 + (i + 0.5) * 8.6 / 6, 0, 0)
			kit.part(details, Vector3.new(8.6 / 6, 0.1, 3.4), stripe, canvas[i % 2 + 1], "Awning")
			kit.part(details, Vector3.new(8.6 / 6, 0.6, 0.08), stripe * CFrame.new(0, -0.3, 1.7), canvas[i % 2 + 1], "Valance")
		end
	end

	for _, x in { -3.35, 3.35 } do
		kit.placePrefab("WallLantern", details, front * CFrame.new(x, 8.2, 0.25))
	end

	for _, x in { -7.5, 7.5 } do
		kit.placePrefab("WindowBox", details, front * CFrame.new(x, 13 + 2.2 - 0.4, 0))
	end

	-- note: goods set out by the door, clear of its swing
	local stall = kit.onGround(front * CFrame.new(-9, 0, 3.4))
	kit.placePrefab("TableSmall", details, stall)
	kit.placePrefab("Basket", details, stall * CFrame.new(-0.8, 3, 0))
	kit.placePrefab("Basket", details, stall * CFrame.new(0.9, 3, 0.2))
	kit.placePrefab("SackOpen", details, kit.onGround(front * CFrame.new(-12.2, 0, 2.2)))
	kit.placePrefab("Sack", details, kit.onGround(front * CFrame.new(9.6, 0, 2.1) * CFrame.Angles(0, 0.5, 0)))
	kit.placePrefab("Crate", details, kit.onGround(front * CFrame.new(11.8, 0, 2.4) * CFrame.Angles(0, -0.2, 0)))
	kit.placePrefab("Barrel", details, kit.onGround(face(building, "back") * CFrame.new(-10, 0, 2)))
end

function town.store(deps: Deps): Building
	local kit, palette = deps.kit, deps.palette
	local length, width, lower, upper, rise = 26, 20, 13, 10, 8
	local model, shell, fittings, interior, details = newBuilding(deps, "Buildings", "GeneralStore")
	local look = facing(56, -36, -Vector3.xAxis)
	local floor_y = kit.plinth(shell, look, length, width, palette.rubble)
	local base = look + Vector3.new(0, floor_y, 0)

	kit.storey(shell, base, {
		length = length,
		width = width,
		height = lower,
		thickness = T,
		style = palette.whitewash,
		lining = palette.plaster,
		floor = palette.boards,
		fittings = fittings,
		openings = {
			front = { { x = -8, y = 1.2, w = 8.6, h = 7.5, prefab = "ShopWindow" }, { x = 8, y = 1.2, w = 8.6, h = 7.5, prefab = "ShopWindow" }, { x = 0, y = 0, w = 6, h = 10.2, prefab = "DoorShop", label = "General Store" } },
			back = { door(6, "DoorOak", "Yard") },
			left = { window(0, 3) },
			right = { window(0, 3) },
		},
	})
	kit.beamedCeiling(shell, base, length - T * 2, width - T * 2, lower + 0.05, palette.boards, palette.timber, 3.2)

	local upper_base = base * CFrame.new(0, lower, 0)
	kit.storey(shell, upper_base, {
		length = length,
		width = width,
		height = upper,
		thickness = T,
		style = palette.whitewash,
		lining = palette.plaster,
		fittings = fittings,
		openings = {
			front = { window(-7.5, 2.2, "WindowShutteredSage"), window(0, 2.2, "WindowTimber"), window(7.5, 2.2, "WindowShutteredSage") },
			back = { window(0, 2.2, "WindowTimber") },
			left = { smallWindow(0, 3) },
			right = { smallWindow(0, 3) },
		},
	})
	kit.beamedCeiling(shell, upper_base, length - T * 2, width - T * 2, upper, palette.plaster, palette.timber, 4)

	local eave = upper_base * CFrame.new(0, upper, 0)
	kit.slateRoof(shell, eave, { length = length, span = width, rise = rise, eave = 1.2, gable = 0.9, thickness = 0.7, style = palette.slate_roof, ridge = palette.ridge_tile, trim = palette.frame_white, wall = T, drop = lower + upper }, palette.whitewash)
	kit.gableEnds(shell, eave, length, width, rise, T, palette.whitewash)
	kit.placePrefab("ChimneyBrick", shell, eave * CFrame.new(-9.5, ridgeHeight(width, rise, 0.7) - 2.2, 0))

	local building = makeBuilding(model, base, length, width, lower, interior, details)
	building.upper = upper_base
	building.upper_width = width
	building.upper_height = upper
	deps.interiors.store(deps, building)
	storeDetails(deps, building)
	return building
end

-- Paper Mill ----------------------------------------------------------------

local MILL = {
	centre = Vector3.new(26, 0, 46),
	length = 30,
	width = 20,
	ground = 12,
	loft = 11,
	top = 8,
	rise = 8,
	stair = { x = -11.6, z = -8.4, width = 3.6, steps = 12, run = 1.15 },
}

-- note: the mill race, a water channel along the mill's south wall that opens into the cove
function town.millRace(deps: Deps)
	local kit, palette = deps.kit, deps.palette
	local terrain = workspace.Terrain
	local north = MILL.centre.Z + MILL.width / 2 + 0.6
	local south = north + 8.4
	local west = MILL.centre.X - MILL.length / 2 - 4
	local east = 54
	local bottom = SEA_LEVEL - 5
	local centre_x = (west + east) / 2
	local centre_z = (north + south) / 2
	local size_x = east - west
	local size_z = south - north

	terrain:FillBlock(CFrame.new(centre_x, (bottom + 14) / 2, centre_z), Vector3.new(size_x, 14 - bottom, size_z), Enum.Material.Air)
	terrain:FillBlock(CFrame.new(centre_x, (bottom + SEA_LEVEL) / 2, centre_z), Vector3.new(size_x, SEA_LEVEL - bottom, size_z), Enum.Material.Water)

	local parent = kit.folder(root(deps), "Buildings")
	local old = parent:FindFirstChild("MillRace")
	if old then
		old:Destroy()
	end

	local model = kit.model(parent, "MillRace")
	local wall_top = SEA_LEVEL + 3
	local wall_height = wall_top - bottom
	local wall_y = (wall_top + bottom) / 2
	local race_length = size_x - 6
	local race_x = west + race_length / 2
	kit.part(model, Vector3.new(race_length, wall_height, 1.6), CFrame.new(race_x, wall_y, north - 0.2), palette.rubble, "RaceWall")
	kit.part(model, Vector3.new(race_length, wall_height, 1.6), CFrame.new(race_x, wall_y, south + 0.8), palette.rubble, "RaceWall")
	kit.part(model, Vector3.new(1.6, wall_height, size_z + 3.2), CFrame.new(west - 0.8, wall_y, centre_z + 0.3), palette.rubble, "RaceWall")
	kit.part(model, Vector3.new(race_length, 0.6, 2.2), CFrame.new(race_x, wall_top + 0.3, south + 0.8), palette.dressed_stone, "Coping")
end

-- note: an undershot waterwheel, axle along the wheel model's local z, pivot on the axle; Waterwheels spins it
local function waterwheel(deps: Deps, parent: Instance, axle: CFrame): Model
	local kit, palette = deps.kit, deps.palette
	local model = kit.model(parent, "Waterwheel", axle)
	local radius = 8
	local floats = 20
	local segment = 2 * math.pi * radius / floats * 1.08

	for i = 0, floats - 1 do
		local turn = axle * CFrame.Angles(0, 0, i * 2 * math.pi / floats)
		for _, side in { -1.4, 1.4 } do
			kit.part(model, Vector3.new(segment, 0.7, 0.4), turn * CFrame.new(0, radius, side), palette.wet_wood, "Rim")
		end
		kit.part(model, Vector3.new(0.3, 2.4, 3.2), turn * CFrame.new(0, radius - 1.1, 0), palette.wet_wood, "Float")
	end

	for i = 0, 7 do
		local turn = axle * CFrame.Angles(0, 0, i * math.pi / 4)
		for _, side in { -1.4, 1.4 } do
			kit.part(model, Vector3.new(0.5, radius, 0.4), turn * CFrame.new(0, radius / 2, side), palette.oak, "Spoke")
		end
	end

	kit.cylinder(model, 3.6, 1.6, axle * CFrame.Angles(0, math.rad(90), 0), palette.iron, "Hub")
	kit.cylinder(model, 6, 0.7, axle * CFrame.new(0, 0, -2.6) * CFrame.Angles(0, math.rad(90), 0), palette.iron, "Axle")
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	kit.tag(model, "Waterwheel")
	return model
end

-- note: a hoist beam under the front gable with a pulley, rope and a sack on the hook
local function hoist(deps: Deps, parent: Instance, face: CFrame, y: number)
	local kit, palette = deps.kit, deps.palette
	kit.part(parent, Vector3.new(0.8, 0.9, 3.6), face * CFrame.new(0, y, 1.8), palette.timber, "HoistBeam")
	kit.part(parent, Vector3.new(0.6, 2.4, 0.6), face * CFrame.new(0, y - 1.5, 0.3) * CFrame.Angles(math.rad(-35), 0, 0), palette.timber, "Strut")
	kit.cylinder(parent, 0.3, 1, face * CFrame.new(0, y - 0.7, 3.2) * CFrame.Angles(0, 0, 0), palette.iron, "Pulley")
	kit.detail(kit.part(parent, Vector3.new(0.1, 6, 0.1), face * CFrame.new(0, y - 3.9, 3.4), palette.rope, "Rope"))
	kit.placePrefab("Sack", parent, face * CFrame.new(0, y - 9.6, 3.4))
end

local function millDetails(deps: Deps, building: Building)
	local kit = deps.kit
	local details = building.details
	local front = face(building, "front")
	local sign = kit.placePrefab("HangingSign", details, front * CFrame.new(-7.6, 10.4, 0))
	setLabels(sign, "Paper Mill")
	for _, x in { -6.2, 6.2 } do
		kit.placePrefab("WallLantern", details, front * CFrame.new(x, 8.3, 0))
	end

	hoist(deps, details, front, MILL.ground + MILL.loft + MILL.top - 1.2)
	kit.placePrefab("Crate", details, kit.onGround(front * CFrame.new(10, 0, 2.6)))
	kit.placePrefab("Crate", details, kit.onGround(front * CFrame.new(12.6, 0, 2.8) * CFrame.Angles(0, 0.35, 0)))
	kit.placePrefab("Sack", details, kit.onGround(front * CFrame.new(-11.5, 0, 2.2)))
	kit.placePrefab("Sack", details, kit.onGround(front * CFrame.new(-12.8, 0, 3.1) * CFrame.Angles(0, 0.8, 0)))
	kit.placePrefab("PaperLine", details, kit.onGround(face(building, "right") * CFrame.new(-2, 0, 8)))
end

function town.mill(deps: Deps): Building
	local kit, palette = deps.kit, deps.palette
	local length, width, rise = MILL.length, MILL.width, MILL.rise
	local model, shell, fittings, interior, details = newBuilding(deps, "Buildings", "PaperMill")
	local look = facing(MILL.centre.X, MILL.centre.Z, -Vector3.zAxis)
	local floor_y = kit.plinth(shell, look, length, width, palette.rubble)
	local base = look + Vector3.new(0, floor_y, 0)

	kit.storey(shell, base, {
		length = length,
		width = width,
		height = MILL.ground,
		thickness = T,
		style = palette.stone,
		lining = palette.plaster,
		floor = palette.flagstone,
		fittings = fittings,
		openings = {
			front = { { x = 0, y = 0, w = 9.4, h = 10.4, prefab = "DoubleDoor", label = "Paper Mill" }, window(-10, 3), window(10, 3) },
			back = { window(-9, 3), window(9, 3) },
			right = { door(0, "DoorOak", "Paper Mill") },
		},
	})
	kit.quoins(shell, base, length, width, MILL.ground, palette.dressed_stone)

	local stair = MILL.stair
	local top_z = stair.z + stair.steps * stair.run
	local well_from = stair.z + 5 * stair.run
	local hole = { x = stair.x, z = (well_from + top_z) / 2, w = stair.width + 0.2, d = top_z - well_from }
	kit.beamedCeiling(shell, base, length - T * 2, width - T * 2, MILL.ground + 0.05, palette.boards, palette.timber, 3, hole)
	kit.stairs(shell, base * CFrame.new(stair.x, 0, stair.z), stair.width, stair.steps, 1, stair.run, palette.boards, palette.oak, 1)

	local loft_base = base * CFrame.new(0, MILL.ground, 0)
	kit.storey(shell, loft_base, {
		length = length,
		width = width,
		height = MILL.loft,
		thickness = T,
		style = palette.weatherboard,
		lining = palette.pine,
		fittings = fittings,
		openings = {
			front = { louvre(-10, 2.5), louvre(0, 2.5), louvre(10, 2.5) },
			back = { louvre(-9, 2.5), louvre(9, 2.5) },
			left = { louvre(0, 2.5) },
			right = { louvre(0, 2.5) },
		},
	})
	local floor = MILL.ground + 0.05
	local well_x = hole.x + hole.w / 2
	balustrade(deps, shell, base:PointToWorldSpace(Vector3.new(well_x, floor, hole.z - hole.d / 2)), base:PointToWorldSpace(Vector3.new(well_x, floor, hole.z + hole.d / 2 - 0.3)))
	balustrade(deps, shell, base:PointToWorldSpace(Vector3.new(well_x, floor, hole.z - hole.d / 2)), base:PointToWorldSpace(Vector3.new(-length / 2 + T + 0.2, floor, hole.z - hole.d / 2)))
	kit.beamedCeiling(shell, loft_base, length - T * 2, width - T * 2, MILL.loft + 0.05, palette.boards, palette.timber, 3)

	local top_base = loft_base * CFrame.new(0, MILL.loft, 0)
	kit.storey(shell, top_base, {
		length = length,
		width = width,
		height = MILL.top,
		thickness = T,
		style = palette.weatherboard,
		fittings = fittings,
		openings = {
			front = { smallWindow(-6, 2.5), smallWindow(6, 2.5) },
			back = { smallWindow(0, 2.5) },
		},
	})

	local eave_height = MILL.ground + MILL.loft + MILL.top
	local eave = base * CFrame.new(0, eave_height, 0)
	kit.slateRoof(shell, eave, { length = length, span = width, rise = rise, eave = 1.2, gable = 0.9, thickness = 0.7, style = palette.slate_roof, ridge = palette.ridge_tile, trim = palette.timber, wall = T, drop = eave_height }, palette.weatherboard)
	kit.gableEnds(shell, eave, length, width, rise, T, palette.weatherboard)

	-- note: the wheel sits outside the back wall with its lower floats in the race
	local wheel_y = (SEA_LEVEL + 5) - floor_y
	waterwheel(deps, shell, base * CFrame.new(0, wheel_y, width / 2 + 2))

	local building = makeBuilding(model, base, length, width, MILL.ground, interior, details)
	building.upper = loft_base
	building.upper_width = width
	building.upper_height = MILL.loft
	deps.interiors.mill(deps, building, MILL)
	millDetails(deps, building)
	return building
end

-- Cottages --------------------------------------------------------------------

-- note: stone and thatch, whitewash and thatch, or whitewash and slate; each one dressed by its seed
local COTTAGES = {
	{ x = -50, z = -92, facing = Vector3.zAxis, style = "stone", door = "DoorOak", window = "Window" },
	{ x = 52, z = -90, facing = Vector3.zAxis, style = "thatch", door = "DoorSage", window = "WindowTimber" },
	{ x = 96, z = -50, facing = -Vector3.xAxis, style = "slate", door = "DoorNavy", window = "WindowShutteredNavy" },
	{ x = -36, z = 22, facing = -Vector3.zAxis, style = "thatch", door = "DoorTeal", window = "WindowShutteredTeal" },
	{ x = 66, z = -2, facing = -Vector3.xAxis, style = "slate", door = "DoorOxblood", window = "WindowShutteredOxblood" },
}
local COTTAGE_LENGTH = 22
local COTTAGE_WIDTH = 16
local COTTAGE_HEIGHT = 10
local GARDEN_DEPTH = 9

local function cottageFrame(index: number): CFrame
	local entry = COTTAGES[index]
	return facing(entry.x, entry.z, entry.facing)
end

-- note: the gate in a cottage's front garden wall, where its path begins
local function cottageGate(index: number): Vector3
	return cottageFrame(index):PointToWorldSpace(Vector3.new(0, 0, -COTTAGE_WIDTH / 2 - GARDEN_DEPTH))
end

-- note: a stone chimney breast up the right gable with a brick stack through the roof
local function gableStack(deps: Deps, parent: Instance, base: CFrame, ridge: number)
	local kit, palette = deps.kit, deps.palette
	local x = COTTAGE_LENGTH / 2 + 1.3
	local bottom = -2.5
	local top = ridge - 2.4
	kit.part(parent, Vector3.new(2.6, top - bottom, 4.6), base * CFrame.new(x, (top + bottom) / 2, 0), palette.stone, "ChimneyBreast")
	kit.placePrefab("ChimneyBrick", parent, base * CFrame.new(x + 0.05, top, 0) * CFrame.Angles(0, math.pi / 2, 0))
end

local function cottageGarden(deps: Deps, building: Building, index: number)
	local kit, palette, nature = deps.kit, deps.palette, deps.nature
	local parent = kit.folder(building.details, "Garden")
	local base = building.base
	local random = Random.new(100 + index)
	local front_z = -COTTAGE_WIDTH / 2
	local edge = front_z - GARDEN_DEPTH
	local half = COTTAGE_LENGTH / 2 + 1
	local function at(x: number, z: number): Vector3
		return base:PointToWorldSpace(Vector3.new(x, 0, z))
	end

	nature.stoneWall(kit, palette, parent, { at(-half, front_z - 0.6), at(-half, edge), at(-2.8, edge) }, 2.6)
	nature.stoneWall(kit, palette, parent, { at(2.8, edge), at(half, edge), at(half, front_z - 0.6) }, 2.6)
	kit.placePrefab("Gate", parent, kit.onGround(base * CFrame.new(0, 0, edge)))

	-- note: stepping stones from the gate to the door
	for i = 1, 4 do
		local z = edge + i * GARDEN_DEPTH / 5
		local stone = kit.onGround(base * CFrame.new(random:NextNumber(-0.3, 0.3), 0, z) * CFrame.Angles(0, random:NextNumber(-0.3, 0.3), 0))
		kit.part(parent, Vector3.new(2.6, 0.5, 1.5), stone * CFrame.new(0, 0.05, 0), palette.flagstone, "SteppingStone")
	end

	for _, x in { -7, 7 } do
		nature.border(kit, palette, parent, kit.onGround(base * CFrame.new(x, 0, front_z - 1.6)), 7, 2.4, random)
	end
	nature.flowers(kit, palette, parent, kit.onGround(base * CFrame.new(-8, 0, edge + 1.6)), random, 4, Vector2.new(2.4, 0.6), 1)
	nature.shrub(kit, palette, parent, kit.onGround(base * CFrame.new(9, 0, edge + 2)), random, 2.6)

	local entry = COTTAGES[index]
	local front = outerFace(base, COTTAGE_LENGTH, COTTAGE_WIDTH, "front")
	if entry.style == "slate" then
		for _, x in { -6.5, 6.5 } do
			kit.placePrefab("WindowBox", parent, front * CFrame.new(x, 3 - 0.4, 0))
		end
	else
		nature.climber(kit, palette, parent, front * CFrame.new(-3.7, 0, 0), random, 2.2, 8.5, Color3.fromRGB(206, 92, 108))
	end

	kit.placePrefab("WallLantern", parent, front * CFrame.new(3.8, 7.4, 0))
	kit.placePrefab("WaterButt", parent, kit.onGround(base * CFrame.new(-half + 1.8, 0, COTTAGE_WIDTH / 2 + 1.8)))
end

function town.cottage(deps: Deps, index: number): Building
	local kit, palette = deps.kit, deps.palette
	local entry = COTTAGES[index]
	local length, width, height = COTTAGE_LENGTH, COTTAGE_WIDTH, COTTAGE_HEIGHT
	local model, shell, fittings, interior, details = newBuilding(deps, "Cottages", "Cottage" .. index)
	local look = cottageFrame(index)
	local floor_y = kit.plinth(shell, look, length, width, palette.rubble)
	local base = look + Vector3.new(0, floor_y, 0)
	local wall = if entry.style == "stone" then palette.stone else palette.whitewash

	kit.storey(shell, base, {
		length = length,
		width = width,
		height = height,
		thickness = T,
		style = wall,
		lining = palette.plaster,
		floor = if entry.style == "thatch" then palette.boards else palette.flagstone,
		fittings = fittings,
		openings = {
			front = { door(0, entry.door, "Cottage"), window(-6.5, 3, entry.window), window(6.5, 3, entry.window) },
			back = { window(-5, 3, "WindowTimber"), window(5, 3, "WindowTimber") },
			left = { window(0, 3, "WindowTimber") },
		},
	})
	if entry.style == "stone" then
		kit.quoins(shell, base, length, width, height, palette.dressed_stone)
	end

	local eave = base * CFrame.new(0, height, 0)
	local ridge
	if entry.style == "slate" then
		local rise = 7
		kit.slateRoof(shell, eave, { length = length, span = width, rise = rise, eave = 1.2, gable = 0.8, thickness = 0.7, style = palette.slate_roof, ridge = palette.ridge_tile, trim = palette.frame_white, wall = T, drop = height }, wall)
		kit.gableEnds(shell, eave, length, width, rise, T, wall)
		ridge = height + ridgeHeight(width, rise, 0.7)
		-- note: boards under the slates, so the open roof reads as timber from inside
		local angle = math.atan(rise / (width / 2))
		for _, side in { -1, 1 } do
			local slope = eave * CFrame.new(0, rise / 2 - 0.1, side * width / 4) * CFrame.Angles(side * angle, 0, 0)
			kit.part(shell, Vector3.new(length - T * 2, 0.15, (width / 2 - T) / math.cos(angle)), slope, palette.pine, "Sarking")
		end
		trusses(deps, shell, eave, length, width, rise, { -4, 4 })
	else
		local rise = 9
		kit.thatchRoof(shell, eave, { length = length, span = width, rise = rise, eave = 1.6, gable = 1.4, thickness = 2.6, style = palette.thatch, ridge = palette.thatch_ridge, trim = palette.timber, wall = T }, wall)
		kit.gableEnds(shell, eave, length, width, rise, T, wall)
		ridge = height + ridgeHeight(width, rise, 2.6)
		trusses(deps, shell, eave, length, width, rise, { -4, 4 })
	end
	gableStack(deps, shell, base, ridge)

	local building = makeBuilding(model, base, length, width, height, interior, details)
	building.style = entry.style
	building.seed = index
	deps.interiors.cottage(deps, building)
	cottageGarden(deps, building, index)
	return building
end

function town.cottages(deps: Deps)
	freshFolder(deps, "Cottages")
	for index in COTTAGES do
		town.cottage(deps, index)
	end
end

-- Harbor ----------------------------------------------------------------------

local JETTY_X = 62
local JETTY_FROM = 56
local JETTY_TO = 104
local DECK_Y = 3.2

-- note: the net loft, a fisherman's store on the beach with its door toward the jetty
function town.netLoft(deps: Deps): Building
	local kit, palette = deps.kit, deps.palette
	local length, width, height, rise = 16, 10, 9, 5
	local model, shell, fittings, interior, details = newBuilding(deps, "Harbor", "NetLoft")
	local look = facing(90, 44, -Vector3.xAxis)
	local floor_y = kit.plinth(shell, look, length, width, palette.rubble, 0.6)
	local base = look + Vector3.new(0, floor_y, 0)

	kit.storey(shell, base, {
		length = length,
		width = width,
		height = height,
		thickness = T,
		style = palette.rubble,
		floor = palette.flagstone,
		fittings = fittings,
		openings = {
			front = { door(-2, "DoorTeal", "Net Loft"), window(4.5, 3, "WindowSmall") },
			left = { smallWindow(0, 4) },
		},
	})

	local eave = base * CFrame.new(0, height, 0)
	kit.slateRoof(shell, eave, { length = length, span = width, rise = rise, eave = 1, gable = 0.7, thickness = 0.6, style = palette.slate_roof, ridge = palette.ridge_tile, trim = palette.tarred, wall = T }, palette.rubble)
	kit.gableEnds(shell, eave, length, width, rise, T, palette.rubble)
	trusses(deps, shell, eave, length, width, rise, { 0 })

	local front = outerFace(base, length, width, "front")
	kit.placePrefab("WallLantern", details, front * CFrame.new(1.4, 7.4, 0))
	kit.placePrefab("NetRack", details, kit.onGround(front * CFrame.new(-1, 0, 8) * CFrame.Angles(0, 0.3, 0)))
	for i, spot in { Vector3.new(5, 0, 2.2), Vector3.new(6.6, 0, 2.6), Vector3.new(5.8, 2.2, 2.4) } do
		kit.placePrefab("CrabPot", details, kit.onGround(front * CFrame.new(spot.X, 0, spot.Z)) * CFrame.new(0, spot.Y, 0) * CFrame.Angles(0, i * 0.4, 0))
	end
	kit.placePrefab("FishBox", details, kit.onGround(front * CFrame.new(-6, 0, 2.2) * CFrame.Angles(0, 0.2, 0)))
	kit.placePrefab("RopeCoil", details, kit.onGround(front * CFrame.new(-6.6, 0, 4.6)))

	local building = makeBuilding(model, base, length, width, height, interior, details)
	deps.interiors.netLoft(deps, building)
	return building
end

function town.harbor(deps: Deps)
	local kit, palette, nature = deps.kit, deps.palette, deps.nature
	local parent = freshFolder(deps, "Harbor")
	local jetty = kit.model(parent, "Jetty")
	local length = JETTY_TO - JETTY_FROM
	local deck = palette.wet_wood
	local planks = kit.tint(palette.wet_wood, Color3.fromRGB(122, 110, 96))

	for z = JETTY_FROM, JETTY_TO - 8, 8 do
		kit.part(jetty, Vector3.new(6, 0.5, 8), CFrame.new(JETTY_X, DECK_Y, z + 4), planks, "Deck")
	end
	kit.part(jetty, Vector3.new(16, 0.5, 6), CFrame.new(JETTY_X, DECK_Y, JETTY_TO + 3), planks, "Deck")

	local function pile(x: number, z: number)
		local top = DECK_Y + 1.2
		local bottom = kit.groundY(x, z) - 2
		kit.post(jetty, top - bottom, 0.9, CFrame.new(x, bottom, z), deck, "Pile")
	end

	for z = JETTY_FROM + 4, JETTY_TO, 8 do
		pile(JETTY_X - 3.2, z)
		pile(JETTY_X + 3.2, z)
		-- note: a cross brace between each pair of piles, below the deck
		local brace = CFrame.new(JETTY_X, DECK_Y - 2.2, z) * CFrame.Angles(0, 0, math.rad(28))
		kit.part(jetty, Vector3.new(7.2, 0.4, 0.3), brace, deck, "Brace")
	end

	for _, x in { -7.6, 7.6 } do
		pile(JETTY_X + x, JETTY_TO + 0.6)
		pile(JETTY_X + x, JETTY_TO + 5.4)
	end

	for _, x in { -3.2, 3.2 } do
		kit.part(jetty, Vector3.new(0.6, 0.6, length), CFrame.new(JETTY_X + x, DECK_Y - 0.55, JETTY_FROM + length / 2), deck, "Stringer")
	end

	-- note: a ladder down from the t-head to the water
	for _, x in { -0.7, 0.7 } do
		kit.part(jetty, Vector3.new(0.2, 5, 0.2), CFrame.new(JETTY_X + 4 + x, DECK_Y - 2.2, JETTY_TO + 6.2), palette.iron, "LadderRail")
	end
	for i = 0, 4 do
		kit.part(jetty, Vector3.new(1.4, 0.12, 0.12), CFrame.new(JETTY_X + 4, DECK_Y - 0.4 - i, JETTY_TO + 6.2), palette.iron, "Rung")
	end

	-- note: a granite slipway down the beach into the water
	local from = Vector3.new(40, 0, 50)
	local to = Vector3.new(40, 0, 70)
	local ground_from = Vector3.new(from.X, kit.groundY(from.X, from.Z), from.Z)
	local ground_to = Vector3.new(to.X, math.min(kit.groundY(to.X, to.Z), -1.5), to.Z)
	kit.part(parent, Vector3.new(6.5, 0.8, (ground_to - ground_from).Magnitude), CFrame.lookAt((ground_from + ground_to) / 2, ground_to), palette.granite, "Slipway")

	local details = kit.folder(parent, "Details")
	local head = CFrame.new(JETTY_X, DECK_Y + 0.25, JETTY_TO + 3)
	kit.placePrefab("LampPost", details, head * CFrame.new(6.4, 0, 1.6))
	for _, x in { -6.6, 1.5 } do
		kit.placePrefab("Bollard", details, head * CFrame.new(x, 0, 2.4))
	end
	kit.placePrefab("CrabPot", details, head * CFrame.new(-4.6, 0, -1.2) * CFrame.Angles(0, 0.3, 0))
	kit.placePrefab("CrabPot", details, head * CFrame.new(-4.5, 1.8, -1.1) * CFrame.Angles(0, -0.2, 0))
	kit.placePrefab("FishBox", details, head * CFrame.new(-1.6, 0, -1.6) * CFrame.Angles(0, 0.15, 0))
	kit.placePrefab("RopeCoil", details, head * CFrame.new(3.6, 0, -1.8))
	kit.placePrefab("Barrel", details, head * CFrame.new(-7, 0, -1.4))
	for i, spot in { Vector3.new(JETTY_X - 3.5, DECK_Y + 0.6, 78), Vector3.new(JETTY_X + 3.5, DECK_Y + 0.6, 92), Vector3.new(JETTY_X - 3.5, DECK_Y + 0.6, 98) } do
		kit.placePrefab("Buoy", details, CFrame.new(spot) * CFrame.Angles(0, i, math.rad(90)))
	end

	local boats = kit.folder(parent, "Boats")
	kit.placePrefab("RowboatBlue", boats, CFrame.new(JETTY_X - 6.4, 0.3, 86) * CFrame.Angles(0, math.rad(4), 0))
	kit.placePrefab("RowboatRed", boats, CFrame.new(JETTY_X + 6.6, 0.3, 94) * CFrame.Angles(0, math.rad(-6), 0))
	local beach = Vector3.new(80, kit.groundY(80, 64), 64)
	kit.placePrefab("RowboatGreen", boats, CFrame.new(beach + Vector3.new(0, 0.75, 0)) * CFrame.Angles(0, math.rad(118), math.rad(-7)))
	kit.placePrefab("MooringPost", parent, CFrame.new(84, kit.groundY(84, 58) - 1.5, 58))
	kit.placePrefab("Anchor", details, kit.onGround(CFrame.new(74, 0, 52) * CFrame.Angles(0, 0.8, 0)))
	kit.placePrefab("NetRack", details, kit.onGround(CFrame.new(50, 0, 50) * CFrame.Angles(0, 1.2, 0)))

	-- note: rocks and gorse soften the edges of the cove
	local random = Random.new(61)
	for _, spot in { Vector3.new(4, 0, 58), Vector3.new(-6, 0, 64), Vector3.new(14, 0, 56), Vector3.new(96, 0, 76), Vector3.new(102, 0, 66), Vector3.new(-20, 0, 48), Vector3.new(108, 0, 54) } do
		nature.rock(kit, palette, details, kit.onGround(CFrame.new(spot)), random, random:NextNumber(2.5, 5))
	end

	town.netLoft(deps)
end

-- Green -------------------------------------------------------------------------

local GREEN_CENTRE = Vector3.new(0, 0, -28)
local GREEN_RADIUS = Vector2.new(36, 24) -- note: the ring lane's centreline
local JUNCTION = Vector3.new(33, 0, -56) -- note: beside the lane to Glimmerwood, where it leaves the ring

function town.green(deps: Deps)
	local kit, palette, nature = deps.kit, deps.palette, deps.nature
	local parent = freshFolder(deps, "Green")
	local random = Random.new(7)
	local centre = GREEN_CENTRE
	local oak = Vector3.new(-12, 0, -32)

	nature.oak(kit, palette, parent, kit.onGround(CFrame.new(oak) * CFrame.Angles(0, 0.4, 0)), random, 1)
	kit.placePrefab("Well", parent, kit.onGround(CFrame.new(16, 0, -21) * CFrame.Angles(0, math.rad(-15), 0)))

	-- note: the quest board looks toward the centre of the green
	local board = Vector3.new(9, 0, -41)
	kit.placePrefab("NoticeBoard", parent, kit.onGround(CFrame.lookAt(board, board + (board - centre))))

	-- note: benches face away from the oak, out toward the lane
	for _, offset in { Vector3.new(-7, 0, 7), Vector3.new(8, 0, 4), Vector3.new(-6, 0, -8) } do
		local seat = oak + offset
		kit.placePrefab("Bench", parent, kit.onGround(CFrame.lookAt(seat, seat - offset)))
	end

	for _, spot in { Vector3.new(22, 0, -30), Vector3.new(-26, 0, -18) } do
		kit.placePrefab("FlowerTub", parent, kit.onGround(CFrame.new(spot)))
	end
	nature.border(kit, palette, parent, kit.onGround(CFrame.new(16, 0, -14) * CFrame.Angles(0, 0.3, 0)), 8, 2.4, random)

	-- note: the fingerpost at the junction points travellers up the lane and down to the harbour
	local post = kit.placePrefab("Fingerpost", parent, kit.onGround(CFrame.new(JUNCTION)))
	local arms = {
		{ name = "Arm1", text = "Glimmerwood", toward = Vector3.new(70, 0, -68) },
		{ name = "Arm2", text = "Harbour", toward = Vector3.new(30, 0, 30) },
	}
	for _, arm in arms do
		local model = post:FindFirstChild(arm.name) :: Model
		local pivot = model:GetPivot()
		local direction = (arm.toward - JUNCTION) * Vector3.new(1, 0, 1)
		-- note: an arm points along its local +x, so turn it to face its destination
		local yaw = math.atan2(-direction.Z, direction.X)
		model:PivotTo(CFrame.new(pivot.Position) * CFrame.Angles(0, yaw, 0))
		setLabels(model, arm.text)
	end
end

-- Lanes, hedges and trees ---------------------------------------------------------

local LANE = { Vector3.new(36, 0, -50), Vector3.new(68, 0, -66), Vector3.new(100, 0, -86), Vector3.new(130, 0, -114), Vector3.new(158, 0, -142) }

-- note: Cornish hedges line the lane out of the village once it clears the cottages
function town.hedges(deps: Deps)
	local kit, palette, nature = deps.kit, deps.palette, deps.nature
	local parent = freshFolder(deps, "Hedges")
	local random = Random.new(23)
	for _, side in { -1, 1 } do
		local points = {}
		for i = 2, #LANE do
			local here = LANE[i]
			local along = (LANE[math.min(i + 1, #LANE)] - LANE[i - 1]).Unit
			local across = Vector3.new(-along.Z, 0, along.X)
			table.insert(points, here + across * side * 7.5)
		end
		nature.cornishHedge(kit, palette, parent, points, random, 4)
	end

	-- note: a field hedgerow along the north edge, behind the cottages and the drying yard
	nature.hedge(kit, palette, parent, { Vector3.new(-72, 0, -108), Vector3.new(-38, 0, -112), Vector3.new(-4, 0, -100) }, random, 4.2)
	nature.hedge(kit, palette, parent, { Vector3.new(40, 0, -112), Vector3.new(78, 0, -106) }, random, 4.2)
end

function town.trees(deps: Deps)
	local kit, palette, nature = deps.kit, deps.palette, deps.nature
	local parent = freshFolder(deps, "Trees")
	local random = Random.new(13)

	for _, spot in { Vector3.new(-30, 0, -110), Vector3.new(30, 0, -116), Vector3.new(82, 0, -114), Vector3.new(112, 0, -70), Vector3.new(-78, 0, -66), Vector3.new(84, 0, -24) } do
		nature.broadleaf(kit, palette, parent, kit.onGround(CFrame.new(spot) * CFrame.Angles(0, random:NextNumber(0, 6), 0)), random, random:NextNumber(0.85, 1.15))
	end

	-- note: wind-bent hawthorns along the exposed edges of the plateau
	for _, spot in { Vector3.new(-88, 0, -40), Vector3.new(-86, 0, 8), Vector3.new(-60, 0, 32), Vector3.new(84, 0, 8), Vector3.new(98, 0, -30), Vector3.new(-14, 0, 22) } do
		nature.hawthorn(kit, palette, parent, kit.onGround(CFrame.new(spot)), random, random:NextNumber(0.9, 1.2))
	end

	for _, spot in { Vector3.new(-92, 0, -20), Vector3.new(-70, 0, 26), Vector3.new(76, 0, 18), Vector3.new(102, 0, -40), Vector3.new(-6, 0, 30), Vector3.new(110, 0, -96), Vector3.new(124, 0, -132) } do
		nature.gorse(kit, palette, parent, kit.onGround(CFrame.new(spot)), random, random:NextNumber(2.6, 3.8))
	end
end

-- Paths -------------------------------------------------------------------------

-- note: repaints grass along a route as dirt with gravel patches; the ground shape is untouched
local function paintPath(kit, points: { Vector3 }, width: number)
	local terrain = workspace.Terrain
	local painted = {}

	for i = 1, #points - 1 do
		local from = points[i]
		local to = points[i + 1]
		local along = (to - from).Unit
		local across = Vector3.new(-along.Z, 0, along.X)
		local steps = math.max(math.ceil((to - from).Magnitude / 1.5), 1)

		for step = 0, steps do
			local centre = from:Lerp(to, step / steps)
			local half = width / 2 * (1 + 0.25 * math.noise(centre.X / 9, centre.Z / 9, 0.5))
			for offset = -half, half, 1.5 do
				local spot = centre + across * offset
				local cell_x = math.floor(spot.X / 4) * 4
				local cell_z = math.floor(spot.Z / 4) * 4
				local key = cell_x .. "," .. cell_z
				if not painted[key] then
					painted[key] = true
					local ground = kit.groundY(cell_x + 2, cell_z + 2)
					local low = math.floor((ground - 8) / 4) * 4
					local region = Region3.new(Vector3.new(cell_x, low, cell_z), Vector3.new(cell_x + 4, low + 16, cell_z + 4))
					local gravel = math.noise(cell_x / 14, cell_z / 14, 0.3) > 0.3
					local surface = if gravel then Enum.Material.Limestone else Enum.Material.Ground
					terrain:ReplaceMaterial(region, 4, Enum.Material.Grass, surface)
				end
			end
		end
	end
end

function town.paths(deps: Deps)
	local kit = deps.kit

	-- note: clear earlier paths first; the release 1 terrain has no dirt or gravel of its own
	local area = Region3.new(Vector3.new(-128, -16, -136), Vector3.new(128, 48, 120))
	workspace.Terrain:ReplaceMaterial(area, 4, Enum.Material.Ground, Enum.Material.Grass)
	workspace.Terrain:ReplaceMaterial(area, 4, Enum.Material.Limestone, Enum.Material.Grass)

	local ring = {}
	for i = 0, 32 do
		local angle = i / 32 * math.pi * 2
		table.insert(ring, GREEN_CENTRE + Vector3.new(math.cos(angle) * GREEN_RADIUS.X, 0, math.sin(angle) * GREEN_RADIUS.Y))
	end
	paintPath(kit, ring, 8)
	paintPath(kit, LANE, 8)

	local routes = {
		{ width = 7, points = { Vector3.new(0, 0, -4), Vector3.new(4, 0, 12), Vector3.new(12, 0, 26), Vector3.new(24, 0, 33), Vector3.new(44, 0, 34), Vector3.new(52, 0, 46), Vector3.new(60, 0, 55) } },
		{ width = 5, points = { Vector3.new(44, 0, 34), Vector3.new(60, 0, 42), Vector3.new(84, 0, 44) } },
		{ width = 6, points = { Vector3.new(0, 0, -69), Vector3.new(0, 0, -52) } },
		{ width = 6, points = { Vector3.new(-47, 0, -28), Vector3.new(-36, 0, -28) } },
		{ width = 6, points = { Vector3.new(45, 0, -36), Vector3.new(35, 0, -32) } },
		{ width = 4, points = { Vector3.new(12, 0, -96), Vector3.new(14, 0, -104) } },
	}
	for _, route in routes do
		paintPath(kit, route.points, route.width)
	end

	-- note: each cottage's path starts at its garden gate and finds its way to the ring, around the store where it must
	local ways = {
		{ Vector3.new(-38, 0, -60), Vector3.new(-28, 0, -43) },
		{ Vector3.new(40, 0, -60), Vector3.new(28, 0, -43) },
		{ Vector3.new(68, 0, -57), Vector3.new(48, 0, -56), Vector3.new(34, 0, -46) },
		{ Vector3.new(-24, 0, -10) },
		{ Vector3.new(36, 0, -8), Vector3.new(30, 0, -15) },
	}
	for index in COTTAGES do
		local points = { cottageGate(index), cottageFrame(index):PointToWorldSpace(Vector3.new(0, 0, -COTTAGE_WIDTH / 2 - GARDEN_DEPTH - 4)) }
		for _, point in ways[index] do
			table.insert(points, point)
		end
		paintPath(kit, points, 4)
	end
end

-- Lamps and spawn -----------------------------------------------------------------

function town.lamps(deps: Deps)
	local kit = deps.kit
	local parent = freshFolder(deps, "Lamps")
	local centre = GREEN_CENTRE
	for _, degrees in { 45, 135, 225, 315 } do
		local angle = math.rad(degrees)
		local spot = centre + Vector3.new(math.cos(angle) * (GREEN_RADIUS.X + 5.5), 0, math.sin(angle) * (GREEN_RADIUS.Y + 5.5))
		kit.placePrefab("LampPost", parent, kit.onGround(CFrame.new(spot)))
	end

	for _, spot in { Vector3.new(10, 0, 14), Vector3.new(42, 0, 40), Vector3.new(64, 0, -70), Vector3.new(-30, 0, -62) } do
		kit.placePrefab("LampPost", parent, kit.onGround(CFrame.new(spot)))
	end
end

function town.spawn(deps: Deps)
	local kit = deps.kit
	local parent = root(deps)
	local old = parent:FindFirstChild("SpawnLocation")
	if old then
		old:Destroy()
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Position = Vector3.new(GREEN_CENTRE.X + 6, kit.groundY(GREEN_CENTRE.X + 6, GREEN_CENTRE.Z) + 0.5, GREEN_CENTRE.Z)

	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end

	spawn.Parent = parent
end

-- Build -------------------------------------------------------------------------

function town.buildings(deps: Deps)
	freshFolder(deps, "Buildings")
	town.millRace(deps)
	town.workshop(deps)
	town.inn(deps)
	town.store(deps)
	town.mill(deps)
end

-- note: the whole town in order; paths go first so the grass cleared under buildings stays cleared
function town.all(deps: Deps)
	local parent = root(deps)
	for _, child in parent:GetChildren() do
		child:Destroy()
	end

	town.paths(deps)
	town.buildings(deps)
	town.cottages(deps)
	town.harbor(deps)
	town.green(deps)
	town.hedges(deps)
	town.trees(deps)
	town.lamps(deps)
	town.spawn(deps)

	-- note: small props indoors and small trim outdoors skip shadows
	for _, interior in parent:GetDescendants() do
		if interior.Name == "Interior" and interior:IsA("Folder") then
			deps.kit.quietShadows(interior, 2.5)
		end
	end
	deps.kit.quietShadows(parent, 0.9)
end

return town