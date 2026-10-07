--!strict
--[[
	Furniture
	What: adds the interior prefabs to ServerStorage.Prefabs: furniture, hearths and lamps, tableware, shop fittings,
		papermaking gear and the folding workshop's tools
	Used by: the studio assistant (edit mode); nothing requires it at runtime
	Needs: kit (BuildKit) and palette (BuildPalette), passed in because studio caches required modules
	Order: run after Prefabs.build(), which clears the folder
	Frames: standing pieces pivot on the floor at their centre and face +z (a user stands on the +z side);
		wall pieces pivot on the floor at their back, against the wall, and reach out along +z
	Cost: visual parts skip collision and queries; a single invisible Collider box gives big pieces their collision
	Lights: hearths, stoves, lanterns and sconces stay lit day and night and cast shadows, so walls, floors and partitions stop them;
		the fittings themselves cast none; nothing here is tagged NightLight
]]

local rgb = Color3.fromRGB
local material = Enum.Material

type Style = { material: Enum.Material, color: Color3, variant: string?, transparency: number? }

local FIRE_COLOR = rgb(255, 150, 72)
local CANDLE_COLOR = rgb(255, 196, 132)
local FLAME_OUTER: Style = { material = material.Neon, color = rgb(255, 112, 36) }
local FLAME_INNER: Style = { material = material.Neon, color = rgb(255, 178, 84) }
local PEWTER: Style = { material = material.Metal, color = rgb(132, 134, 136) }
local WAX: Style = { material = material.SmoothPlastic, color = rgb(238, 230, 206) }
local SLATE_BOARD: Style = { material = material.Slate, color = rgb(46, 52, 50) }
local CHINA: Style = { material = material.SmoothPlastic, color = rgb(236, 238, 240) }
local CHINA_BLUE: Style = { material = material.SmoothPlastic, color = rgb(70, 96, 150) }
local SWEETS = { rgb(214, 70, 82), rgb(240, 196, 70), rgb(120, 180, 110), rgb(232, 150, 190), rgb(150, 110, 70) }

local furniture = {}

-- Helpers -------------------------------------------------------------------

local function legs(kit, model: Model, width: number, depth: number, height: number, size: number, style: Style)
	for _, corner in { Vector2.new(-1, -1), Vector2.new(1, -1), Vector2.new(1, 1), Vector2.new(-1, 1) } do
		local x = corner.X * (width / 2 - size / 2)
		local z = corner.Y * (depth / 2 - size / 2)
		kit.part(model, Vector3.new(size, height, size), CFrame.new(x, height / 2, z), style, "Leg")
	end
end

-- note: visual parts stop colliding; big pieces get one simple collider box instead
local function finish(kit, model: Model, collider: Vector3?, centre: Vector3?)
	kit.detail(model, true)
	if collider then
		kit.collider(model, collider, CFrame.new(centre or Vector3.new(0, collider.Y / 2, 0)))
	end
end

local function label(part: BasePart, face: Enum.NormalId, text: string, color: Color3, font: Enum.Font)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 1

	local text_label = Instance.new("TextLabel")
	text_label.Name = "Label"
	text_label.BackgroundTransparency = 1
	text_label.Size = UDim2.fromScale(0.9, 0.86)
	text_label.Position = UDim2.fromScale(0.05, 0.07)
	text_label.Font = font
	text_label.TextScaled = true
	text_label.TextWrapped = true
	text_label.TextXAlignment = Enum.TextXAlignment.Left
	text_label.TextYAlignment = Enum.TextYAlignment.Top
	text_label.TextColor3 = color
	text_label.Text = text
	text_label.Parent = gui
	gui.Parent = part
end

-- note: shadows keep each light inside its room
local function pointLight(parent: BasePart, color: Color3, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = true
	light.Parent = parent
end

-- note: a small fire: logs, embers, two crossed flames, rising sparks and a warm light
local function fire(kit, palette, model: Model, base: CFrame, width: number, range: number)
	-- note: logs, embers and flames cast no shadow, so they never block the fire's own light
	for _, offset in { -0.35, 0.35 } do
		kit.detail(kit.cylinder(model, width, 0.5, base * CFrame.new(0, 0.3, offset) * CFrame.Angles(0, math.rad(offset * 20), 0), palette.bark, "Log"))
	end
	kit.detail(kit.cylinder(model, width * 0.8, 0.45, base * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, math.rad(12), 0), palette.bark, "Log"))
	kit.detail(kit.part(model, Vector3.new(width * 0.9, 0.15, 1.2), base * CFrame.new(0, 0.1, 0), palette.ember, "Embers"))

	-- note: an orange outer flame with a smaller, brighter one inside it; the sparks do most of the work
	local flame = kit.ellipsoid(model, Vector3.new(width * 0.4, 1.3, 0.2), base * CFrame.new(0, 1.15, 0), FLAME_OUTER, "Flame")
	flame.Transparency = 0.3
	local side_flame = kit.ellipsoid(model, Vector3.new(0.18, 0.9, width * 0.22), base * CFrame.new(0.15, 1, 0), FLAME_OUTER, "Flame")
	side_flame.Transparency = 0.3
	local inner_flame = kit.ellipsoid(model, Vector3.new(width * 0.2, 0.7, 0.14), base * CFrame.new(-0.1, 0.95, 0), FLAME_INNER, "Flame")
	for _, part in { flame, side_flame, inner_flame } do
		kit.detail(part)
	end

	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Fire"
	sparks.Texture = "rbxasset://textures/particles/fire_main.dds"
	sparks.Color = ColorSequence.new(rgb(255, 170, 90), rgb(220, 80, 40))
	sparks.LightEmission = 1
	sparks.Rate = 22
	sparks.Lifetime = NumberRange.new(0.5, 0.9)
	sparks.Speed = NumberRange.new(1, 2)
	sparks.SpreadAngle = Vector2.new(12, 12)
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0.3) })
	sparks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	sparks.Parent = flame
	pointLight(flame, FIRE_COLOR, range, 1.3)
end

-- note: a candle with a lit flame; no light of its own, so tables can carry many cheaply
local function candle(kit, palette, model: Model, base: CFrame, height: number)
	kit.post(model, 0.12, 0.5, base, palette.brass, "Holder")
	kit.post(model, height, 0.2, base * CFrame.new(0, 0.1, 0), WAX, "Candle")
	kit.ellipsoid(model, Vector3.new(0.14, 0.32, 0.14), base * CFrame.new(0, 0.1 + height + 0.14, 0), palette.flame, "Flame")
end

-- note: a four-sided lantern hanging from base (its top); lit by a candle and a warm light
local function lanternHead(kit, palette, model: Model, top: CFrame, range: number)
	kit.post(model, 0.25, 0.7, top * CFrame.new(0, -0.25, 0), palette.iron, "Cap")
	kit.part(model, Vector3.new(1, 0.12, 1), top * CFrame.new(0, -0.32, 0), palette.iron, "Brim")
	local glass = kit.part(model, Vector3.new(0.8, 1.1, 0.8), top * CFrame.new(0, -0.95, 0), palette.lamp_glass, "Glass")
	glass.CastShadow = false
	for _, corner in { Vector2.new(-1, -1), Vector2.new(1, -1), Vector2.new(1, 1), Vector2.new(-1, 1) } do
		kit.part(model, Vector3.new(0.08, 1.2, 0.08), top * CFrame.new(corner.X * 0.42, -0.95, corner.Y * 0.42), palette.iron, "Frame")
	end
	kit.part(model, Vector3.new(1, 0.12, 1), top * CFrame.new(0, -1.56, 0), palette.iron, "Tray")
	local flame = kit.ellipsoid(model, Vector3.new(0.18, 0.4, 0.18), top * CFrame.new(0, -0.95, 0), palette.flame, "Flame")
	-- note: kept gentle; night exposure lifts every light further
	pointLight(flame, CANDLE_COLOR, range, 0.8)
end

-- Tables and seats ------------------------------------------------------------

local function makeTable(kit, palette, folder: Instance, name: string, width: number, depth: number, top_style: Style)
	local model = kit.model(folder, name, CFrame.new())
	kit.part(model, Vector3.new(width, 0.25, depth), CFrame.new(0, 2.875, 0), top_style, "Top")
	kit.part(model, Vector3.new(width - 0.8, 0.45, depth - 0.6), CFrame.new(0, 2.52, 0), palette.oak, "Apron")
	legs(kit, model, width - 0.4, depth - 0.3, 2.75, 0.35, palette.oak)
	kit.part(model, Vector3.new(width - 1, 0.2, 0.2), CFrame.new(0, 0.5, 0), palette.oak, "Stretcher")
	finish(kit, model, Vector3.new(width, 3, depth))
end

