--!strict
--[[
	FoldHavenInteriors
	What: dresses Fold Haven's interiors for their trade: the folding workshop's tables and schematics, the inn's taproom
		and bedrooms, the general store's counter and stock, the paper mill's machinery and drying loft, the cottages and the net loft
	Used by: TownBuilds.FoldHaven, which builds each shell, floor, stair and partition first and then calls these
	Needs: deps from FoldHaven (kit, palette, nature) and each building's record (base, size and folders)
	Frames: positions are in a room's local frame: x along its length, z from the front (-) to the back (+), y up from the floor;
		wall() gives a frame on a wall's inner face, x to the right seen from inside, z into the room
	Clearance: door swings, stairs and windows stay clear, and walkways stay about four studs wide
	Lights: hearths, stoves, lanterns and sconces stay lit day and night and cast shadows (see Furniture); one or two per room,
		so rooms stay dim and warm
]]

local T = 1.6
local WEAVE = Enum.Material.Fabric

type Deps = {
	kit: any,
	palette: any,
	nature: any,
	interiors: any,
}

type Room = {
	base: CFrame,
	length: number,
	width: number,
}

type Item = {
	name: string,
	x: number,
	z: number,
	yaw: number?,
}

local interiors = {}

-- Helpers -------------------------------------------------------------------

local function at(room: Room, x: number, z: number, yaw: number?, y: number?): CFrame
	return room.base * CFrame.new(x, y or 0, z) * CFrame.Angles(0, math.rad(yaw or 0), 0)
end

local function wall(deps: Deps, room: Room, side: string, along: number, y: number?, out: number?): CFrame
	return deps.kit.innerFace(room.base, room.length, room.width, T, side, along) * CFrame.new(0, y or 0, out or 0)
end

local function put(deps: Deps, parent: Instance, name: string, frame: CFrame): Model
	return deps.kit.placePrefab(name, parent, frame)
end

-- note: small props on a surface at height y in the surface's own frame
local function dress(deps: Deps, parent: Instance, surface: CFrame, y: number, items: { Item })
	for _, item in items do
		put(deps, parent, item.name, surface * CFrame.new(item.x, y, item.z) * CFrame.Angles(0, math.rad(item.yaw or 0), 0))
	end
end

-- note: a woven rug: a border, a field and two bands, lying just proud of the floor
local function rug(deps: Deps, parent: Instance, frame: CFrame, length: number, width: number, border: Color3, field: Color3)
	local kit = deps.kit
	local edge = { material = WEAVE, color = border }
	kit.detail(kit.part(parent, Vector3.new(length, 0.08, width), frame * CFrame.new(0, 0.09, 0), edge, "Rug"))
	kit.detail(kit.part(parent, Vector3.new(length - 0.8, 0.08, width - 0.8), frame * CFrame.new(0, 0.12, 0), { material = WEAVE, color = field }, "Rug"))
	for _, x in { -length / 4, length / 4 } do
		kit.detail(kit.part(parent, Vector3.new(0.4, 0.08, width - 1.4), frame * CFrame.new(x, 0.15, 0), edge, "Rug"))
	end
end

-- note: a table with chairs drawn up on its long sides
local function tableSet(deps: Deps, parent: Instance, name: string, frame: CFrame, chairs: { Vector2 }): CFrame
	put(deps, parent, name, frame)
	for _, chair in chairs do
		-- note: a chair faces +z, so one on the far side turns round to face the table
		local yaw = if chair.Y > 0 then math.pi else 0
		put(deps, parent, "Chair", frame * CFrame.new(chair.X, 0, chair.Y) * CFrame.Angles(0, yaw, 0))
	end
	return frame
end