local function makeRoundTable(kit, palette, folder: Instance)
	local model = kit.model(folder, "TableRound", CFrame.new())
	kit.post(model, 0.22, 4.2, CFrame.new(0, 2.78, 0), palette.oak, "Top")
	kit.post(model, 2.6, 0.6, CFrame.new(0, 0.2, 0), palette.oak, "Pedestal")
	for _, yaw in { 0, 90 } do
		kit.part(model, Vector3.new(2.6, 0.3, 0.4), CFrame.new(0, 0.15, 0) * CFrame.Angles(0, math.rad(yaw), 0), palette.oak, "Foot")
	end
	finish(kit, model, Vector3.new(3.4, 3, 3.4))
end

-- note: a ladder-back chair with a rush seat; the sitter faces +z
local function makeChair(kit, palette, folder: Instance)
	local model = kit.model(folder, "Chair", CFrame.new())
	kit.part(model, Vector3.new(1.9, 0.18, 1.8), CFrame.new(0, 1.9, 0), palette.hessian, "Seat")
	for _, x in { -0.82, 0.82 } do
		kit.part(model, Vector3.new(0.22, 1.9, 0.22), CFrame.new(x, 0.95, 0.78), palette.oak, "Leg")
		kit.part(model, Vector3.new(0.22, 4.4, 0.22), CFrame.new(x, 2.2, -0.8), palette.oak, "Upright")
	end
	for _, y in { 2.7, 3.3, 3.9 } do
		kit.part(model, Vector3.new(1.6, 0.3, 0.1), CFrame.new(0, y, -0.82), palette.oak, "Slat")
	end
	kit.part(model, Vector3.new(1.6, 0.14, 0.14), CFrame.new(0, 0.6, 0.78), palette.oak, "Rung")
	finish(kit, model, Vector3.new(1.9, 2, 1.8), Vector3.new(0, 1, 0))
end

local function makeStool(kit, palette, folder: Instance)
	local model = kit.model(folder, "Stool", CFrame.new())
	kit.post(model, 0.22, 1.5, CFrame.new(0, 1.85, 0), palette.oak_light, "Seat")
	for i = 0, 2 do
		local turn = CFrame.Angles(0, i * math.pi * 2 / 3, 0)
		kit.part(model, Vector3.new(0.2, 1.95, 0.2), turn * CFrame.new(0, 0.95, 0.5) * CFrame.Angles(math.rad(10), 0, 0), palette.oak, "Leg")
	end
	finish(kit, model)
end

-- note: a high-backed settle that keeps the draughts off; the sitter faces +z
local function makeSettle(kit, palette, folder: Instance)
	local model = kit.model(folder, "Settle", CFrame.new())
	kit.part(model, Vector3.new(6, 0.25, 1.8), CFrame.new(0, 1.9, 0.05), palette.oak, "Seat")
	kit.part(model, Vector3.new(6, 1.75, 0.2), CFrame.new(0, 0.9, 0.85), palette.oak, "Front")
	kit.part(model, Vector3.new(6.2, 6.2, 0.3), CFrame.new(0, 3.1, -0.95), palette.oak, "Back")
	for _, x in { -3.05, 3.05 } do
		kit.part(model, Vector3.new(0.3, 3.4, 2.1), CFrame.new(x, 1.7, 0), palette.oak, "End")
	end
	kit.part(model, Vector3.new(5.6, 0.5, 1.4), CFrame.new(0, 2.15, 0.05), palette.wool_red, "Cushion")
	finish(kit, model, Vector3.new(6.2, 6.2, 2.1), Vector3.new(0, 3.1, 0))
end

-- note: an upholstered wing chair for a snug; the sitter faces +z
local function makeArmchair(kit, palette, folder: Instance, name: string, cloth: Style)
	local model = kit.model(folder, name, CFrame.new())
	kit.part(model, Vector3.new(2.8, 1.3, 2.6), CFrame.new(0, 1.05, 0), cloth, "Base")
	kit.part(model, Vector3.new(2.1, 0.45, 2.1), CFrame.new(0, 1.9, 0.2), cloth, "Cushion")
	kit.part(model, Vector3.new(2.8, 3.4, 0.6), CFrame.new(0, 2.4, -1.05) * CFrame.Angles(math.rad(-6), 0, 0), cloth, "Back")
	for _, side in { -1, 1 } do
		kit.part(model, Vector3.new(0.45, 0.9, 2.4), CFrame.new(side * 1.2, 2.1, 0.05), cloth, "Arm")
		kit.part(model, Vector3.new(0.4, 1.8, 1.1), CFrame.new(side * 1.25, 3.3, -0.65), cloth, "Wing")
		for _, z in { -1.1, 1.1 } do
			kit.part(model, Vector3.new(0.25, 0.4, 0.25), CFrame.new(side * 1.2, 0.2, z), palette.timber, "Foot")
		end
	end
	finish(kit, model, Vector3.new(2.9, 2.2, 2.7), Vector3.new(0, 1.1, 0))
end

-- Beds and storage ------------------------------------------------------------

-- note: a wall piece; the headboard stands against the wall and the bed runs out along +z
local function makeBed(kit, palette, folder: Instance, name: string, width: number, quilt: Style)
	local model = kit.model(folder, name, CFrame.new())
	local length = 7.2
	kit.part(model, Vector3.new(width, 0.9, length), CFrame.new(0, 0.95, length / 2 + 0.3), palette.oak, "Frame")
	kit.part(model, Vector3.new(width - 0.2, 0.7, length - 0.2), CFrame.new(0, 1.7, length / 2 + 0.3), palette.linen, "Mattress")
	kit.part(model, Vector3.new(width + 0.1, 0.3, length * 0.68), CFrame.new(0, 2.08, length * 0.66 + 0.3), quilt, "Quilt")
	kit.part(model, Vector3.new(width + 0.12, 1.1, 0.12), CFrame.new(0, 1.55, length + 0.3 - 0.06), quilt, "Drape")
	for _, x in { -width / 4, width / 4 } do
		if width > 4 or x < 0 then
			kit.ellipsoid(model, Vector3.new(math.min(width / 2 - 0.2, 2.6), 0.6, 1.2), CFrame.new(if width > 4 then x else 0, 2.2, 1.1), palette.linen, "Pillow")
		end
	end
	kit.part(model, Vector3.new(width + 0.4, 4, 0.3), CFrame.new(0, 2, 0.15), palette.oak, "Headboard")
	kit.part(model, Vector3.new(width + 0.4, 2.2, 0.3), CFrame.new(0, 1.1, length + 0.45), palette.oak, "Footboard")
	finish(kit, model, Vector3.new(width + 0.4, 2.4, length + 0.6), Vector3.new(0, 1.2, length / 2 + 0.3))
end

-- note: a blanket chest with iron straps; a wall piece
local function makeChest(kit, palette, folder: Instance)
	local model = kit.model(folder, "Chest", CFrame.new())
	kit.part(model, Vector3.new(3.6, 1.7, 1.9), CFrame.new(0, 1.05, 0.95), palette.oak, "Body")
	kit.part(model, Vector3.new(3.7, 0.25, 2), CFrame.new(0, 2.02, 0.95), palette.oak_light, "Lid")
	for _, x in { -1.2, 1.2 } do
		kit.part(model, Vector3.new(0.25, 1.95, 0.05), CFrame.new(x, 1.1, 1.92), palette.iron, "Strap")
	end
	kit.part(model, Vector3.new(0.35, 0.45, 0.06), CFrame.new(0, 1.7, 1.93), palette.brass, "Lock")
	legs(kit, model, 3.5, 1.8, 0.25, 0.3, palette.timber)
	finish(kit, model, Vector3.new(3.7, 2.15, 2), Vector3.new(0, 1.07, 0.95))
end

-- note: a welsh dresser with plates on its rack and jugs on the worktop; a wall piece
local function makeDresser(kit, palette, folder: Instance)
	local model = kit.model(folder, "Dresser", CFrame.new())
	kit.part(model, Vector3.new(5.6, 3, 2), CFrame.new(0, 1.7, 1), palette.oak, "Cupboard")
	for _, x in { -1.4, 1.4 } do
		kit.part(model, Vector3.new(2.4, 2.2, 0.08), CFrame.new(x, 1.7, 2.02), palette.oak_light, "Door")
		kit.ball(model, 0.2, CFrame.new(x + (if x < 0 then 0.9 else -0.9), 1.9, 2.1), palette.brass, "Knob")
	end
	kit.part(model, Vector3.new(5.6, 0.2, 2), CFrame.new(0, 0.1, 1), palette.timber, "Plinth")
	kit.part(model, Vector3.new(5.9, 0.2, 2.2), CFrame.new(0, 3.3, 1.05), palette.oak_light, "Worktop")
	kit.part(model, Vector3.new(5.6, 4.4, 0.2), CFrame.new(0, 5.6, 0.1), palette.oak, "RackBack")
	for _, x in { -2.68, 2.68 } do
		kit.part(model, Vector3.new(0.25, 4.4, 1), CFrame.new(x, 5.6, 0.5), palette.oak, "RackSide")
	end
	kit.part(model, Vector3.new(6, 0.35, 1.2), CFrame.new(0, 7.95, 0.55), palette.oak, "Cornice")

	for _, y in { 4.9, 6.5 } do
		kit.part(model, Vector3.new(5.2, 0.14, 0.9), CFrame.new(0, y, 0.55), palette.oak_light, "Shelf")
		for i = 0, 4 do
			local plate = if i % 2 == 0 then CHINA_BLUE else CHINA
			kit.cylinder(model, 0.08, 1, CFrame.new(-2 + i, y + 0.55, 0.35) * CFrame.Angles(math.rad(-12), math.rad(90), 0), plate, "Plate")
		end
	end

	for i, x in { -2, -0.6, 1.4 } do
		kit.post(model, 0.8 + i * 0.15, 0.6, CFrame.new(x, 3.4, 1.4), if i == 2 then CHINA_BLUE else CHINA, "Jug")
	end
	finish(kit, model, Vector3.new(5.9, 8, 2.2), Vector3.new(0, 4, 1.05))