-- note: fills each shelf of a shelf prefab with small props picked from a list
local function stock(deps: Deps, parent: Instance, shelf: Model, items: { string }, random: Random, spacing: number)
	local heights = string.split(shelf:GetAttribute("Shelves") :: string, ",")
	local width = shelf:GetAttribute("Width") :: number
	local depth = shelf:GetAttribute("Depth") :: number
	local pivot = shelf:GetPivot()
	for _, text in heights do
		local y = tonumber(text) :: number
		local x = -width / 2 + spacing / 2
		while x <= width / 2 - spacing / 2 do
			if random:NextNumber() < 0.85 then
				local name = items[random:NextInteger(1, #items)]
				local spot = pivot * CFrame.new(x + random:NextNumber(-0.1, 0.1), y, depth / 2 + random:NextNumber(-0.15, 0.15))
				put(deps, parent, name, spot * CFrame.Angles(0, random:NextNumber(-0.4, 0.4), 0))
			end
			x += spacing
		end
	end
end

-- note: a rope between two points with sheets of paper pegged along it
local function dryingLine(deps: Deps, parent: Instance, from: Vector3, to: Vector3, sheets: number, random: Random)
	local kit, palette = deps.kit, deps.palette
	local along = (to - from).Unit
	kit.detail(kit.part(parent, Vector3.new(0.06, 0.06, (to - from).Magnitude), CFrame.lookAt((from + to) / 2, to), palette.rope, "Line"))
	for i = 1, sheets do
		local point = from:Lerp(to, i / (sheets + 1))
		local frame = CFrame.lookAt(point, point + along)
		local sheet = if random:NextNumber() < 0.2 then palette.kraft else palette.paper
		kit.detail(kit.part(parent, Vector3.new(0.04, 1.8, 1.4), frame * CFrame.new(0, -0.95, 0) * CFrame.Angles(0, 0, math.rad(random:NextNumber(-4, 4))), sheet, "Sheet"))
		kit.detail(kit.part(parent, Vector3.new(0.1, 0.35, 0.12), frame * CFrame.new(0, -0.05, 0), palette.oak_light, "Peg"))
	end
end

-- note: a garland of hops slung under a beam, the old pub custom
local function hops(deps: Deps, parent: Instance, from: Vector3, to: Vector3)
	local kit, palette = deps.kit, deps.palette
	local count = math.floor((to - from).Magnitude / 0.7)
	for i = 0, count do
		local sag = 0.2 + 0.3 * math.sin(i / count * math.pi)
		local point = from:Lerp(to, i / count) - Vector3.new(0, sag, 0)
		local leaf = if i % 4 == 0 then palette.leaf else palette.leaf_light
		kit.detail(kit.ellipsoid(parent, Vector3.new(0.42, 0.62, 0.42), CFrame.new(point) * CFrame.Angles(0, i, 0), leaf, "Hop"))
	end
end

-- note: goods hung from a beam on an iron hook
local function hang(deps: Deps, parent: Instance, name: string, top: CFrame, drop: number)
	local kit, palette = deps.kit, deps.palette
	kit.detail(kit.part(parent, Vector3.new(0.08, drop, 0.08), top * CFrame.new(0, -drop / 2, 0), palette.iron, "Hook"))
	local item = put(deps, parent, name, top * CFrame.new(0, -drop, 0))
	local _, size = item:GetBoundingBox()
	item:PivotTo(item:GetPivot() * CFrame.new(0, -size.Y, 0))
end

-- note: a peg rail by a door with a coat and a hat on it; frame on the wall face
local function pegRail(deps: Deps, parent: Instance, frame: CFrame, coat: any)
	local kit, palette = deps.kit, deps.palette
	kit.part(parent, Vector3.new(3.6, 0.35, 0.15), frame * CFrame.new(0, 0, 0.08), palette.oak, "PegRail")
	for _, x in { -1.2, 0, 1.2 } do
		kit.detail(kit.part(parent, Vector3.new(0.14, 0.14, 0.5), frame * CFrame.new(x, 0, 0.35), palette.oak_light, "Peg"))
	end
	kit.detail(kit.ellipsoid(parent, Vector3.new(1.6, 3.2, 0.6), frame * CFrame.new(-1.2, -1.5, 0.45), coat, "Coat"))
	kit.detail(kit.post(parent, 0.5, 1.1, frame * CFrame.new(1.2, -0.1, 0.55), palette.leather, "Hat"))
end

-- note: a sheet pinned up at a point on a wall frame
local function pin(deps: Deps, parent: Instance, frame: CFrame, name: string, x: number, y: number, tilt: number)
	put(deps, parent, name, frame * CFrame.new(x, y, 0.02) * CFrame.Angles(0, 0, math.rad(tilt)))
end

-- Folding Workshop ----------------------------------------------------------

local LOOP = "How a spirit is folded\n1. Find a spirit in the woods\n2. Win its schematic\n3. Bring coin and the right paper\n4. Fold it anew, here"

function interiors.workshop(deps: Deps, building: any)
	local kit, palette = deps.kit, deps.palette
	local parent = building.interior
	local room: Room = { base = building.base, length = building.length, width = building.width }
	local random = Random.new(51)

	-- note: the keeper's folding table in the middle of the floor, with stools for the learners on the front side
	local folding = at(room, 0, 1)
	put(deps, parent, "TableLong", folding)
	dress(deps, parent, folding, 3, {
		{ name = "FoldingMat", x = -4, z = -0.7 },
		{ name = "FoldingMat", x = 4, z = -0.7, yaw = -6 },
		{ name = "BookPress", x = 0, z = 0.6 },
		{ name = "PaperStack", x = -2.4, z = 1 },
		{ name = "Ream", x = 2.5, z = 1, yaw = 12 },
		{ name = "Candlestick", x = -5.4, z = 1.2 },
		{ name = "Candlestick", x = 5.4, z = 1.2 },
	})
	for _, x in { -4, 0, 4 } do
		put(deps, parent, "Stool", at(room, x, -2.4))
	end
	for _, x in { -2.5, 2.5 } do
		put(deps, parent, "Stool", at(room, x, 4.4))
	end
	rug(deps, parent, at(room, 0, 1), 16, 8.4, Color3.fromRGB(82, 46, 40), Color3.fromRGB(116, 64, 50))

	-- note: paper cubbies behind the keeper, either side of the back windows
	put(deps, parent, "Pigeonholes", wall(deps, room, "back", 5))
	put(deps, parent, "Pigeonholes", wall(deps, room, "back", -8))
	local back = wall(deps, room, "back", 0)
	for i, name in { "SchematicCrane", "SchematicBoat", "SchematicFox" } do
		pin(deps, parent, back, name, -9.6 + i * 2.2, 9.9, random:NextNumber(-4, 4))
	end

	-- note: the left wall teaches the loop: a chalkboard, pinned schematics and a drafting desk
	local board = put(deps, parent, "Chalkboard", wall(deps, room, "left", 6.5, 6.2))
	for _, descendant in board:GetDescendants() do
		if descendant:IsA("TextLabel") then
			descendant.Text = LOOP
		end
	end
	put(deps, parent, "DraftingDesk", wall(deps, room, "left", 6.5, 0, 2.4))
	put(deps, parent, "Stool", wall(deps, room, "left", 6.5, 0, 4.6))
	local left = wall(deps, room, "left", 0)
	for i, name in { "SchematicFox", "SchematicCrane", "SchematicBoat", "SchematicCrane" } do
		local x = if i <= 2 then 2.6 else 10.4
		local y = if i % 2 == 0 then 5.4 else 7.8
		pin(deps, parent, left, name, x, y, random:NextNumber(-6, 6))
	end

	local shelf = put(deps, parent, "ShelfUnit", wall(deps, room, "left", -6))
	stock(deps, parent, shelf, { "Ream", "PaperStack", "Ream", "Books" }, random, 1.6)
	for i = 0, 2 do
		put(deps, parent, "PaperRoll", at(room, -17.6, 3.2 + i * 0.75, 90, 0.05 + (i % 2) * 0.7))
	end

	-- note: a repair bench on the right wall and the stove that warms the room, its flue running up to the chimney
	put(deps, parent, "Workbench", wall(deps, room, "right", -6.5))
	put(deps, parent, "Stove", at(room, 14.5, 1))
	kit.post(parent, 10, 0.65, room.base * CFrame.new(14.5, 13, 1), palette.iron, "Flue")
	put(deps, parent, "Basket", at(room, 11.6, 3.6))
	put(deps, parent, "Bucket", at(room, 17.2, 5.2))

	-- note: two practice tables under the front windows
	for _, x in { -13, 13 } do
		local desk = at(room, x, -7.6)
		put(deps, parent, "Table", desk)
		dress(deps, parent, desk, 3, {
			{ name = "FoldingMat", x = -1.3, z = 0.2, yaw = random:NextNumber(-10, 10) },
			{ name = "FoldingMat", x = 1.4, z = 0.1, yaw = random:NextNumber(-10, 10) },
			{ name = "PaperStack", x = 0, z = -0.9 },
		})
		for _, offset in { -1.4, 1.4 } do
			put(deps, parent, "Stool", desk * CFrame.new(offset, 0, 2.6))
		end
	end

	-- note: sheets drying on lines slung between the trusses, well above head height
	for _, span in { { -11, 0 }, { 0, 11 } } do
		for _, z in { -6, 6 } do
			local from = room.base:PointToWorldSpace(Vector3.new(span[1] + 0.5, 12.8, z))
			local to = room.base:PointToWorldSpace(Vector3.new(span[2] - 0.5, 12.8, z))
			dryingLine(deps, parent, from, to, 5, random)
		end
	end

	-- note: two lanterns over the tables; the stove lights the right end
	for _, spot in { Vector3.new(-11, 0, -3), Vector3.new(0, 0, 1) } do
		put(deps, parent, "HangingLantern", at(room, spot.X, spot.Z, 0, 13))
	end

	put(deps, parent, "Broom", at(room, -15.2, 10.6))
	put(deps, parent, "Basket", at(room, -19, -9.6))
	rug(deps, parent, at(room, 0, -9.4), 6, 2.6, Color3.fromRGB(96, 80, 62), Color3.fromRGB(132, 110, 82))
end

-- The Folded Crane Inn ------------------------------------------------------

function interiors.inn(deps: Deps, building: any, plan: any)
	local kit, palette = deps.kit, deps.palette
	local parent = building.interior
	local room: Room = { base = building.base, length = plan.length, width = plan.width }
	local random = Random.new(61)
	local joist_y = plan.lower + 0.05 - 1.4

	-- note: the inglenook on the left gable, with settles either side keeping the draughts off
	put(deps, parent, "Inglenook", wall(deps, room, "left", 0))
	put(deps, parent, "Settle", at(room, -15.2, -8.6, 0))
	put(deps, parent, "Settle", at(room, -15.2, 8.6, 180))
	rug(deps, parent, at(room, -13.8, 0), 6, 9, Color3.fromRGB(110, 46, 40), Color3.fromRGB(150, 92, 56))

	-- note: the bar faces the room, with the back bar against the back wall behind it
	put(deps, parent, "BackBar", wall(deps, room, "back", -2.5))
	local bar = at(room, 2.5, 5.4, 180)
	put(deps, parent, "BarCounter", bar)
	dress(deps, parent, bar, 3.75, {
		{ name = "Tankard", x = -4.6, z = 0.6 },
		{ name = "Tankard", x = 3.4, z = 0.5 },
		{ name = "Tankard", x = 4.1, z = 0.8 },
		{ name = "Jug", x = -3.2, z = 0.2 },
		{ name = "Candlestick", x = 5.6, z = 0.3 },
	})
	for i = 0, 3 do
		put(deps, parent, "Stool", at(room, -1.5 + i * 3, 2.7))
	end

	-- note: hops hang from the joists over the bar
	local joists = { -1.78, 1.78, 5.35 }
	for _, x in joists do
		hops(deps, parent, room.base:PointToWorldSpace(Vector3.new(x, joist_y, -5)), room.base:PointToWorldSpace(Vector3.new(x, joist_y, 7)))
	end

	put(deps, parent, "Dresser", wall(deps, room, "back", 11))
	put(deps, parent, "Barrel", at(room, -20, 10.8))
	put(deps, parent, "Barrel", at(room, -17.6, 11.1, 30))

	-- note: tables by the front windows, clear of the door's swing
	local round = tableSet(deps, parent, "TableRound", at(room, -8, -6.5), { Vector2.new(0, -2.6), Vector2.new(0, 2.6) })
	put(deps, parent, "Chair", round * CFrame.new(2.6, 0, 0) * CFrame.Angles(0, math.rad(-90), 0))
	dress(deps, parent, round, 3, { { name = "Tankard", x = -0.6, z = -0.4 }, { name = "Candlestick", x = 0.5, z = 0.3 } })

	local long = tableSet(deps, parent, "Table", at(room, 7.5, -6.6), { Vector2.new(-1.6, -2.6), Vector2.new(1.6, -2.6), Vector2.new(-1.6, 2.6), Vector2.new(1.6, 2.6) })
	dress(deps, parent, long, 3, { { name = "Bowl", x = -1.5, z = -0.6 }, { name = "Bowl", x = 1.4, z = 0.7 }, { name = "Loaf", x = 0, z = 0 }, { name = "Tankard", x = 2.2, z = -0.6 } })

	local small = tableSet(deps, parent, "TableSmall", at(room, -6.6, 2.4), { Vector2.new(0, -2.4) })
	dress(deps, parent, small, 3, { { name = "Tankard", x = 0.4, z = 0 }, { name = "Candlestick", x = -0.8, z = 0.4 } })

	-- note: a snug between the front windows and the stair
	put(deps, parent, "Clock", wall(deps, room, "front", 13))
	put(deps, parent, "ArmchairGreen", at(room, 12.6, -2.2, 200))
	put(deps, parent, "ArmchairRed", at(room, 14.4, -8.4, 15))
	rug(deps, parent, at(room, 13.6, -5.2), 4.4, 5.6, Color3.fromRGB(70, 84, 110), Color3.fromRGB(176, 150, 104))
	put(deps, parent, "PictureSea", wall(deps, room, "front", -12.5, 7.2))
	pegRail(deps, parent, wall(deps, room, "front", -4.6, 6.6), palette.wool_blue)

	-- note: the inglenook lights the left end, so lanterns hang only over the bar and the right-hand tables
	for _, spot in { Vector3.new(8.9, 0, -4), Vector3.new(1.78, 0, 8.2) } do
		put(deps, parent, "HangingLantern", at(room, spot.X, spot.Z, 0, joist_y))
	end

	-- note: upstairs, two bedrooms open off the corridor; the landing has a chair by the window
	local upper: Room = { base = building.upper, length = plan.length, width = building.upper_width }
	local upper_joists = plan.upper - 1.35

	put(deps, parent, "BedDouble", wall(deps, upper, "left", 6))
	put(deps, parent, "Chest", at(upper, -12.6, -6, 90))
	put(deps, parent, "PictureHills", wall(deps, upper, "left", 6, 7))
	local stand = wall(deps, upper, "front", -8, 0, 1.6)
	put(deps, parent, "TableSmall", stand)
	dress(deps, parent, stand, 3, { { name = "Bowl", x = -0.6, z = 0 }, { name = "Jug", x = 0.8, z = 0.2 } })
	put(deps, parent, "Chair", at(upper, -10.8, -8.6, 40))
	rug(deps, parent, at(upper, -12.6, -0.6), 5, 6.4, Color3.fromRGB(122, 52, 46), Color3.fromRGB(204, 178, 132))
	put(deps, parent, "Sconce", upper.base * CFrame.new(-4.4, 6.4, -6) * CFrame.Angles(0, math.rad(-90), 0))

	put(deps, parent, "Bed", upper.base * CFrame.new(9.6, 0, -7) * CFrame.Angles(0, math.rad(-90), 0))
	put(deps, parent, "PictureSea", upper.base * CFrame.new(9.6, 6.8, -7) * CFrame.Angles(0, math.rad(-90), 0))
	local stand_two = wall(deps, upper, "front", -1.2, 0, 1.6)
	put(deps, parent, "TableSmall", stand_two)
	dress(deps, parent, stand_two, 3, { { name = "Bowl", x = 0.6, z = 0 }, { name = "Candlestick", x = -0.9, z = 0.3 } })
	put(deps, parent, "Chair", at(upper, 1.6, 2.6, 160))
	rug(deps, parent, at(upper, 4.2, -2), 4.4, 5.4, Color3.fromRGB(64, 84, 70), Color3.fromRGB(196, 170, 124))
	put(deps, parent, "Sconce", upper.base * CFrame.new(-3.6, 6.4, -6) * CFrame.Angles(0, math.rad(90), 0))

	rug(deps, parent, at(upper, -5.5, 10.2), 28, 3, Color3.fromRGB(110, 46, 40), Color3.fromRGB(150, 92, 56))
	put(deps, parent, "Chest", wall(deps, upper, "back", 17))
	put(deps, parent, "PictureHills", wall(deps, upper, "back", 2, 6.6))
	put(deps, parent, "ArmchairGreen", at(upper, 14.6, -9.6, 20))
	put(deps, parent, "HangingLantern", at(upper, 14, 9, 0, upper_joists))
end

-- General Store -------------------------------------------------------------

function interiors.store(deps: Deps, building: any)
	local kit, palette = deps.kit, deps.palette
	local parent = building.interior
	local room: Room = { base = building.base, length = building.length, width = building.width }
	local random = Random.new(71)
	local joist_y = building.height + 0.05 - 1.4

	-- note: the counter runs along the back of the shop with the stock behind it
	local counter = at(room, -4, 2.6, 180)
	put(deps, parent, "Counter", counter)
	dress(deps, parent, counter, 3.75, {
		{ name = "Scales", x = -3, z = 0.2 },
		{ name = "SweetJars", x = 2.6, z = 0.4 },
		{ name = "Till", x = -0.4, z = -0.4, yaw = 180 },
		{ name = "Books", x = -4.4, z = -0.5 },
		{ name = "Jar", x = 4.4, z = -0.2 },
	})

	local shelf = put(deps, parent, "ShelfUnit", wall(deps, room, "back", 8.2))
	stock(deps, parent, shelf, { "TinRed", "TinBlue", "TinGreen", "Jar", "TonicRed", "TonicGreen", "TonicBlue", "Books" }, random, 1.1)
	put(deps, parent, "Drawers", wall(deps, room, "back", 2.4))

	local low = put(deps, parent, "ShelfLow", wall(deps, room, "left", 5))
	stock(deps, parent, low, { "Jar", "TinGreen", "TinRed", "TonicRed", "TonicGreen" }, random, 1.1)
	put(deps, parent, "SackOpen", at(room, -10, -0.6))
	put(deps, parent, "Sack", at(room, -8.4, -0.8, 40))

	-- note: a repair corner: a bench of tools under a peg board
	local corner = wall(deps, room, "right", -5.2)
	put(deps, parent, "TableSmall", corner * CFrame.new(0, 0, 1.6))
	dress(deps, parent, corner * CFrame.new(0, 0, 1.6), 3, { { name = "Bucket", x = -0.9, z = 0 }, { name = "Books", x = 0.9, z = 0.2 } })
	kit.part(parent, Vector3.new(5, 3, 0.2), corner * CFrame.new(0, 5.6, 0.1), palette.pine, "PegBoard")
	local tools = {
		{ Vector3.new(0.3, 1.6, 0.1), -1.8, 5.6, palette.oak_light },
		{ Vector3.new(1.8, 0.7, 0.05), -0.2, 6.3, palette.iron },
		{ Vector3.new(0.16, 1.3, 0.1), 1.2, 5.4, palette.iron },
		{ Vector3.new(0.16, 1.1, 0.1), 1.6, 5.5, palette.iron },
		{ Vector3.new(1.2, 0.12, 0.1), 0.2, 4.9, palette.brass },
	}
	for _, tool in tools do
		kit.detail(kit.part(parent, tool[1], corner * CFrame.new(tool[2], tool[3], 0.28), tool[4], "Tool"))
	end

	-- note: bait and apples in barrels, clear of the back door's swing
	put(deps, parent, "Barrel", at(room, 9.8, 6.6))
	put(deps, parent, "Barrel", at(room, 9.8, 3.8, 25))
	local rods = at(room, -10.8, 7.4)
	for i = 0, 2 do
		kit.detail(kit.part(parent, Vector3.new(0.12, 9, 0.12), rods * CFrame.new(i * 0.35, 4.5, 0) * CFrame.Angles(math.rad(-8 + i * 4), 0, math.rad(6)), palette.oak_light, "Rod"))
	end

	-- note: a display table of goods in the middle of the floor
	local display = at(room, 5, -1)
	put(deps, parent, "Table", display)
	dress(deps, parent, display, 3, {
		{ name = "Basket", x = -1.8, z = 0 },
		{ name = "Loaf", x = 0.2, z = -0.6 },
		{ name = "Loaf", x = 0.4, z = 0.7, yaw = 30 },
		{ name = "Jar", x = 1.8, z = -0.4 },
		{ name = "Jar", x = 2.4, z = 0.6 },
	})
	put(deps, parent, "Crate", at(room, -8, -6.4, 10))
	put(deps, parent, "Barrel", at(room, -5.4, -7))

	-- note: goods hung from the joists over the shop floor
	local hung = { { "Kettle", -6.51, -5 }, { "Basket", -3.26, -4.4 }, { "Kettle", 3.26, -5.6 }, { "Bucket", 6.51, -4 }, { "Basket", 9.77, -6 } }
	for _, item in hung do
		hang(deps, parent, item[1] :: string, at(room, item[2] :: number, item[3] :: number, 0, joist_y), 1.4)
	end
	-- note: one lantern between the counter and the display table
	put(deps, parent, "HangingLantern", at(room, 0, 1, 0, joist_y))
	rug(deps, parent, at(room, 0, -7), 5, 2.4, Color3.fromRGB(96, 80, 62), Color3.fromRGB(132, 110, 82))

	-- note: the shopkeeper's rooms upstairs, seen through the front windows
	local upper: Room = { base = building.upper, length = building.length, width = building.upper_width }
	put(deps, parent, "Bed", wall(deps, upper, "back", 6))
	put(deps, parent, "Dresser", wall(deps, upper, "back", -6))
	put(deps, parent, "ArmchairRed", at(upper, 4, -4.6, 160))
	rug(deps, parent, at(upper, 0, -2), 6, 4.4, Color3.fromRGB(70, 84, 110), Color3.fromRGB(196, 170, 124))

	-- note: a reading sconce on the front wall, between the windows above the armchair
	put(deps, parent, "Sconce", wall(deps, upper, "front", 3.75, 6.4))
end

-- Paper Mill ----------------------------------------------------------------

function interiors.mill(deps: Deps, building: any, plan: any)
	local kit, palette = deps.kit, deps.palette
	local parent = building.interior
	local room: Room = { base = building.base, length = plan.length, width = plan.width }
	local random = Random.new(81)
	local joist_y = plan.ground + 0.05 - 1.4

	-- note: the water-driven stampers beat rags to pulp along the back wall
	put(deps, parent, "Stampers", wall(deps, room, "back", 3))
	put(deps, parent, "Basket", at(room, 3.4, 6.4))
	put(deps, parent, "Sack", at(room, -8.6, 7, 30))
	put(deps, parent, "Sack", at(room, 4.6, 7.2, -20))

	-- note: the vat, the couching bench and the great press on the right side, clear of the side door
	put(deps, parent, "Vat", at(room, 4.5, 0.5, 10))
	put(deps, parent, "Stool", at(room, 4.2, -2.7))
	put(deps, parent, "CouchingBench", at(room, 10.6, 6.2))
	put(deps, parent, "ScrewPress", at(room, 9.5, -6))

	-- note: the merchant's counter in the front-left corner, its customers on the door side
	local counter = at(room, -6, -3, 90)
	put(deps, parent, "CounterOak", counter)
	dress(deps, parent, counter, 3.75, {
		{ name = "Ream", x = -2.6, z = 0 },
		{ name = "Ream", x = -2.6, z = 0, yaw = 6 },
		{ name = "Scales", x = 0.4, z = 0.2 },
		{ name = "PaperStack", x = 2.6, z = 0 },
		{ name = "Books", x = 1.4, z = -0.5 },
	})
	for i = 0, 2 do
		put(deps, parent, "Ream", at(room, -8.6, -7.2, random:NextNumber(-8, 8), i * 0.7))
	end

	-- note: a sorting table of finished sheets in the middle
	local sorting = at(room, -1.5, 0, 90)
	put(deps, parent, "TableSmall", sorting)
	dress(deps, parent, sorting, 3, { { name = "PaperStack", x = 0, z = -0.6 }, { name = "Ream", x = 0.2, z = 0.8, yaw = 10 } })
	put(deps, parent, "Broom", at(room, 12.4, 2.8))
	put(deps, parent, "Bucket", at(room, 7.4, 2.6))
	-- note: one lantern over the counter and the sorting table lights the floor
	put(deps, parent, "HangingLantern", at(room, -1.68, -2.2, 0, joist_y))

	-- note: the drying loft: lines of sheets from front to back, a sorting table and bundles waiting to go down
	local loft: Room = { base = building.upper, length = plan.length, width = plan.width }
	for _, x in { -7, -3.5, 0, 3.5, 7, 10.5 } do
		local from = loft.base:PointToWorldSpace(Vector3.new(x, 8.2, -8.2))
		local to = loft.base:PointToWorldSpace(Vector3.new(x, 8.2, 8.2))
		dryingLine(deps, parent, from, to, 7, random)
	end

	local table_frame = at(loft, 3, 5.6)
	put(deps, parent, "TableLong", table_frame)
	dress(deps, parent, table_frame, 3, {
		{ name = "PaperStack", x = -4, z = 0 },
		{ name = "PaperStack", x = -1.6, z = 0.3, yaw = 10 },
		{ name = "Ream", x = 1.2, z = 0 },
		{ name = "Ream", x = 3.6, z = -0.2, yaw = -8 },
	})
	for i = 0, 5 do
		put(deps, parent, "Ream", at(loft, 10.4 + (i % 2) * 1.6, -6.4, random:NextNumber(-6, 6), math.floor(i / 2) * 0.7))
	end
	put(deps, parent, "Basket", at(loft, -6.4, 6.6))
	put(deps, parent, "HangingLantern", at(loft, 1.7, 0, 0, plan.loft + 0.05 - 1.4))
end

-- Cottages --------------------------------------------------------------------

local RUGS = {
	{ Color3.fromRGB(122, 52, 46), Color3.fromRGB(176, 150, 104) },
	{ Color3.fromRGB(64, 84, 70), Color3.fromRGB(196, 170, 124) },
	{ Color3.fromRGB(70, 84, 110), Color3.fromRGB(204, 178, 132) },
}

function interiors.cottage(deps: Deps, building: any)
	local kit, palette = deps.kit, deps.palette
	local parent = building.interior
	local room: Room = { base = building.base, length = building.length, width = building.width }
	local seed = building.seed or 1
	local random = Random.new(200 + seed)
	local colors = RUGS[seed % #RUGS + 1]

	-- note: the hearth on the right gable, where the chimney stack stands outside; its fire is the cottage's only light
	put(deps, parent, "Fireplace", wall(deps, room, "right", 0))
	rug(deps, parent, at(room, 4.6, 0), 3.2, 5, colors[1], colors[2])
	put(deps, parent, if seed % 2 == 0 then "ArmchairGreen" else "ArmchairRed", at(room, 3.4, -3.2, 70))
	put(deps, parent, "Basket", at(room, 7.6, 4.6))

	put(deps, parent, if seed % 2 == 0 then "BedPatch" else "Bed", wall(deps, room, "left", -4))
	put(deps, parent, if seed % 3 == 0 then "PictureHills" else "PictureSea", wall(deps, room, "left", -4, 6.6))
	put(deps, parent, "Dresser", wall(deps, room, "back", 0))

	local dining = tableSet(deps, parent, "Table", at(room, -5.5, -2.2), { Vector2.new(0, -2.9), Vector2.new(0, 3.1) })
	local meal = {
		{ name = "Loaf", x = random:NextNumber(-1.6, -0.6), z = 0 },
		{ name = "Plate", x = 0.4, z = -0.8 },
		{ name = "Plate", x = 0.6, z = 0.8 },
		{ name = "Jug", x = 1.9, z = 0.1 },
		{ name = "Candlestick", x = -2.2, z = 0.5 },
	}
	dress(deps, parent, dining, 3, meal)

	local shelf = wall(deps, room, "left", 3.4, 5.6)
	put(deps, parent, "WallShelf", shelf)
	dress(deps, parent, shelf, 0.15, {
		{ name = "Jar", x = -1.4, z = 0.5 },
		{ name = "Jar", x = -0.6, z = 0.5 },
		{ name = "Jug", x = 0.6, z = 0.5 },
		{ name = "TinGreen", x = 1.5, z = 0.5 },
	})
	put(deps, parent, "Broom", at(room, -3.6, -5.6))
end

-- Net Loft ----------------------------------------------------------------------

function interiors.netLoft(deps: Deps, building: any)
	local kit, palette = deps.kit, deps.palette
	local parent = building.interior
	local room: Room = { base = building.base, length = building.length, width = building.width }

	-- note: nets hung on the back wall with their cork floats, oars leaning on the left
	local back = wall(deps, room, "back", 0)
	local net = kit.part(parent, Vector3.new(9, 5, 0.1), back * CFrame.new(0, 5, 0.2), palette.net, "Net")
	net.Transparency = 0.2
	kit.detail(net)
	for i = 0, 7 do
		kit.detail(kit.ellipsoid(parent, Vector3.new(0.5, 0.32, 0.32), back * CFrame.new(-3.9 + i * 1.1, 7.5, 0.35), palette.oak_light, "Cork"))
	end

	local left = wall(deps, room, "left", 0)
	for i, z in { -0.8, 0.2 } do
		kit.detail(kit.part(parent, Vector3.new(0.2, 8, 0.2), left * CFrame.new(z, 4, 0.6) * CFrame.Angles(math.rad(-6), 0, math.rad(4 * i)), palette.oak_light, "Oar"), true)
		kit.detail(kit.part(parent, Vector3.new(0.6, 1.8, 0.08), left * CFrame.new(z, 0.95, 0.7) * CFrame.Angles(math.rad(-6), 0, math.rad(4 * i)), palette.oak_light, "Blade"), true)
	end

	-- note: a mending table with a heap of net, pots stacked in the corner
	local mending = at(room, -3.8, -1.2)
	put(deps, parent, "TableSmall", mending)
	kit.detail(kit.ellipsoid(parent, Vector3.new(2.6, 0.8, 2), mending * CFrame.new(0, 3.3, 0), palette.net, "NetHeap"))
	put(deps, parent, "Stool", at(room, -3.8, 1.4))
	put(deps, parent, "CrabPot", at(room, 5.4, 2.4, 10))
	put(deps, parent, "CrabPot", at(room, 5.4, 2.4, -20, 1.8))
	put(deps, parent, "RopeCoil", at(room, 2.6, 2.4))
	put(deps, parent, "Buoy", at(room, 0.6, 2.6))
	put(deps, parent, "HangingLantern", at(room, 0, 0, 0, building.height))
end

return interiors