end

-- note: open shelving for stock; a wall piece; shelf heights are in the Shelves attribute
local function makeShelfUnit(kit, palette, folder: Instance, name: string, width: number, height: number, depth: number, style: Style)
	local model = kit.model(folder, name, CFrame.new())
	kit.part(model, Vector3.new(width, height, 0.15), CFrame.new(0, height / 2, 0.08), style, "Back")
	for _, x in { -width / 2 + 0.12, width / 2 - 0.12 } do
		kit.part(model, Vector3.new(0.25, height, depth), CFrame.new(x, height / 2, depth / 2), style, "Side")
	end

	local shelves = {}
	local count = math.floor(height / 1.8)
	for i = 0, count - 1 do
		local y = 0.3 + i * (height - 0.6) / (count - 1)
		kit.part(model, Vector3.new(width - 0.4, 0.16, depth - 0.1), CFrame.new(0, y, depth / 2), style, "Shelf")
		table.insert(shelves, string.format("%.2f", y + 0.08))
	end

	model:SetAttribute("Shelves", table.concat(shelves, ","))
	model:SetAttribute("Width", width - 0.6)
	model:SetAttribute("Depth", depth)
	finish(kit, model, Vector3.new(width, height, depth), Vector3.new(0, height / 2, depth / 2))
end

-- note: a chest of small drawers with brass knobs, for a shop's sundries; a wall piece
local function makeDrawers(kit, palette, folder: Instance)
	local model = kit.model(folder, "Drawers", CFrame.new())
	kit.part(model, Vector3.new(5, 4.6, 1.6), CFrame.new(0, 2.3, 0.8), palette.oak, "Body")
	for col = 0, 3 do
		for row = 0, 4 do
			local x = -1.8 + col * 1.2
			local y = 0.6 + row * 0.85
			kit.part(model, Vector3.new(1.08, 0.74, 0.08), CFrame.new(x, y, 1.62), palette.oak_light, "Drawer")
			kit.ball(model, 0.16, CFrame.new(x, y, 1.7), palette.brass, "Knob")
		end
	end
	kit.part(model, Vector3.new(5.2, 0.2, 1.8), CFrame.new(0, 4.7, 0.85), palette.oak_light, "Top")
	finish(kit, model, Vector3.new(5.2, 4.8, 1.8), Vector3.new(0, 2.4, 0.9))
end

-- note: a cabinet of paper cubbies, some stocked with sheets; a wall piece
local function makePigeonholes(kit, palette, folder: Instance)
	local model = kit.model(folder, "Pigeonholes", CFrame.new())
	local width, height, depth = 6.4, 7, 1.6
	local cols, rows = 6, 6
	kit.part(model, Vector3.new(width, height, 0.15), CFrame.new(0, height / 2 + 0.6, 0.08), palette.oak, "Back")
	kit.part(model, Vector3.new(width, 0.6, depth), CFrame.new(0, 0.3, depth / 2), palette.timber, "Base")
	for i = 0, cols do
		local x = -width / 2 + 0.1 + i * (width - 0.2) / cols
		kit.part(model, Vector3.new(0.14, height, depth), CFrame.new(x, height / 2 + 0.6, depth / 2), palette.oak, "Divider")
	end
	for j = 0, rows do
		local y = 0.6 + j * height / rows
		kit.part(model, Vector3.new(width, 0.12, depth), CFrame.new(0, y, depth / 2), palette.oak, "Shelf")
	end

	local random = Random.new(21)
	for i = 0, cols - 1 do
		for j = 0, rows - 1 do
			if random:NextNumber() < 0.75 then
				local x = -width / 2 + 0.1 + (i + 0.5) * (width - 0.2) / cols
				local thick = random:NextNumber(0.15, 0.55)
				local y = 0.66 + j * height / rows + thick / 2
				local sheet = if random:NextNumber() < 0.25 then palette.kraft else palette.paper
				kit.part(model, Vector3.new(0.8, thick, depth - 0.3), CFrame.new(x, y, depth / 2 + random:NextNumber(-0.1, 0.1)), sheet, "Sheets")
			end
		end
	end
	kit.part(model, Vector3.new(width + 0.3, 0.3, depth + 0.2), CFrame.new(0, height + 0.75, depth / 2), palette.oak, "Cornice")
	finish(kit, model, Vector3.new(width + 0.3, height + 0.9, depth + 0.2), Vector3.new(0, (height + 0.9) / 2, depth / 2))
end

-- note: a plank shelf on iron brackets; a wall piece, top at 0.15 above the pivot
local function makeWallShelf(kit, palette, folder: Instance)
	local model = kit.model(folder, "WallShelf", CFrame.new())
	kit.part(model, Vector3.new(4.4, 0.15, 1), CFrame.new(0, 0.075, 0.5), palette.oak_light, "Plank")
	for _, x in { -1.6, 1.6 } do
		kit.part(model, Vector3.new(0.1, 0.8, 0.8), CFrame.new(x, -0.4, 0.4), palette.iron, "Bracket")
	end
	finish(kit, model)
end

-- Hearths and lamps -----------------------------------------------------------

-- note: a cottage hearth: stone jambs, an oak bressumer, a chimney breast to the ceiling and a fire; a wall piece
local function makeFireplace(kit, palette, folder: Instance, height: number)
	local model = kit.model(folder, "Fireplace", CFrame.new())
	local width = 6.4
	local depth = 1.8
	for _, x in { -2.6, 2.6 } do
		kit.part(model, Vector3.new(1.2, 4.4, depth), CFrame.new(x, 2.2, depth / 2), palette.stone, "Jamb")
	end
	kit.part(model, Vector3.new(width, 0.9, depth + 0.1), CFrame.new(0, 4.85, depth / 2 + 0.05), palette.timber, "Bressumer")
	kit.part(model, Vector3.new(width, height - 5.3, depth), CFrame.new(0, 5.3 + (height - 5.3) / 2, depth / 2), palette.plaster, "Breast")
	kit.part(model, Vector3.new(width + 0.6, 0.25, 1), CFrame.new(0, 5.42, depth + 0.3), palette.oak_light, "Mantel")
	kit.part(model, Vector3.new(4, 4.4, 0.3), CFrame.new(0, 2.2, 0.15), palette.soot, "Back")
	kit.part(model, Vector3.new(width + 0.6, 0.22, depth + 1.2), CFrame.new(0, 0.11, depth / 2 + 0.6), palette.hearth, "Hearth")
	fire(kit, palette, model, CFrame.new(0, 0.22, 0.9), 2.4, 16)

	candle(kit, palette, model, CFrame.new(-2.4, 5.55, depth + 0.3), 0.6)
	candle(kit, palette, model, CFrame.new(2.4, 5.55, depth + 0.3), 0.6)
	kit.post(model, 0.7, 0.5, CFrame.new(-0.9, 5.55, depth + 0.3), CHINA_BLUE, "Vase")
	kit.part(model, Vector3.new(1.1, 0.9, 0.35), CFrame.new(0.7, 5.98, depth + 0.25), palette.oak, "Clock")
	kit.cylinder(model, 0.05, 0.6, CFrame.new(0.7, 6.05, depth + 0.45) * CFrame.Angles(0, math.rad(90), 0), CHINA, "Face")
	finish(kit, model, Vector3.new(width, height, depth), Vector3.new(0, height / 2, depth / 2))
end

-- note: an inn's inglenook: a deep fireplace with seats inside it, a brick breast, a kettle on a crane; a wall piece
local function makeInglenook(kit, palette, folder: Instance, height: number)
	local model = kit.model(folder, "Inglenook", CFrame.new())
	local width = 14
	local depth = 3.6
	local opening = 9
	local mouth = 6.4
	for _, side in { -1, 1 } do
		kit.part(model, Vector3.new((width - opening) / 2, mouth, depth), CFrame.new(side * (opening / 2 + (width - opening) / 4), mouth / 2, depth / 2), palette.brick, "Jamb")
	end
	kit.part(model, Vector3.new(width, 1.3, depth + 0.2), CFrame.new(0, mouth + 0.65, depth / 2 + 0.1), palette.timber, "Bressumer")
	kit.part(model, Vector3.new(width, height - mouth - 1.3, depth), CFrame.new(0, mouth + 1.3 + (height - mouth - 1.3) / 2, depth / 2), palette.brick, "Breast")
	kit.part(model, Vector3.new(opening, mouth, 0.4), CFrame.new(0, mouth / 2, 0.2), palette.soot, "Back")
	kit.part(model, Vector3.new(opening, 0.25, depth + 0.8), CFrame.new(0, 0.12, depth / 2 + 0.4), palette.hearth, "Hearth")

	for _, side in { -1, 1 } do
		local x = side * (opening / 2 - 0.9)
		kit.part(model, Vector3.new(1.4, 1.8, depth - 0.6), CFrame.new(x, 0.9, depth / 2), palette.oak, "NookSeat")
	end

	kit.part(model, Vector3.new(2.6, 0.3, 1.4), CFrame.new(0, 0.55, 1.4), palette.iron, "Basket")
	for _, x in { -1.1, 1.1 } do
		kit.part(model, Vector3.new(0.2, 1.2, 0.2), CFrame.new(x, 0.7, 2.1), palette.iron, "Firedog")
	end
	fire(kit, palette, model, CFrame.new(0, 0.7, 1.4), 2.6, 20)

	kit.part(model, Vector3.new(0.18, 5, 0.18), CFrame.new(-3, 2.9, 0.6), palette.iron, "CranePost")
	kit.part(model, Vector3.new(2.8, 0.16, 0.16), CFrame.new(-1.7, 4.9, 0.6), palette.iron, "CraneArm")
	kit.part(model, Vector3.new(0.08, 1.6, 0.08), CFrame.new(-0.6, 4.1, 0.6), palette.iron, "Hook")
	kit.ellipsoid(model, Vector3.new(1.2, 1, 1.2), CFrame.new(-0.6, 3, 0.6), palette.copper, "Kettle")

	kit.part(model, Vector3.new(width + 0.4, 0.3, 1.1), CFrame.new(0, mouth + 1.45, depth + 0.45), palette.oak_light, "Mantel")
	for i, x in { -5.5, -3.8, 3.8, 5.5 } do
		kit.cylinder(model, 0.12, 1, CFrame.new(x, mouth + 2.1, depth + 0.3) * CFrame.Angles(math.rad(-10), math.rad(90), 0), if i % 2 == 0 then CHINA_BLUE else CHINA, "Plate")
	end
	kit.post(model, 0.9, 0.7, CFrame.new(0, mouth + 1.6, depth + 0.45), palette.copper, "Jug")
	finish(kit, model, Vector3.new(width, height, depth), Vector3.new(0, height / 2, depth / 2))

	-- note: the nook seats stay walkable inside the opening, so the collider covers only the breast and jambs
	local collider = model:FindFirstChild("Collider")
	if collider and collider:IsA("BasePart") then
		collider.Size = Vector3.new(width, height - mouth, depth)
		collider.CFrame = CFrame.new(0, mouth + (height - mouth) / 2, depth / 2)
	end
	for _, side in { -1, 1 } do
		kit.collider(model, Vector3.new((width - opening) / 2, mouth, depth), CFrame.new(side * (opening / 2 + (width - opening) / 4), mouth / 2, depth / 2))
	end
end

-- note: a pot-bellied iron stove with its flue pipe up to height; standing
local function makeStove(kit, palette, folder: Instance, height: number)
	local model = kit.model(folder, "Stove", CFrame.new())
	legs(kit, model, 2.2, 2.2, 0.6, 0.3, palette.iron)
	kit.post(model, 2.8, 2.4, CFrame.new(0, 0.6, 0), palette.iron, "Body")
	kit.post(model, 0.3, 2.7, CFrame.new(0, 3.4, 0), palette.iron, "Top")
	kit.post(model, height - 3.7, 0.65, CFrame.new(0, 3.7, 0), palette.iron, "Flue")
	local door = kit.part(model, Vector3.new(0.9, 0.7, 0.1), CFrame.new(0, 1.6, 1.2), palette.ember, "Glow")
	pointLight(door, FIRE_COLOR, 12, 1.1)
	kit.part(model, Vector3.new(4, 0.15, 4), CFrame.new(0, 0.07, 0), palette.hearth, "Hearth")
	kit.ellipsoid(model, Vector3.new(1, 0.9, 1), CFrame.new(0.4, 4, 0), palette.copper, "Kettle")
	finish(kit, model, Vector3.new(2.6, 3.6, 2.6), Vector3.new(0, 1.8, 0))
end

-- note: a lantern on a chain; pivot at the ceiling, hanging down by drop
local function makeHangingLantern(kit, palette, folder: Instance, drop: number)
	local model = kit.model(folder, "HangingLantern", CFrame.new())
	kit.part(model, Vector3.new(0.5, 0.15, 0.5), CFrame.new(0, -0.075, 0), palette.iron, "Rose")
	kit.part(model, Vector3.new(0.08, drop, 0.08), CFrame.new(0, -drop / 2, 0), palette.iron, "Chain")
	lanternHead(kit, palette, model, CFrame.new(0, -drop, 0), 16)
	-- note: the fitting casts no shadow, so it never blocks its own light
	kit.detail(model)
end

-- note: a wall candle sconce with a small light; a wall piece, mounted at its pivot
local function makeSconce(kit, palette, folder: Instance)
	local model = kit.model(folder, "Sconce", CFrame.new())
	kit.part(model, Vector3.new(0.5, 1, 0.1), CFrame.new(0, 0, 0.05), palette.brass, "Plate")
	kit.part(model, Vector3.new(0.12, 0.12, 0.7), CFrame.new(0, -0.3, 0.4), palette.brass, "Arm")
	candle(kit, palette, model, CFrame.new(0, -0.25, 0.75), 0.5)
	local flame = model:FindFirstChild("Flame")
	if flame and flame:IsA("BasePart") then
		pointLight(flame, CANDLE_COLOR, 10, 0.7)
	end
	-- note: the fitting casts no shadow, so it never blocks its own light
	kit.detail(model)
end

local function makeCandlestick(kit, palette, folder: Instance)
	local model = kit.model(folder, "Candlestick", CFrame.new())
	kit.post(model, 0.12, 0.6, CFrame.new(), palette.brass, "Foot")
	kit.post(model, 0.6, 0.16, CFrame.new(0, 0.1, 0), palette.brass, "Stem")
	candle(kit, palette, model, CFrame.new(0, 0.65, 0), 0.7)
	finish(kit, model)
end

-- Wall dressing -----------------------------------------------------------------

-- note: a framed seascape; a wall piece, centred on its pivot
local function makePicture(kit, palette, folder: Instance, name: string, bands: { Color3 })
	local model = kit.model(folder, name, CFrame.new())
	kit.part(model, Vector3.new(3.4, 2.6, 0.15), CFrame.new(0, 0, 0.08), palette.brass, "Frame")
	local height = 2.1 / #bands
	for i, color in bands do
		local y = 1.05 - (i - 0.5) * height
		kit.part(model, Vector3.new(2.9, height, 0.05), CFrame.new(0, y, 0.17), { material = material.SmoothPlastic, color = color }, "Paint")
	end
	kit.wedge(model, Vector3.new(0.05, 0.5, 0.35), CFrame.new(0.4, 0.05, 0.2) * CFrame.Angles(0, math.rad(90), 0), CHINA, "Sail")
	finish(kit, model)
end

-- note: a slate chalkboard on an oak frame; a wall piece, centred on its pivot; set its Label text
local function makeChalkboard(kit, palette, folder: Instance)
	local model = kit.model(folder, "Chalkboard", CFrame.new())
	kit.part(model, Vector3.new(5.4, 3.8, 0.2), CFrame.new(0, 0, 0.1), palette.oak, "Frame")
	local board = kit.part(model, Vector3.new(5, 3.4, 0.1), CFrame.new(0, 0, 0.22), SLATE_BOARD, "Board")
	kit.part(model, Vector3.new(5.2, 0.12, 0.4), CFrame.new(0, -1.95, 0.3), palette.oak, "Ledge")
	kit.part(model, Vector3.new(0.4, 0.1, 0.1), CFrame.new(1.6, -1.85, 0.35), palette.paper_white, "Chalk")
	label(board, Enum.NormalId.Back, "", rgb(232, 230, 220), Enum.Font.PatrickHand)
	finish(kit, model)
end

-- note: a grandfather clock; standing, its face toward +z
local function makeClock(kit, palette, folder: Instance)
	local model = kit.model(folder, "Clock", CFrame.new())
	kit.part(model, Vector3.new(1.8, 1.6, 1.2), CFrame.new(0, 0.8, 0), palette.oak, "Base")
	kit.part(model, Vector3.new(1.4, 3.4, 1), CFrame.new(0, 3.3, 0), palette.oak, "Trunk")
	kit.part(model, Vector3.new(0.6, 1.6, 0.05), CFrame.new(0, 3.2, 0.52), palette.glass, "Window")
	kit.post(model, 0.05, 0.4, CFrame.new(0, 2.7, 0.45) * CFrame.Angles(math.rad(90), 0, 0), palette.brass, "Pendulum")
	kit.part(model, Vector3.new(1.9, 2, 1.3), CFrame.new(0, 6, 0), palette.oak, "Hood")
	kit.cylinder(model, 0.05, 1.3, CFrame.new(0, 6, 0.66) * CFrame.Angles(0, math.rad(90), 0), CHINA, "Face")
	kit.part(model, Vector3.new(0.06, 0.5, 0.03), CFrame.new(0, 6.2, 0.7), palette.ink, "Hand")
	kit.part(model, Vector3.new(0.4, 0.06, 0.03), CFrame.new(0.15, 6, 0.7), palette.ink, "Hand")
	kit.part(model, Vector3.new(2, 0.3, 1.4), CFrame.new(0, 7.15, 0), palette.oak_light, "Crest")
	finish(kit, model, Vector3.new(1.9, 7.3, 1.3), Vector3.new(0, 3.65, 0))
end

-- Shop and bar fittings ---------------------------------------------------------

-- note: a panelled counter; standing, the customer's side toward +z
local function makeCounter(kit, palette, folder: Instance, name: string, length: number, body: Style)
	local model = kit.model(folder, name, CFrame.new())
	kit.part(model, Vector3.new(length, 3.3, 2.2), CFrame.new(0, 1.85, 0), body, "Body")
	kit.part(model, Vector3.new(length, 0.4, 2), CFrame.new(0, 0.2, -0.05), palette.timber, "Kick")
	kit.part(model, Vector3.new(length + 0.4, 0.25, 2.6), CFrame.new(0, 3.62, 0.1), palette.oak_light, "Top")
	local panels = math.max(math.floor(length / 3), 1)
	for i = 0, panels - 1 do
		local x = -length / 2 + (i + 0.5) * length / panels
		kit.part(model, Vector3.new(length / panels - 0.7, 2.2, 0.08), CFrame.new(x, 1.95, 1.12), body, "Panel")
	end
	finish(kit, model, Vector3.new(length + 0.4, 3.75, 2.6), Vector3.new(0, 1.87, 0.1))
end

-- note: a pub counter with beer engines and a brass foot rail; standing, the drinkers' side toward +z
local function makeBarCounter(kit, palette, folder: Instance, length: number)
	makeCounter(kit, palette, folder, "BarCounter", length, palette.oak)
	local model = folder:FindFirstChild("BarCounter") :: Model

	-- note: the counter already has its collider, so only these extras become detail
	local extras = {}
	table.insert(extras, kit.cylinder(model, length, 0.25, CFrame.new(0, 0.7, 1.55), palette.brass, "FootRail"))
	for i = 0, 2 do
		local x = -1.6 + i * 1.6
		table.insert(extras, kit.post(model, 0.9, 0.35, CFrame.new(x, 3.75, -0.6), palette.brass, "Pump"))
		table.insert(extras, kit.part(model, Vector3.new(0.22, 1.4, 0.22), CFrame.new(x, 5.25, -0.55) * CFrame.Angles(math.rad(12), 0, 0), palette.timber, "Handle"))
	end
	table.insert(extras, kit.part(model, Vector3.new(5, 0.08, 0.8), CFrame.new(0, 3.77, 0.3), palette.brass, "DripTray"))
	for _, part in extras do
		kit.detail(part, true)
	end
end

-- note: bottles and tankards on shelves over a cupboard, behind a bar; a wall piece
local function makeBackBar(kit, palette, folder: Instance, length: number)
	local model = kit.model(folder, "BackBar", CFrame.new())
	kit.part(model, Vector3.new(length, 3.4, 1.8), CFrame.new(0, 1.7, 0.9), palette.oak, "Cupboard")
	kit.part(model, Vector3.new(length + 0.2, 0.2, 2), CFrame.new(0, 3.5, 1), palette.oak_light, "Top")
	kit.part(model, Vector3.new(length, 4.6, 0.15), CFrame.new(0, 6, 0.08), palette.oak, "Back")

	local random = Random.new(9)
	local glass = { palette.glass_green, palette.glass_amber, palette.glass_blue }
	for _, y in { 5, 6.6 } do
		kit.part(model, Vector3.new(length, 0.14, 0.9), CFrame.new(0, y, 0.5), palette.oak_light, "Shelf")
		local x = -length / 2 + 0.6
		while x < length / 2 - 0.6 do
			if y < 6 then
				kit.post(model, 0.7, 0.55, CFrame.new(x, y + 0.07, 0.5), PEWTER, "Tankard")
				kit.part(model, Vector3.new(0.12, 0.45, 0.3), CFrame.new(x + 0.33, y + 0.42, 0.5), PEWTER, "Handle")
				x += 0.9
			else
				local tall = random:NextNumber(0.9, 1.3)
				kit.post(model, tall, 0.38, CFrame.new(x, y + 0.07, 0.45), glass[random:NextInteger(1, #glass)], "Bottle")
				kit.post(model, 0.35, 0.16, CFrame.new(x, y + 0.07 + tall, 0.45), palette.oak_light, "Cork")
				x += 0.6
			end
		end
	end
	finish(kit, model, Vector3.new(length, 3.6, 2), Vector3.new(0, 1.8, 1))
end

-- note: casks lying on a rack with brass taps; a wall piece
local function makeStillage(kit, palette, folder: Instance)
	local model = kit.model(folder, "Stillage", CFrame.new())
	for _, z in { 0.6, 2.4 } do
		kit.part(model, Vector3.new(8.4, 0.5, 0.5), CFrame.new(0, 1.3, z), palette.oak, "Rail")
		for _, x in { -3.9, 3.9 } do
			kit.part(model, Vector3.new(0.5, 1.05, 0.5), CFrame.new(x, 0.53, z), palette.oak, "Leg")
		end
	end
	for i = -1, 1 do
		local cask = CFrame.new(i * 2.7, 2.65, 1.5) * CFrame.Angles(0, math.rad(90), 0)
		kit.cylinder(model, 3, 2.3, cask, palette.oak, "Cask")
		for _, offset in { -1, 1 } do
			kit.cylinder(model, 0.14, 2.4, cask * CFrame.new(offset, 0, 0), palette.iron, "Hoop")
		end
		kit.part(model, Vector3.new(0.18, 0.18, 0.5), CFrame.new(i * 2.7, 2.2, 3.15), palette.brass, "Tap")
	end
	finish(kit, model, Vector3.new(8.4, 3.9, 3), Vector3.new(0, 1.95, 1.5))
end

-- note: brass balance scales with a few weights
local function makeScales(kit, palette, folder: Instance)
	local model = kit.model(folder, "Scales", CFrame.new())
	kit.part(model, Vector3.new(1.8, 0.2, 0.8), CFrame.new(0, 0.1, 0), palette.oak, "Base")
	kit.post(model, 1.4, 0.14, CFrame.new(0, 0.2, 0), palette.brass, "Column")
	kit.part(model, Vector3.new(1.8, 0.08, 0.1), CFrame.new(0, 1.6, 0), palette.brass, "Beam")
	for _, x in { -0.8, 0.8 } do
		kit.part(model, Vector3.new(0.04, 0.8, 0.04), CFrame.new(x, 1.2, 0), palette.brass, "Hanger")
		kit.post(model, 0.06, 0.8, CFrame.new(x, 0.8, 0), palette.brass, "Pan")
	end
	for i, size in { 0.3, 0.24, 0.18 } do
		kit.post(model, size, size, CFrame.new(-0.6 + i * 0.3, 0.2, 0.3), palette.brass, "Weight")
	end
	finish(kit, model)
end

-- note: a row of sweet jars with lids
local function makeSweetJars(kit, palette, folder: Instance)
	local model = kit.model(folder, "SweetJars", CFrame.new())
	for i, color in SWEETS do
		local x = (i - 3) * 0.8
		kit.post(model, 0.7, 0.55, CFrame.new(x, 0, 0), { material = material.SmoothPlastic, color = color }, "Sweets")
		local jar = kit.post(model, 1.1, 0.7, CFrame.new(x, 0, 0), palette.glass_clear, "Jar")
		jar.CastShadow = false
		kit.post(model, 0.15, 0.5, CFrame.new(x, 1.1, 0), palette.paper_white, "Lid")
	end
	finish(kit, model)
end

local function makeTill(kit, palette, folder: Instance)
	local model = kit.model(folder, "Till", CFrame.new())
	kit.part(model, Vector3.new(1.6, 0.8, 1.2), CFrame.new(0, 0.4, 0), palette.brass, "Body")
	kit.wedge(model, Vector3.new(1.6, 0.5, 1), CFrame.new(0, 1.05, 0.05) * CFrame.Angles(0, math.pi, 0), palette.brass, "Keys")
	kit.part(model, Vector3.new(1.2, 0.5, 0.15), CFrame.new(0, 1.1, -0.5), palette.brass, "Display")
	kit.part(model, Vector3.new(1.4, 0.3, 0.1), CFrame.new(0, 0.25, 0.62), palette.oak, "Drawer")
	finish(kit, model)
end

-- Small things ----------------------------------------------------------------

local function makeTankard(kit, palette, folder: Instance)
	local model = kit.model(folder, "Tankard", CFrame.new())
	kit.post(model, 0.65, 0.5, CFrame.new(), PEWTER, "Body")
	kit.part(model, Vector3.new(0.1, 0.4, 0.25), CFrame.new(0.3, 0.35, 0), PEWTER, "Handle")
	kit.post(model, 0.04, 0.42, CFrame.new(0, 0.6, 0), palette.wool_ochre, "Ale")
	finish(kit, model)
end

local function makePlate(kit, palette, folder: Instance)
	local model = kit.model(folder, "Plate", CFrame.new())
	kit.post(model, 0.06, 1, CFrame.new(), CHINA, "Plate")
	kit.post(model, 0.03, 0.7, CFrame.new(0, 0.05, 0), CHINA_BLUE, "Pattern")
	finish(kit, model)
end

local function makeBowl(kit, palette, folder: Instance)
	local model = kit.model(folder, "Bowl", CFrame.new())
	kit.ellipsoid(model, Vector3.new(0.9, 0.5, 0.9), CFrame.new(0, 0.18, 0), CHINA, "Bowl")
	kit.post(model, 0.04, 0.72, CFrame.new(0, 0.36, 0), palette.wool_ochre, "Broth")
	finish(kit, model)
end

local function makeJug(kit, palette, folder: Instance)
	local model = kit.model(folder, "Jug", CFrame.new())
	kit.post(model, 0.9, 0.6, CFrame.new(), CHINA_BLUE, "Body")
	kit.wedge(model, Vector3.new(0.2, 0.2, 0.25), CFrame.new(0, 0.85, 0.35), CHINA_BLUE, "Spout")
	kit.part(model, Vector3.new(0.1, 0.5, 0.25), CFrame.new(0, 0.5, -0.36), CHINA_BLUE, "Handle")
	finish(kit, model)
end

local function makeBottle(kit, palette, folder: Instance, name: string, glass: Style)
	local model = kit.model(folder, name, CFrame.new())
	kit.post(model, 0.8, 0.4, CFrame.new(), glass, "Body")
	kit.post(model, 0.35, 0.16, CFrame.new(0, 0.8, 0), glass, "Neck")
	kit.post(model, 0.12, 0.18, CFrame.new(0, 1.15, 0), palette.oak_light, "Cork")
	kit.part(model, Vector3.new(0.3, 0.28, 0.02), CFrame.new(0, 0.4, 0.2), palette.paper, "Label")
	finish(kit, model)
end

local function makeJar(kit, palette, folder: Instance)
	local model = kit.model(folder, "Jar", CFrame.new())
	kit.post(model, 0.55, 0.5, CFrame.new(), { material = material.SmoothPlastic, color = rgb(150, 54, 62) }, "Jam")
	local jar = kit.post(model, 0.7, 0.58, CFrame.new(), palette.glass_clear, "Glass")
	jar.CastShadow = false
	kit.post(model, 0.1, 0.62, CFrame.new(0, 0.7, 0), palette.linen, "Cover")
	finish(kit, model)
end

local function makeTin(kit, palette, folder: Instance, name: string, paint: Style)
	local model = kit.model(folder, name, CFrame.new())
	kit.post(model, 0.8, 0.6, CFrame.new(), paint, "Body")
	kit.post(model, 0.08, 0.62, CFrame.new(0, 0.8, 0), palette.brass, "Lid")
	kit.post(model, 0.3, 0.61, CFrame.new(0, 0.3, 0), palette.paper, "Label")
	finish(kit, model)
end

local function makeBooks(kit, palette, folder: Instance)
	local model = kit.model(folder, "Books", CFrame.new())
	local covers = { palette.wool_red, palette.wool_green, palette.wool_blue, palette.leather }
	local y = 0
	for i, cover in covers do
		local thick = 0.22 + (i % 2) * 0.06
		kit.part(model, Vector3.new(1.3 - i * 0.06, thick, 0.95 - i * 0.03), CFrame.new(0, y + thick / 2, 0) * CFrame.Angles(0, math.rad(i * 7 - 10), 0), { material = material.Leather, color = cover.color }, "Book")
		y += thick
	end
	finish(kit, model)
end

local function makeKettle(kit, palette, folder: Instance)
	local model = kit.model(folder, "Kettle", CFrame.new())
	kit.ellipsoid(model, Vector3.new(1, 0.85, 1), CFrame.new(0, 0.42, 0), palette.copper, "Body")
	kit.part(model, Vector3.new(0.12, 0.12, 0.6), CFrame.new(0, 0.55, 0.55) * CFrame.Angles(math.rad(-35), 0, 0), palette.copper, "Spout")
	kit.part(model, Vector3.new(0.1, 0.1, 0.8), CFrame.new(0, 1, 0), palette.iron, "Handle")
	finish(kit, model)
end

local function makeBucket(kit, palette, folder: Instance)
	local model = kit.model(folder, "Bucket", CFrame.new())
	kit.post(model, 1.1, 1.1, CFrame.new(), palette.oak, "Body")
	for _, y in { 0.2, 0.85 } do
		kit.post(model, 0.1, 1.16, CFrame.new(0, y, 0), palette.iron, "Hoop")
	end
	kit.part(model, Vector3.new(1.2, 0.08, 0.08), CFrame.new(0, 1.5, 0), palette.iron, "Handle")
	finish(kit, model)
end

local function makeBroom(kit, palette, folder: Instance)
	local model = kit.model(folder, "Broom", CFrame.new())
	local lean = CFrame.Angles(math.rad(-12), 0, 0)
	kit.part(model, Vector3.new(0.14, 4.6, 0.14), lean * CFrame.new(0, 3, 0), palette.oak_light, "Handle")
	kit.ellipsoid(model, Vector3.new(0.8, 1.4, 0.8), lean * CFrame.new(0, 0.7, 0), palette.hessian, "Brush")
	finish(kit, model)
end

local function makeLoaf(kit, palette, folder: Instance)
	local model = kit.model(folder, "Loaf", CFrame.new())
	kit.ellipsoid(model, Vector3.new(1.2, 0.6, 0.7), CFrame.new(0, 0.28, 0), { material = material.Sand, color = rgb(196, 140, 78) }, "Bread")
	kit.part(model, Vector3.new(1.4, 0.1, 0.9), CFrame.new(0, 0.05, 0), palette.oak_light, "Board")
	finish(kit, model)
end

-- Paper and folding ---------------------------------------------------------------

-- note: a stack of loose sheets with a few strays on top
local function makePaperStack(kit, palette, folder: Instance)
	local model = kit.model(folder, "PaperStack", CFrame.new())
	kit.part(model, Vector3.new(1.3, 0.5, 1.7), CFrame.new(0, 0.25, 0), palette.paper, "Stack")
	for i = 1, 3 do
		kit.part(model, Vector3.new(1.3, 0.03, 1.7), CFrame.new(0.05 * i, 0.5 + i * 0.03, 0.04 * i) * CFrame.Angles(0, math.rad(i * 6 - 4), 0), palette.paper_white, "Sheet")
	end
	finish(kit, model)
end

-- note: a ream wrapped in kraft paper and tied with twine
local function makeReam(kit, palette, folder: Instance)
	local model = kit.model(folder, "Ream", CFrame.new())
	kit.part(model, Vector3.new(1.4, 0.7, 1.9), CFrame.new(0, 0.35, 0), palette.kraft, "Wrap")
	kit.part(model, Vector3.new(1.42, 0.72, 0.06), CFrame.new(0, 0.35, 0), palette.rope, "Twine")
	kit.part(model, Vector3.new(0.06, 0.72, 1.92), CFrame.new(0, 0.35, 0), palette.rope, "Twine")
	kit.part(model, Vector3.new(0.7, 0.02, 0.5), CFrame.new(-0.25, 0.71, 0.5), palette.paper_white, "Ticket")
	finish(kit, model)
end

local function makePaperRoll(kit, palette, folder: Instance)
	local model = kit.model(folder, "PaperRoll", CFrame.new())
	kit.cylinder(model, 3, 0.7, CFrame.new(0, 0.35, 0), palette.paper, "Roll")
	kit.cylinder(model, 3.08, 0.2, CFrame.new(0, 0.35, 0), palette.kraft, "Core")
	finish(kit, model)
end

-- note: a pinned schematic: a square sheet with crease lines and fold arrows drawn on it; a wall piece
local function makeSchematic(kit, palette, folder: Instance, name: string, lines: { { number } })
	local model = kit.model(folder, name, CFrame.new())
	local sheet = 1.8
	kit.part(model, Vector3.new(sheet, sheet * 1.3, 0.04), CFrame.new(0, 0, 0.02), palette.paper, "Sheet")
	for _, line in lines do
		local from = Vector3.new(line[1] * sheet / 2, line[2] * sheet / 2, 0.05)
		local to = Vector3.new(line[3] * sheet / 2, line[4] * sheet / 2, 0.05)
		local length = (to - from).Magnitude
		local angle = math.atan2(to.Y - from.Y, to.X - from.X)
		kit.part(model, Vector3.new(length, 0.05, 0.02), CFrame.new((from + to) / 2) * CFrame.Angles(0, 0, angle), palette.ink, "Crease")
	end
	kit.ball(model, 0.14, CFrame.new(0, sheet * 0.6, 0.06), palette.brass, "Pin")
	finish(kit, model)
end

-- note: a folding mat with a half-folded square on it and a bone folder beside
local function makeFoldingMat(kit, palette, folder: Instance)
	local model = kit.model(folder, "FoldingMat", CFrame.new())
	kit.part(model, Vector3.new(2.4, 0.05, 1.8), CFrame.new(0, 0.025, 0), palette.wool_green, "Mat")
	kit.part(model, Vector3.new(1.2, 0.03, 1.2), CFrame.new(-0.2, 0.065, 0) * CFrame.Angles(0, math.rad(15), 0), palette.paper_white, "Square")
	kit.wedge(model, Vector3.new(0.85, 0.35, 0.85), CFrame.new(-0.2, 0.25, 0.05) * CFrame.Angles(0, math.rad(60), 0), palette.paper_white, "Fold")
	kit.part(model, Vector3.new(0.9, 0.05, 0.14), CFrame.new(0.8, 0.075, 0.4) * CFrame.Angles(0, math.rad(-20), 0), palette.linen, "BoneFolder")
	kit.part(model, Vector3.new(0.1, 0.05, 1.5), CFrame.new(0.95, 0.075, -0.2), palette.brass, "Ruler")
	finish(kit, model)
end

-- note: a heavy workbench with a vice, a tool board behind it and tools on hooks; a wall piece
local function makeWorkbench(kit, palette, folder: Instance)
	local model = kit.model(folder, "Workbench", CFrame.new())
	local length = 9
	kit.part(model, Vector3.new(length, 0.5, 3), CFrame.new(0, 3.25, 1.6), palette.oak_light, "Top")
	legs(kit, model, length - 0.4, 2.8, 3, 0.5, palette.oak)
	for _, part in model:GetChildren() do
		if part.Name == "Leg" and part:IsA("BasePart") then
			part.CFrame += Vector3.new(0, 0, 1.6)
		end
	end
	kit.part(model, Vector3.new(length - 0.8, 0.2, 2.4), CFrame.new(0, 0.9, 1.6), palette.oak, "Shelf")
	kit.part(model, Vector3.new(0.9, 0.7, 0.7), CFrame.new(length / 2 - 0.9, 3.75, 2.9), palette.iron, "Vice")
	kit.part(model, Vector3.new(length, 3.6, 0.2), CFrame.new(0, 5.6, 0.1), palette.pine, "ToolBoard")

	local tools = {
		{ Vector3.new(0.3, 1.6, 0.1), -3.4, 5.6, palette.oak_light },
		{ Vector3.new(1.8, 0.7, 0.05), -2, 5.9, palette.iron },
		{ Vector3.new(0.15, 1.2, 0.1), -0.6, 5.5, palette.iron },
		{ Vector3.new(0.15, 1, 0.1), -0.2, 5.6, palette.iron },
		{ Vector3.new(0.15, 1.3, 0.1), 0.2, 5.5, palette.iron },
		{ Vector3.new(1.4, 0.1, 0.1), 1.6, 6.4, palette.brass },
		{ Vector3.new(0.8, 1.6, 0.06), 3, 5.4, palette.iron },
	}
	for _, tool in tools do
		kit.part(model, tool[1], CFrame.new(tool[2], tool[3], 0.28), tool[4], "Tool")
	end
	finish(kit, model, Vector3.new(length, 3.5, 3), Vector3.new(0, 1.75, 1.6))
end

-- note: a sloped drafting desk for drawing schematics, with a sheet pinned on it; standing, the user on +z
local function makeDraftingDesk(kit, palette, folder: Instance)
	local model = kit.model(folder, "DraftingDesk", CFrame.new())
	legs(kit, model, 4, 2.8, 3.6, 0.3, palette.oak)
	local slope = CFrame.new(0, 4, 0) * CFrame.Angles(math.rad(22), 0, 0)
	kit.part(model, Vector3.new(4.4, 0.2, 3.2), slope, palette.oak_light, "Board")
	kit.part(model, Vector3.new(2.2, 0.03, 2.6), slope * CFrame.new(0, 0.12, 0), palette.paper, "Sheet")
	kit.part(model, Vector3.new(4.4, 0.25, 0.25), slope * CFrame.new(0, 0.2, 1.5), palette.oak, "Lip")
	kit.part(model, Vector3.new(0.08, 0.08, 1), slope * CFrame.new(1.4, 0.18, 0.4), palette.ink, "Pen")
	finish(kit, model, Vector3.new(4.4, 4.4, 3.2), Vector3.new(0, 2.2, 0))
end

-- note: a bench-top screw press for flattening sheets
local function makeBookPress(kit, palette, folder: Instance)
	local model = kit.model(folder, "BookPress", CFrame.new())
	kit.part(model, Vector3.new(2.4, 0.4, 1.8), CFrame.new(0, 0.2, 0), palette.oak, "Bed")
	for _, x in { -1, 1 } do
		kit.part(model, Vector3.new(0.35, 2.4, 0.35), CFrame.new(x, 1.4, 0), palette.oak, "Post")
	end
	kit.part(model, Vector3.new(2.4, 0.4, 0.6), CFrame.new(0, 2.6, 0), palette.oak, "Head")
	kit.post(model, 1.6, 0.3, CFrame.new(0, 1.2, 0), palette.iron, "Screw")
	kit.part(model, Vector3.new(1.6, 0.25, 1.4), CFrame.new(0, 1.05, 0), palette.oak_light, "Platen")
	kit.part(model, Vector3.new(1.4, 0.5, 1.2), CFrame.new(0, 0.65, 0), palette.paper, "Sheets")
	kit.cylinder(model, 2.2, 0.14, CFrame.new(0, 2.95, 0) * CFrame.Angles(0, math.rad(30), 0), palette.iron, "Bar")
	finish(kit, model)
end

-- Papermaking -------------------------------------------------------------------

-- note: the vat of pulp with the vatman's plank across it and a mould and deckle resting on the plank
local function makeVat(kit, palette, folder: Instance)
	local model = kit.model(folder, "Vat", CFrame.new())
	kit.post(model, 3.2, 5.2, CFrame.new(), palette.oak, "Tub")
	for _, y in { 0.4, 1.6, 2.8 } do
		kit.post(model, 0.16, 5.3, CFrame.new(0, y, 0), palette.iron, "Hoop")
	end
	kit.post(model, 0.1, 4.8, CFrame.new(0, 3.05, 0), palette.pulp, "Pulp")
	kit.part(model, Vector3.new(6, 0.25, 1), CFrame.new(0, 3.32, -0.6), palette.oak_light, "Plank")
	local mould = CFrame.new(0.4, 3.52, -0.6) * CFrame.Angles(0, math.rad(8), 0)
	kit.part(model, Vector3.new(2.6, 0.12, 1.8), mould, palette.oak_light, "Mould")
	kit.part(model, Vector3.new(2.3, 0.04, 1.5), mould * CFrame.new(0, 0.07, 0), palette.pulp, "Sheet")
	finish(kit, model, Vector3.new(5.2, 3.3, 5.2), Vector3.new(0, 1.65, 0))
end

-- note: a couching bench with a post of felts and wet sheets; standing
local function makeCouchingBench(kit, palette, folder: Instance)
	local model = kit.model(folder, "CouchingBench", CFrame.new())
	kit.part(model, Vector3.new(4, 0.3, 3), CFrame.new(0, 2.2, 0), palette.oak, "Top")
	legs(kit, model, 3.8, 2.8, 2.05, 0.35, palette.oak)
	for i = 0, 9 do
		local layer = if i % 2 == 0 then palette.felt else palette.pulp
		kit.part(model, Vector3.new(2.6, 0.1, 2), CFrame.new(0.2, 2.4 + i * 0.1, 0) * CFrame.Angles(0, math.rad((i % 3) - 1), 0), layer, "Layer")
	end
	finish(kit, model, Vector3.new(4, 3.4, 3), Vector3.new(0, 1.7, 0))
end

-- note: a great wooden screw press for squeezing the water out of a post of sheets; standing
local function makeScrewPress(kit, palette, folder: Instance)
	local model = kit.model(folder, "ScrewPress", CFrame.new())
	for _, x in { -2.2, 2.2 } do
		kit.part(model, Vector3.new(1, 8.5, 1.2), CFrame.new(x, 4.25, 0), palette.oak, "Cheek")
	end
	kit.part(model, Vector3.new(5.6, 1.2, 1.6), CFrame.new(0, 7.9, 0), palette.oak, "Head")
	kit.part(model, Vector3.new(5.6, 1.4, 2.6), CFrame.new(0, 0.7, 0), palette.oak, "Bed")
	kit.post(model, 4.2, 0.9, CFrame.new(0, 3.7, 0), palette.oak_light, "Screw")
	kit.part(model, Vector3.new(3.2, 0.5, 2.2), CFrame.new(0, 3.5, 0), palette.oak, "Platen")
	for i = 0, 5 do
		local layer = if i % 2 == 0 then palette.felt else palette.pulp
		kit.part(model, Vector3.new(2.6, 0.2, 1.9), CFrame.new(0, 1.5 + i * 0.2, 0), layer, "Layer")
	end
	kit.cylinder(model, 6, 0.3, CFrame.new(0, 5.2, 0) * CFrame.Angles(0, math.rad(35), 0), palette.oak_light, "Bar")
	finish(kit, model, Vector3.new(5.6, 8.5, 2.6), Vector3.new(0, 4.25, 0))
end

-- note: water-driven stampers that beat rags to pulp: a trough, four hammers in a frame and a turning cam shaft; a wall piece
-- note: the CamShaft model is tagged Waterwheel; its pivot's local z runs along the shaft, so Waterwheels turns it
local function makeStampers(kit, palette, folder: Instance)
	local model = kit.model(folder, "Stampers", CFrame.new())
	local length = 9
	kit.part(model, Vector3.new(length, 2.2, 2.4), CFrame.new(0, 1.1, 2.6), palette.oak, "Trough")
	kit.part(model, Vector3.new(length - 0.6, 0.15, 1.8), CFrame.new(0, 2.15, 2.6), palette.pulp, "Pulp")
	for _, x in { -length / 2 + 0.3, length / 2 - 0.3 } do
		kit.part(model, Vector3.new(0.6, 8.5, 0.6), CFrame.new(x, 4.25, 2.6), palette.oak, "Upright")
	end
	for _, y in { 5.2, 8.2 } do
		kit.part(model, Vector3.new(length, 0.5, 0.5), CFrame.new(0, y, 2.6), palette.oak, "Guide")
	end
	for i = 0, 3 do
		local x = -length / 2 + 1.4 + i * 2.05
		kit.part(model, Vector3.new(0.8, 6, 0.8), CFrame.new(x, 2.4 + 3 + (i % 2) * 0.6, 2.6), palette.oak_light, "Stamper")
		kit.part(model, Vector3.new(0.9, 0.5, 0.9), CFrame.new(x, 2.6 + (i % 2) * 0.6, 2.6), palette.iron, "Shoe")
		kit.part(model, Vector3.new(0.3, 0.3, 0.9), CFrame.new(x, 6 + (i % 2) * 0.6, 2), palette.oak, "Tappet")
	end

	local shaft = kit.model(model, "CamShaft", CFrame.new(0, 6, 0.9) * CFrame.Angles(0, math.rad(90), 0))
	kit.cylinder(shaft, length + 1, 1, CFrame.new(0, 6, 0.9), palette.oak, "Shaft")
	for i = 0, 3 do
		local x = -length / 2 + 1.4 + i * 2.05
		local turn = CFrame.new(x, 6, 0.9) * CFrame.Angles(i * math.pi / 2, 0, 0)
		kit.part(shaft, Vector3.new(0.3, 1.8, 0.4), turn, palette.oak_light, "Cam")
	end
	shaft.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	kit.tag(shaft, "Waterwheel")
	finish(kit, model, Vector3.new(length, 8.5, 3.4), Vector3.new(0, 4.25, 2.2))
end

-- Build -------------------------------------------------------------------------

function furniture.build(kit, palette): Instance
	local folder = kit.prefabFolder()

	makeTable(kit, palette, folder, "Table", 6, 3.4, palette.oak_light)
	makeTable(kit, palette, folder, "TableLong", 12, 3.8, palette.oak_light)
	makeTable(kit, palette, folder, "TableSmall", 3.6, 3, palette.oak_light)
	makeRoundTable(kit, palette, folder)
	makeChair(kit, palette, folder)
	makeStool(kit, palette, folder)
	makeSettle(kit, palette, folder)
	makeArmchair(kit, palette, folder, "ArmchairRed", palette.wool_red)
	makeArmchair(kit, palette, folder, "ArmchairGreen", palette.wool_green)

	makeBed(kit, palette, folder, "Bed", 3.8, palette.wool_blue)
	makeBed(kit, palette, folder, "BedPatch", 3.8, palette.wool_red)
	makeBed(kit, palette, folder, "BedDouble", 5.6, palette.wool_green)
	makeChest(kit, palette, folder)
	makeDresser(kit, palette, folder)
	makeShelfUnit(kit, palette, folder, "ShelfUnit", 6, 8.4, 1.6, palette.oak)
	makeShelfUnit(kit, palette, folder, "ShelfLow", 6, 4.2, 1.6, palette.pine)
	makeDrawers(kit, palette, folder)
	makePigeonholes(kit, palette, folder)
	makeWallShelf(kit, palette, folder)

	makeFireplace(kit, palette, folder, 10)
	makeInglenook(kit, palette, folder, 13)
	makeStove(kit, palette, folder, 13)
	makeHangingLantern(kit, palette, folder, 2.4)
	makeSconce(kit, palette, folder)
	makeCandlestick(kit, palette, folder)

	makePicture(kit, palette, folder, "PictureSea", { rgb(176, 198, 214), rgb(70, 110, 146), rgb(214, 196, 150) })
	makePicture(kit, palette, folder, "PictureHills", { rgb(196, 210, 220), rgb(110, 140, 90), rgb(86, 110, 64) })
	makeChalkboard(kit, palette, folder)
	makeClock(kit, palette, folder)

	makeCounter(kit, palette, folder, "Counter", 10, palette.paint_green)
	makeCounter(kit, palette, folder, "CounterOak", 8, palette.oak)
	makeBarCounter(kit, palette, folder, 12)
	makeBackBar(kit, palette, folder, 10)
	makeStillage(kit, palette, folder)
	makeScales(kit, palette, folder)
	makeSweetJars(kit, palette, folder)
	makeTill(kit, palette, folder)

	makeTankard(kit, palette, folder)
	makePlate(kit, palette, folder)
	makeBowl(kit, palette, folder)
	makeJug(kit, palette, folder)
	makeBottle(kit, palette, folder, "TonicRed", { material = material.Glass, color = rgb(170, 46, 52), transparency = 0.2 })
	makeBottle(kit, palette, folder, "TonicGreen", palette.glass_green)
	makeBottle(kit, palette, folder, "TonicBlue", palette.glass_blue)
	makeJar(kit, palette, folder)
	makeTin(kit, palette, folder, "TinRed", palette.paint_oxblood)
	makeTin(kit, palette, folder, "TinBlue", palette.paint_navy)
	makeTin(kit, palette, folder, "TinGreen", palette.paint_sage)
	makeBooks(kit, palette, folder)
	makeKettle(kit, palette, folder)
	makeBucket(kit, palette, folder)
	makeBroom(kit, palette, folder)
	makeLoaf(kit, palette, folder)

	makePaperStack(kit, palette, folder)
	makeReam(kit, palette, folder)
	makePaperRoll(kit, palette, folder)
	makeSchematic(kit, palette, folder, "SchematicCrane", { { -1, -1, 1, 1 }, { -1, 1, 1, -1 }, { 0, -1, 0, 1 }, { -0.6, -1.25, 0.6, -1.25 } })
	makeSchematic(kit, palette, folder, "SchematicBoat", { { -1, 0, 1, 0 }, { -1, -1, 0, 1 }, { 0, 1, 1, -1 }, { -0.6, -1.25, 0.6, -1.25 } })
	makeSchematic(kit, palette, folder, "SchematicFox", { { -1, 1, 1, -1 }, { -1, 0.2, 0.2, 1 }, { -0.2, -1, 1, 0.2 }, { -0.6, -1.25, 0.6, -1.25 } })
	makeFoldingMat(kit, palette, folder)
	makeWorkbench(kit, palette, folder)
	makeDraftingDesk(kit, palette, folder)
	makeBookPress(kit, palette, folder)

	makeVat(kit, palette, folder)
	makeCouchingBench(kit, palette, folder)
	makeScrewPress(kit, palette, folder)
	makeStampers(kit, palette, folder)
	return folder
end

return furniture