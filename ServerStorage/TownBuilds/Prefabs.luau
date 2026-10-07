--!strict
--[[
	Prefabs
	What: rebuilds the architectural and outdoor prefabs into ServerStorage.Prefabs: windows, doors, chimneys, lamps, signs,
		street furniture, harbor gear, containers and garden pieces
	Used by: the studio assistant (edit mode); nothing requires it at runtime
	Needs: kit (BuildKit), palette (BuildPalette) and nature (TownBuilds.Nature), passed in because studio caches required modules
	Order: build() clears the folder first; Furniture.build() then adds the interior prefabs
	Frames: windows and doors pivot on the wall's centre line at the opening's centre, local z outward, sized for 1.6 stud walls;
		wall-mounted pieces pivot on the wall face with local z outward; standing pieces pivot on the ground and face +z
	Doors: tagged Door with Open and Swing attributes; each Leaf model turns on its Hinge part (DoorService, DoorController);
		a leaf's ClosedOffset is its hinge relative to the door's Head, which never moves
	Pivots: prefab models keep a WorldPivot and no PrimaryPart (a PrimaryPart moves the pivot onto that part when cloned)
	Tags: NightLight (lamp glass and lights that TownLights switches on at night)
]]

local rgb = Color3.fromRGB
local material = Enum.Material

type Style = { material: Enum.Material, color: Color3, variant: string?, transparency: number? }

local WALL = 1.6
local LAMP_COLOR = rgb(255, 194, 128)
local GILT = rgb(228, 206, 152)
local TERRACOTTA: Style = { material = material.Sandstone, color = rgb(170, 100, 72) }
local WATER: Style = { material = material.Glass, color = rgb(38, 56, 58), transparency = 0.15 }

local prefabs = {}

-- Helpers -------------------------------------------------------------------

local function label(part: BasePart, face: Enum.NormalId, text: string, color: Color3, font: Enum.Font): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 1

	local text_label = Instance.new("TextLabel")
	text_label.Name = "Label"
	text_label.BackgroundTransparency = 1
	text_label.Size = UDim2.fromScale(0.9, 0.8)
	text_label.Position = UDim2.fromScale(0.05, 0.1)
	text_label.Font = font
	text_label.TextScaled = true
	text_label.TextWrapped = true
	text_label.TextColor3 = color
	text_label.Text = text
	text_label.Parent = gui
	gui.Parent = part
	return gui
end

local function smoke(parent: BasePart)
	-- note: a thin wisp, kept to a low rate so a whole town stays cheap
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Smoke"
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(rgb(172, 168, 162))
	emitter.LightInfluence = 1
	emitter.Rate = 1.5
	emitter.Lifetime = NumberRange.new(6, 9)
	emitter.Speed = NumberRange.new(2, 3)
	emitter.SpreadAngle = Vector2.new(8, 8)
	emitter.Acceleration = Vector3.new(0.8, 0.3, 0.4)
	emitter.RotSpeed = NumberRange.new(-10, 10)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 7) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(0.3, 0.8), NumberSequenceKeypoint.new(1, 1) })
	emitter.Parent = parent
end

-- note: a four-sided lantern standing on base (its bottom centre); the glass glows and the light comes on at night
local function lantern(kit, palette, parent: Instance, base: CFrame, range: number)
	kit.part(parent, Vector3.new(1.3, 0.16, 1.3), base * CFrame.new(0, 0.08, 0), palette.iron, "Tray")
	local glow = kit.part(parent, Vector3.new(1, 1.4, 1), base * CFrame.new(0, 0.86, 0), palette.lamp_glass, "Glow")
	glow.CastShadow = false
	kit.tag(glow, "NightLight")

	for _, corner in { Vector2.new(-1, -1), Vector2.new(1, -1), Vector2.new(1, 1), Vector2.new(-1, 1) } do
		kit.part(parent, Vector3.new(0.1, 1.5, 0.1), base * CFrame.new(corner.X * 0.52, 0.9, corner.Y * 0.52), palette.iron, "Frame")
	end

	kit.part(parent, Vector3.new(1.5, 0.18, 1.5), base * CFrame.new(0, 1.65, 0), palette.iron, "Brim")
	kit.post(parent, 0.35, 1.1, base * CFrame.new(0, 1.74, 0), palette.iron, "Cap")
	kit.ball(parent, 0.3, base * CFrame.new(0, 2.2, 0), palette.iron, "Finial")

	-- note: the light casts shadows, so walls stop it and it never lights a room through them
	local light = Instance.new("PointLight")
	light.Color = LAMP_COLOR
	light.Range = range
	light.Brightness = 1.5
	light.Shadows = true
	light.Enabled = false
	light.Parent = glow
	kit.tag(light, "NightLight")
end

-- Windows -------------------------------------------------------------------

type WindowSpec = {
	w: number,
	h: number,
	cols: number,
	rows: number,
	frame: Style,
	lintel: Style,
	sill: Style,
	shutters: Style?,
}

local function makeWindow(kit, palette, folder: Instance, name: string, spec: WindowSpec)
	local model = kit.model(folder, name, CFrame.new())
	local w = spec.w
	local h = spec.h
	local f = 0.3
	local z = 0.3 -- note: the casement sits half a stud back from the outer face

	kit.part(model, Vector3.new(w, f, 0.34), CFrame.new(0, h / 2 - f / 2, z), spec.frame, "Head")
	kit.part(model, Vector3.new(w, f, 0.34), CFrame.new(0, -h / 2 + f / 2, z), spec.frame, "Foot")
	for _, side in { -1, 1 } do
		kit.part(model, Vector3.new(f, h - f * 2, 0.34), CFrame.new(side * (w / 2 - f / 2), 0, z), spec.frame, "Jamb")
	end

	local inner_w = w - f * 2
	local inner_h = h - f * 2
	local pane = kit.part(model, Vector3.new(inner_w, inner_h, 0.05), CFrame.new(0, 0, z), palette.glass, "Pane")
	pane.CastShadow = false
	pane.CanQuery = false

	for i = 1, spec.cols - 1 do
		local x = -inner_w / 2 + inner_w * i / spec.cols
		kit.detail(kit.part(model, Vector3.new(0.12, inner_h, 0.16), CFrame.new(x, 0, z), spec.frame, "Bar"))
	end

	for i = 1, spec.rows - 1 do
		local y = -inner_h / 2 + inner_h * i / spec.rows
		kit.detail(kit.part(model, Vector3.new(inner_w, 0.12, 0.16), CFrame.new(0, y, z), spec.frame, "Bar"))
	end

	-- note: a stone sill and lintel outside, an oak window board and lintel inside
	kit.part(model, Vector3.new(w + 0.8, 0.35, 1), CFrame.new(0, -h / 2 - 0.145, 0.75), spec.sill, "Sill")
	kit.part(model, Vector3.new(w + 1.2, 0.7, 0.25), CFrame.new(0, h / 2 + 0.33, 0.825), spec.lintel, "Lintel")
	kit.part(model, Vector3.new(w + 0.3, 0.14, 1.05), CFrame.new(0, -h / 2 - 0.03, -0.425), palette.oak_light, "Board")
	kit.part(model, Vector3.new(w + 0.6, 0.45, 0.2), CFrame.new(0, h / 2 + 0.2, -0.85), palette.timber, "InnerLintel")

	local shutters = spec.shutters
	if shutters then
		for _, side in { -1, 1 } do
			local leaf = CFrame.new(side * (w * 0.75 + 0.2), 0, WALL / 2 + 0.1)
			kit.part(model, Vector3.new(w / 2, h, 0.16), leaf, shutters, "Shutter")
			for _, y in { h / 2 - 0.9, -h / 2 + 0.9 } do
				kit.detail(kit.part(model, Vector3.new(w / 2 - 0.3, 0.3, 0.08), leaf * CFrame.new(0, y, 0.11), shutters, "Ledge"))
			end

			local rise = h - 1.8
			local run = w / 2 - 0.6
			local brace = math.sqrt(rise * rise + run * run)
			local tilt = side * math.atan2(rise, run)
			kit.detail(kit.part(model, Vector3.new(brace, 0.26, 0.07), leaf * CFrame.new(0, 0, 0.11) * CFrame.Angles(0, 0, tilt), shutters, "Brace"))
			kit.detail(kit.part(model, Vector3.new(0.14, 0.14, 0.35), CFrame.new(side * (w + 0.35), -0.6, WALL / 2 + 0.15), palette.iron, "Catch"))
		end
	end

	model:SetAttribute("Width", w)
	model:SetAttribute("Height", h)
end

-- note: a drying-loft vent; open slats air the paper loft and still shed the rain outward
local function makeLouvre(kit, palette, folder: Instance, name: string, w: number, h: number)
	local model = kit.model(folder, name, CFrame.new())
	local f = 0.3
	local z = 0.25
	kit.part(model, Vector3.new(w, f, 0.4), CFrame.new(0, h / 2 - f / 2, z), palette.timber, "Head")
	kit.part(model, Vector3.new(w, f, 0.4), CFrame.new(0, -h / 2 + f / 2, z), palette.timber, "Foot")
	for _, side in { -1, 1 } do
		kit.part(model, Vector3.new(f, h - f * 2, 0.4), CFrame.new(side * (w / 2 - f / 2), 0, z), palette.timber, "Jamb")
	end

	local slats = math.floor((h - f * 2) / 0.55)
	for i = 0, slats - 1 do
		local y = -h / 2 + f + 0.3 + i * 0.55
		kit.part(model, Vector3.new(w - f * 2, 0.08, 0.7), CFrame.new(0, y, z) * CFrame.Angles(math.rad(40), 0, 0), palette.timber, "Slat")
	end

	kit.part(model, Vector3.new(w + 0.6, 0.25, 0.8), CFrame.new(0, -h / 2 - 0.1, 0.75), palette.timber, "Sill")
	model:SetAttribute("Width", w)
	model:SetAttribute("Height", h)
end

-- note: a shop window projecting past the wall: panelled stall riser, small panes, a fascia and a display board inside
local function makeShopWindow(kit, palette, folder: Instance, name: string, w: number, h: number, paint: Style)
	local model = kit.model(folder, name, CFrame.new())
	local face = WALL / 2
	local reach = 1 -- note: how far it projects past the wall face
	local riser = 1.9
	local bottom = -h / 2
	local fascia = 0.9
	local glass_bottom = bottom + riser + 0.2
	local glass_h = h / 2 - fascia - glass_bottom
	local glass_y = glass_bottom + glass_h / 2
	local front_z = face + reach - 0.15

	kit.part(model, Vector3.new(w, riser, WALL + reach), CFrame.new(0, bottom + riser / 2, reach / 2), paint, "Riser")
	for _, x in { -w / 4, w / 4 } do
		kit.detail(kit.part(model, Vector3.new(w / 2 - 0.8, riser - 0.7, 0.1), CFrame.new(x, bottom + riser / 2, face + reach + 0.05), paint, "RiserPanel"), true)
	end

	kit.part(model, Vector3.new(w + 0.3, 0.2, WALL + reach + 0.3), CFrame.new(0, bottom + riser + 0.1, (reach + 0.3) / 2), palette.oak_light, "Stallboard")

	for _, side in { -1, 1 } do
		kit.part(model, Vector3.new(0.3, glass_h, 0.3), CFrame.new(side * (w / 2 - 0.15), glass_y, front_z), paint, "Post")
		local return_pane = kit.part(model, Vector3.new(0.05, glass_h, reach - 0.3), CFrame.new(side * (w / 2 - 0.15), glass_y, face + (reach - 0.3) / 2), palette.glass, "Pane")
		return_pane.CastShadow = false
		return_pane.CanQuery = false
	end

	local front = kit.part(model, Vector3.new(w - 0.6, glass_h, 0.05), CFrame.new(0, glass_y, front_z), palette.glass, "Pane")
	front.CastShadow = false
	front.CanQuery = false

	local cols = 5
	local rows = 3
	for i = 1, cols - 1 do
		local x = -(w - 0.6) / 2 + (w - 0.6) * i / cols
		kit.detail(kit.part(model, Vector3.new(0.12, glass_h, 0.16), CFrame.new(x, glass_y, front_z), paint, "Bar"))
	end

	for i = 1, rows - 1 do
		local y = glass_bottom + glass_h * i / rows
		kit.detail(kit.part(model, Vector3.new(w - 0.6, 0.12, 0.16), CFrame.new(0, y, front_z), paint, "Bar"))
	end

	kit.part(model, Vector3.new(w + 0.4, fascia, WALL + reach + 0.1), CFrame.new(0, h / 2 - fascia / 2, (reach + 0.1) / 2), paint, "Fascia")
	kit.part(model, Vector3.new(w + 0.8, 0.25, WALL + reach + 0.5), CFrame.new(0, h / 2 + 0.12, (reach + 0.5) / 2), palette.lead, "Cornice")
	model:SetAttribute("Width", w)
	model:SetAttribute("Height", h)
end

-- Doors ---------------------------------------------------------------------

type DoorSpec = {
	w: number,
	h: number,
	leaves: number,
	leaf: Style,
	frame: Style,
	wall: number, -- note: thickness of the wall the door fits
	leaf_z: number, -- note: where the leaf hangs within the wall, along local z
	transom: number?, -- note: height of a glazed fanlight above the leaf
	surround: Style?,
	step: Style?,
	knocker: boolean?,
}

local function makeDoor(kit, palette, folder: Instance, name: string, spec: DoorSpec)
	local model = kit.model(folder, name, CFrame.new())
	local w = spec.w
	local h = spec.h
	local f = 0.3
	local depth = spec.wall + 0.1

	local head = kit.part(model, Vector3.new(w, f, depth), CFrame.new(0, h / 2 - f / 2, 0), spec.frame, "Head")
	for _, side in { -1, 1 } do
		kit.part(model, Vector3.new(f, h - f, depth), CFrame.new(side * (w / 2 - f / 2), -f / 2, 0), spec.frame, "Jamb")
	end

	local leaf_top = h / 2 - f
	local transom = spec.transom
	if transom then
		leaf_top -= transom
		kit.part(model, Vector3.new(w - f * 2, 0.3, 0.4), CFrame.new(0, leaf_top + 0.15, spec.leaf_z), spec.frame, "TransomRail")

		local light_h = transom - 0.3
		local light_y = leaf_top + 0.3 + light_h / 2
		local pane = kit.part(model, Vector3.new(w - f * 2, light_h, 0.05), CFrame.new(0, light_y, spec.leaf_z), palette.glass, "Pane")
		pane.CastShadow = false
		pane.CanQuery = false
		for i = 1, 3 do
			local x = -(w - f * 2) / 2 + (w - f * 2) * i / 4
			kit.detail(kit.part(model, Vector3.new(0.12, light_h, 0.14), CFrame.new(x, light_y, spec.leaf_z), spec.frame, "Bar"))
		end
	end

	local bottom = -h / 2 + 0.05
	local leaf_h = leaf_top - 0.03 - bottom
	local leaf_y = bottom + leaf_h / 2
	local leaf_w = (w - f * 2) / spec.leaves
	local half = 0.17
	local outer = spec.leaf_z + half
	local inner = spec.leaf_z - half
	local ledges = { leaf_y + leaf_h / 2 - 1.1, leaf_y, leaf_y - leaf_h / 2 + 1.2 }

	for i = 1, spec.leaves do
		-- note: hand 1 hangs on the left jamb seen from outside, -1 on the right
		local hand = if i == 1 then 1 else -1
		local edge = -hand * (w / 2 - f)
		local leaf = kit.model(model, "Leaf")
		local hinge = kit.part(leaf, Vector3.new(0.2, 0.2, 0.2), CFrame.new(edge + hand * half, leaf_y, spec.leaf_z), palette.iron, "Hinge")
		hinge.Transparency = 1
		kit.detail(hinge)
		leaf.PrimaryPart = hinge
		leaf:SetAttribute("Hand", hand)
		leaf:SetAttribute("ClosedOffset", head.CFrame:ToObjectSpace(hinge.CFrame))

		-- note: the panel lies on its side so the plank texture runs upright
		local centre_x = edge + hand * leaf_w / 2
		kit.part(leaf, Vector3.new(leaf_h, leaf_w - 0.08, half * 2), CFrame.new(centre_x, leaf_y, spec.leaf_z) * CFrame.Angles(0, 0, math.rad(90)), spec.leaf, "Panel")

		local strap = leaf_w * 0.72
		for _, y in { ledges[1], ledges[3] } do
			kit.detail(kit.part(leaf, Vector3.new(strap, 0.22, 0.06), CFrame.new(edge + hand * (strap / 2 + 0.1), y, outer + 0.03), palette.iron, "Strap"))
		end

		local latch_x = edge + hand * (leaf_w - 0.55)
		local latch_y = -h / 2 + 4.1
		kit.detail(kit.part(leaf, Vector3.new(0.32, 0.6, 0.05), CFrame.new(latch_x, latch_y, outer + 0.025), palette.iron, "LatchPlate"))
		kit.detail(kit.cylinder(leaf, 0.06, 0.55, CFrame.new(latch_x, latch_y - 0.2, outer + 0.08) * CFrame.Angles(0, math.rad(90), 0), palette.iron, "Ring"))
		kit.detail(kit.part(leaf, Vector3.new(0.9, 0.12, 0.1), CFrame.new(latch_x - hand * 0.3, latch_y, inner - 0.05), palette.iron, "Latch"))

		-- note: ledges and a z brace on the inside face
		for _, y in ledges do
			kit.detail(kit.part(leaf, Vector3.new(leaf_w - 0.5, 0.45, 0.1), CFrame.new(centre_x, y, inner - 0.05), spec.leaf, "Ledge"))
		end

		for k = 1, 2 do
			local low = ledges[k + 1]
			local high = ledges[k]
			local run = leaf_w - 1.2
			local rise = high - low
			local length = math.sqrt(run * run + rise * rise)
			local tilt = hand * math.atan2(rise, run)
			kit.detail(kit.part(leaf, Vector3.new(length, 0.35, 0.08), CFrame.new(centre_x, (low + high) / 2, inner - 0.04) * CFrame.Angles(0, 0, tilt), spec.leaf, "Brace"))
		end

		if spec.knocker and i == 1 then
			kit.detail(kit.part(leaf, Vector3.new(0.5, 0.7, 0.06), CFrame.new(centre_x, -h / 2 + 5.6, outer + 0.03), palette.brass, "KnockerPlate"))
			kit.detail(kit.cylinder(leaf, 0.08, 0.75, CFrame.new(centre_x, -h / 2 + 5.3, outer + 0.1) * CFrame.Angles(0, math.rad(90), 0), palette.brass, "Knocker"))
		end
	end

	local surround = spec.surround
	if surround then
		local face = spec.wall / 2
		kit.part(model, Vector3.new(w + 1.6, 0.8, 0.24), CFrame.new(0, h / 2 + 0.38, face + 0.06), surround, "Lintel")
		kit.part(model, Vector3.new(0.9, 1.1, 0.34), CFrame.new(0, h / 2 + 0.45, face + 0.1), surround, "Keystone")

		local course = 1.2
		local count = math.floor(h / course)
		for _, side in { -1, 1 } do
			for c = 0, count - 1 do
				local block = if c % 2 == 0 then 1.3 else 0.8
				local x = side * (w / 2 + block / 2 - 0.05)
				local y = -h / 2 + c * course + course / 2
				kit.part(model, Vector3.new(block, course - 0.08, 0.2), CFrame.new(x, y, face + 0.04), surround, "JambStone")
			end
		end
	end

	local step = spec.step
	if step then
		local top = -h / 2 - 0.35
		kit.part(model, Vector3.new(w + 1.2, 1.6, 1.8), CFrame.new(0, top - 0.8, spec.wall / 2 + 1.4), step, "Step")
	end

	-- note: the prompt sits in the frame's head, which never moves, at about chest height
	local attachment = Instance.new("Attachment")
	attachment.Name = "PromptAttachment"
	attachment.Position = Vector3.new(0, 4.2 - h + f / 2, 0)
	attachment.Parent = head

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = attachment

	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("Open", false)
	model:SetAttribute("Swing", 1)
	model:SetAttribute("Width", w)
	model:SetAttribute("Height", h)
	kit.tag(model, "Door")
end

-- Chimneys ------------------------------------------------------------------

-- note: a stack top with an oversailing course and clay pots; pivot at the stack's base, sunk into the roof
local function makeChimney(kit, palette, folder: Instance, name: string, body: Style, pots: { number })
	local model = kit.model(folder, name, CFrame.new())
	kit.part(model, Vector3.new(3.4, 7, 2.8), CFrame.new(0, 3.5, 0), body, "Stack")
	kit.part(model, Vector3.new(3.9, 0.45, 3.3), CFrame.new(0, 6.5, 0), palette.dressed_stone, "Oversail")
	kit.part(model, Vector3.new(3.6, 0.45, 3), CFrame.new(0, 7.1, 0), body, "Cap")

	for i, height in pots do
		local x = (i - (#pots + 1) / 2) * 1.2
		kit.post(model, height, 0.8, CFrame.new(x, 7.3, 0), TERRACOTTA, "Pot")
		kit.detail(kit.post(model, 0.2, 0.95, CFrame.new(x, 7.1 + height, 0), TERRACOTTA, "Rim"))
	end

	local first_x = (1 - (#pots + 1) / 2) * 1.2
	local vent = kit.part(model, Vector3.new(0.4, 0.2, 0.4), CFrame.new(first_x, 7.5 + pots[1], 0), TERRACOTTA, "Vent")
	vent.Transparency = 1
	kit.detail(vent)
	smoke(vent)
end

-- Lamps and signs -----------------------------------------------------------

local function makeLampPost(kit, palette, folder: Instance)
	local model = kit.model(folder, "LampPost", CFrame.new())
	kit.post(model, 0.5, 1.3, CFrame.new(), palette.iron, "Base")
	kit.post(model, 1.2, 0.85, CFrame.new(0, 0.5, 0), palette.iron, "Foot")
	kit.post(model, 7.6, 0.42, CFrame.new(0, 1.6, 0), palette.iron, "Shaft")
	for _, y in { 1.7, 5.5, 8.9 } do
		kit.detail(kit.post(model, 0.22, 0.62, CFrame.new(0, y, 0), palette.iron, "Collar"))
	end

	kit.detail(kit.part(model, Vector3.new(1.8, 0.12, 0.12), CFrame.new(0, 8.6, 0), palette.iron, "LadderBar"))
	kit.post(model, 0.3, 0.7, CFrame.new(0, 9.1, 0), palette.iron, "Seat")
	lantern(kit, palette, model, CFrame.new(0, 9.4, 0), 26)

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "Shaft" and part.Name ~= "Base" and part.Name ~= "Foot" then
			kit.detail(part)
		end
	end
end

-- note: pivot on the wall face; an iron bracket holds a hanging lantern out along +z
local function makeWallLantern(kit, palette, folder: Instance)
	local model = kit.model(folder, "WallLantern", CFrame.new())
	kit.part(model, Vector3.new(0.5, 1.2, 0.12), CFrame.new(0, 0.3, 0.06), palette.iron, "Plate")
	kit.part(model, Vector3.new(0.14, 0.14, 1.6), CFrame.new(0, 0.75, 0.8), palette.iron, "Arm")
	kit.part(model, Vector3.new(0.1, 0.1, 1.25), CFrame.new(0, 0.28, 0.55) * CFrame.Angles(math.rad(-40), 0, 0), palette.iron, "Brace")
	kit.ball(model, 0.28, CFrame.new(0, 0.75, 1.62), palette.iron, "Scroll")
	kit.part(model, Vector3.new(0.08, 0.3, 0.08), CFrame.new(0, 0.55, 1.45), palette.iron, "Drop")
	lantern(kit, palette, model, CFrame.new(0, -2, 1.45), 16)
	kit.detail(model)
end

-- note: pivot on the wall face; a scrolled bracket holds a framed board out along +z; set the text on both Label objects
local function makeHangingSign(kit, palette, folder: Instance)
	local model = kit.model(folder, "HangingSign", CFrame.new())
	kit.part(model, Vector3.new(0.6, 1.8, 0.12), CFrame.new(0, -0.5, 0.06), palette.iron, "Plate")
	kit.part(model, Vector3.new(0.2, 0.2, 4.6), CFrame.new(0, 0, 2.3), palette.iron, "Arm")
	kit.part(model, Vector3.new(0.12, 0.12, 2.42), CFrame.new(0, -0.6, 1.15) * CFrame.Angles(math.rad(-29.7), 0, 0), palette.iron, "Brace")
	kit.ball(model, 0.4, CFrame.new(0, 0, 4.65), palette.iron, "Scroll")
	for _, z in { 1.3, 3.5 } do
		kit.part(model, Vector3.new(0.06, 0.6, 0.06), CFrame.new(0, -0.35, z), palette.iron, "Chain")
	end

	local board = kit.part(model, Vector3.new(0.28, 2.4, 3.6), CFrame.new(0, -1.95, 2.4), palette.paint_green, "Board")
	for _, y in { -0.78, -3.12 } do
		kit.part(model, Vector3.new(0.34, 0.16, 3.6), CFrame.new(0, y, 2.4), palette.brass, "Trim")
	end
	for _, z in { 0.68, 4.12 } do
		kit.part(model, Vector3.new(0.34, 2.4, 0.16), CFrame.new(0, -1.95, z), palette.brass, "Trim")
	end

	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		label(board, face, "Sign", GILT, Enum.Font.Fondamento)
	end
	kit.detail(model)
end

-- note: an oak fingerpost; each Arm model carries a Label on both faces and turns about the post (set by the caller)
local function makeFingerpost(kit, palette, folder: Instance)
	local model = kit.model(folder, "Fingerpost", CFrame.new())
	kit.part(model, Vector3.new(0.5, 8.4, 0.5), CFrame.new(0, 4.2, 0), palette.frame_white, "Post")
	kit.ball(model, 0.75, CFrame.new(0, 8.6, 0), palette.frame_white, "Finial")
	kit.detail(kit.post(model, 0.25, 0.65, CFrame.new(0, 8.1, 0), palette.ink, "Collar"))

	for index, y in { 7.3, 6.3 } do
		local arm = kit.model(model, "Arm" .. index, CFrame.new(0, y, 0))
		local board = kit.part(arm, Vector3.new(4.4, 0.75, 0.18), CFrame.new(2.45, y, 0), palette.frame_white, "Board")
		kit.part(arm, Vector3.new(0.53, 0.53, 0.18), CFrame.new(4.65, y, 0) * CFrame.Angles(0, 0, math.rad(45)), palette.frame_white, "Tip")
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			label(board, face, "", palette.ink.color, Enum.Font.Merriweather)
		end
		kit.detail(arm, true)
	end
end

-- Street furniture ----------------------------------------------------------

-- note: oak slats on cast iron ends; the back is at -z and the sitter faces +z
local function makeBench(kit, palette, folder: Instance)
	local model = kit.model(folder, "Bench", CFrame.new())
	for _, z in { 0.55, 0.05, -0.45 } do
		kit.part(model, Vector3.new(6, 0.18, 0.44), CFrame.new(0, 1.85, z), palette.oak, "Slat")
	end

	for index, y in { 2.6, 3.2 } do
		kit.part(model, Vector3.new(6, 0.4, 0.14), CFrame.new(0, y, -0.82 - index * 0.08) * CFrame.Angles(math.rad(10), 0, 0), palette.oak, "BackSlat")
	end

	for _, x in { -2.7, 2.7 } do
		kit.part(model, Vector3.new(0.2, 1.8, 0.2), CFrame.new(x, 0.9, 0.6), palette.iron, "Leg")
		kit.part(model, Vector3.new(0.2, 3.5, 0.2), CFrame.new(x, 1.75, -0.82) * CFrame.Angles(math.rad(8), 0, 0), palette.iron, "Upright")
		kit.part(model, Vector3.new(0.2, 0.2, 1.6), CFrame.new(x, 1.72, -0.05), palette.iron, "Rail")
		kit.part(model, Vector3.new(0.22, 0.16, 1.5), CFrame.new(x, 2.55, 0.05), palette.iron, "Arm")
		kit.part(model, Vector3.new(0.18, 0.72, 0.18), CFrame.new(x, 2.2, 0.62), palette.iron, "ArmPost")
	end

	kit.detail(model, true)
	kit.collider(model, Vector3.new(6, 2, 1.9), CFrame.new(0, 1, -0.1))
end

-- note: a staved half barrel of cottage flowers
local function makeFlowerTub(kit, palette, nature, folder: Instance)
	local model = kit.model(folder, "FlowerTub", CFrame.new())
	kit.post(model, 1.5, 2.8, CFrame.new(), palette.oak, "Tub")
	for _, y in { 0.3, 1.15 } do
		kit.post(model, 0.14, 2.9, CFrame.new(0, y, 0), palette.iron, "Hoop")
	end

	kit.post(model, 0.1, 2.5, CFrame.new(0, 1.42, 0), palette.soil, "Soil")
	nature.flowers(kit, palette, model, CFrame.new(0, 1.5, 0), Random.new(5), 4, Vector2.new(0.7, 0.7), 1)
	kit.detail(model, true)
	kit.collider(model, Vector3.new(2.8, 1.5, 2.8), CFrame.new(0, 0.75, 0))
end

-- note: a painted planter on iron brackets; pivot on the wall face just under a sill, the box out along +z
local function makeWindowBox(kit, palette, nature, folder: Instance)
	local model = kit.model(folder, "WindowBox", CFrame.new())
	kit.part(model, Vector3.new(4.6, 0.8, 0.9), CFrame.new(0, -0.45, 0.5), palette.paint_sage, "Box")
	kit.part(model, Vector3.new(4.4, 0.2, 0.7), CFrame.new(0, -0.1, 0.5), palette.soil, "Soil")
	for _, x in { -1.6, 1.6 } do
		kit.part(model, Vector3.new(0.12, 0.7, 0.8), CFrame.new(x, -1.05, 0.45), palette.iron, "Bracket")
	end

	nature.flowers(kit, palette, model, CFrame.new(0, -0.05, 0.5), Random.new(11), 5, Vector2.new(1.7, 0.2), 0.6)
	for i = 0, 3 do
		kit.ellipsoid(model, Vector3.new(0.9, 1.3, 0.4), CFrame.new(-1.8 + i * 1.2, -0.75, 1), palette.leaf_dark, "Trail")
	end
	kit.detail(model)
end

-- note: a covered well: rubble drum with dressed coping, oak frame, shingled roof, windlass and bucket
local function makeWell(kit, palette, folder: Instance)
	local model = kit.model(folder, "Well", CFrame.new())
	local radius = 2.6
	local stones = 12
	for i = 0, stones - 1 do
		local turn = CFrame.Angles(0, i / stones * math.pi * 2, 0)
		kit.part(model, Vector3.new(1.5, 2.6, 1.1), turn * CFrame.new(0, 1.3, radius), palette.rubble, "Stone")
		kit.part(model, Vector3.new(1.55, 0.35, 1.4), turn * CFrame.new(0, 2.75, radius + 0.05), palette.dressed_stone, "Coping")
	end

	kit.post(model, 0.2, radius * 2 - 0.4, CFrame.new(0, 0.8, 0), WATER, "Water")
	for _, x in { -radius - 0.2, radius + 0.2 } do
		kit.part(model, Vector3.new(0.5, 6.6, 0.5), CFrame.new(x, 3.3, 0), palette.oak, "Post")
	end

	kit.cylinder(model, radius * 2 + 1, 0.55, CFrame.new(0, 4.6, 0), palette.oak, "Windlass")
	kit.part(model, Vector3.new(0.15, 1, 0.15), CFrame.new(radius + 0.75, 4.2, 0), palette.iron, "Crank")
	kit.cylinder(model, 0.6, 0.16, CFrame.new(radius + 1, 3.75, 0), palette.oak, "Handle")
	kit.part(model, Vector3.new(0.08, 1.9, 0.08), CFrame.new(0, 3.4, 0), palette.rope, "Rope")
	kit.post(model, 0.9, 0.9, CFrame.new(0, 1.55, 0), palette.oak, "Bucket")
	kit.post(model, 0.12, 0.95, CFrame.new(0, 2.2, 0), palette.iron, "Band")

	local angle = math.rad(35)
	for _, side in { -1, 1 } do
		kit.part(model, Vector3.new(7.6, 0.3, 3.4), CFrame.new(0, 7.3, side * 1.3) * CFrame.Angles(side * angle, 0, 0), palette.slate_roof, "Roof")
	end
	kit.part(model, Vector3.new(7.8, 0.45, 0.45), CFrame.new(0, 8.25, 0) * CFrame.Angles(math.rad(45), 0, 0), palette.ridge_tile, "Ridge")

	kit.detail(model, true)
	kit.collider(model, Vector3.new(radius * 2 + 1.2, 3, radius * 2 + 1.2), CFrame.new(0, 1.5, 0))
end

-- note: the quest board, a roofed oak frame with pinned notices; pivot on the ground, the notices face +z
local function makeNoticeBoard(kit, palette, folder: Instance)
	local model = kit.model(folder, "NoticeBoard", CFrame.new())
	for _, x in { -3, 3 } do
		kit.part(model, Vector3.new(0.55, 8.2, 0.55), CFrame.new(x, 4.1, 0), palette.timber, "Post")
	end

	kit.part(model, Vector3.new(5.5, 3.8, 0.3), CFrame.new(0, 4.6, 0), palette.boards, "Board")
	for _, y in { 6.6, 2.6 } do
		kit.part(model, Vector3.new(6, 0.3, 0.45), CFrame.new(0, y, 0), palette.timber, "Rail")
	end
	kit.part(model, Vector3.new(5.5, 0.15, 0.6), CFrame.new(0, 2.8, 0.35), palette.timber, "Ledge")

	local random = Random.new(3)
	for i = 0, 6 do
		local x = -2.1 + (i % 4) * 1.4 + random:NextNumber(-0.2, 0.2)
		local y = if i < 4 then 5.4 else 3.8
		local size = Vector3.new(random:NextNumber(0.9, 1.25), random:NextNumber(1.2, 1.6), 0.04)
		local tilt = math.rad(random:NextNumber(-8, 8))
		kit.part(model, size, CFrame.new(x + (if i >= 4 then 0.7 else 0), y + random:NextNumber(-0.3, 0.3), 0.18) * CFrame.Angles(0, 0, tilt), palette.paper, "Note")
	end

	local angle = math.rad(30)
	for _, side in { -1, 1 } do
		kit.part(model, Vector3.new(7.2, 0.25, 2.1), CFrame.new(0, 8.45, side * 0.85) * CFrame.Angles(side * angle, 0, 0), palette.slate_roof, "Roof")
		for _, x in { -3.55, 3.55 } do
			kit.part(model, Vector3.new(0.2, 0.5, 2.1), CFrame.new(x, 8.2, side * 0.85) * CFrame.Angles(side * angle, 0, 0), palette.timber, "Bargeboard")
		end
	end
	kit.part(model, Vector3.new(7.3, 0.4, 0.4), CFrame.new(0, 9.05, 0) * CFrame.Angles(math.rad(45), 0, 0), palette.ridge_tile, "Ridge")

	kit.detail(model, true)
	kit.collider(model, Vector3.new(6.6, 8.2, 0.8), CFrame.new(0, 4.1, 0))
end

-- Harbor --------------------------------------------------------------------

-- note: pivot at the waterline in the hull centre, bow toward -z
local function makeRowboat(kit, palette, folder: Instance, name: string, hull: Style, strake: Style)
	local model = kit.model(folder, name, CFrame.new())
	kit.part(model, Vector3.new(2.6, 0.3, 9.6), CFrame.new(0, -0.55, 0.4), palette.wet_wood, "Bottom")

	for _, side in { -1, 1 } do
		local plank = CFrame.new(side * 1.55, 0.1, 0.4) * CFrame.Angles(0, 0, math.rad(side * -16))
		kit.part(model, Vector3.new(0.25, 1.5, 9.6), plank, hull, "Side")
		kit.part(model, Vector3.new(0.35, 0.2, 9.6), plank * CFrame.new(0, 0.82, 0), palette.oak, "Gunwale")
		kit.part(model, Vector3.new(0.06, 0.32, 9.4), plank * CFrame.new(side * 0.15, 0.48, 0), strake, "Strake")
		for _, z in { -3, 0, 3 } do
			kit.part(model, Vector3.new(0.14, 1.3, 0.22), plank * CFrame.new(-side * 0.18, 0, z), palette.oak, "Rib")
		end

		-- note: the two bow planks angle in to meet at the stem
		local bow = CFrame.new(side * 0.85, 0.1, -5.2) * CFrame.Angles(0, math.rad(side * 33), math.rad(side * -16))
		kit.part(model, Vector3.new(0.25, 1.5, 2.9), bow, hull, "Bow")
		kit.part(model, Vector3.new(0.06, 0.32, 2.8), bow * CFrame.new(side * 0.15, 0.48, 0), strake, "Strake")
	end

	kit.part(model, Vector3.new(3.4, 1.5, 0.3), CFrame.new(0, 0.1, 5.25), hull, "Transom")
	kit.part(model, Vector3.new(0.3, 1.9, 0.3), CFrame.new(0, 0.3, -6.35), palette.oak, "Stem")
	kit.cylinder(model, 0.1, 0.4, CFrame.new(0, 0.7, -6.55) * CFrame.Angles(0, math.rad(90), 0), palette.iron, "BowRing")
	for _, z in { -1, 3 } do
		kit.part(model, Vector3.new(2.9, 0.22, 1), CFrame.new(0, 0.15, z), palette.oak, "Thwart")
	end

	for _, side in { -1, 1 } do
		local oar = CFrame.new(side * 0.7, 0.35, 0.8) * CFrame.Angles(0, math.rad(side * 4), 0)
		kit.part(model, Vector3.new(0.18, 0.18, 7.5), oar, palette.oak_light, "Oar")
		kit.part(model, Vector3.new(0.5, 0.08, 1.6), oar * CFrame.new(0, 0, 3.2), palette.oak_light, "Blade")
	end

	kit.detail(model, true)
end

local function makeMooringPost(kit, palette, folder: Instance)
	local model = kit.model(folder, "MooringPost", CFrame.new())
	kit.post(model, 7, 1.1, CFrame.new(), palette.wet_wood, "Post")
	kit.detail(kit.post(model, 0.5, 1.22, CFrame.new(0, 5.4, 0), palette.rope, "Rope"))
end

local function makeBollard(kit, palette, folder: Instance)
	local model = kit.model(folder, "Bollard", CFrame.new())
	kit.post(model, 0.2, 1.4, CFrame.new(), palette.iron, "Foot")
	kit.post(model, 1.5, 0.9, CFrame.new(), palette.iron, "Body")
	kit.post(model, 0.25, 1.25, CFrame.new(0, 1.45, 0), palette.iron, "Cap")
end

-- note: a lobster pot: a net dome on a wooden base with a dark entrance
local function makeCrabPot(kit, palette, folder: Instance)
	local model = kit.model(folder, "CrabPot", CFrame.new())
	kit.part(model, Vector3.new(2.4, 0.2, 1.6), CFrame.new(0, 0.1, 0), palette.wet_wood, "Base")
	kit.ellipsoid(model, Vector3.new(2.3, 2.2, 1.5), CFrame.new(0, 0.2, 0), palette.net, "Net")
	for _, x in { -0.6, 0.6 } do
		kit.ellipsoid(model, Vector3.new(0.12, 2.25, 1.55), CFrame.new(x, 0.2, 0), palette.driftwood, "Hoop")
	end
	kit.ellipsoid(model, Vector3.new(0.6, 0.6, 0.1), CFrame.new(0, 0.7, -0.74), palette.soot, "Entrance")
	kit.detail(model, true)
end

local function makeBuoy(kit, palette, folder: Instance)
	local model = kit.model(folder, "Buoy", CFrame.new())
	kit.ball(model, 1.1, CFrame.new(0, 0.55, 0), palette.wool_red, "Float")
	kit.post(model, 0.2, 1.12, CFrame.new(0, 0.45, 0), palette.linen, "Band")
	kit.part(model, Vector3.new(0.08, 0.4, 0.08), CFrame.new(0, 1.25, 0), palette.rope, "Loop")
	kit.detail(model, true)
end

local function makeFishBox(kit, palette, folder: Instance)
	local model = kit.model(folder, "FishBox", CFrame.new())
	kit.part(model, Vector3.new(2.6, 0.14, 1.6), CFrame.new(0, 0.07, 0), palette.wet_wood, "Bottom")
	for _, side in { -1, 1 } do
		kit.part(model, Vector3.new(2.6, 0.8, 0.12), CFrame.new(0, 0.5, side * 0.74), palette.wet_wood, "Side")
		kit.part(model, Vector3.new(0.12, 0.8, 1.36), CFrame.new(side * 1.24, 0.5, 0), palette.wet_wood, "End")
	end
	kit.detail(model, true)
end

local function makeRopeCoil(kit, palette, folder: Instance)
	local model = kit.model(folder, "RopeCoil", CFrame.new())
	for i, diameter in { 1.7, 1.45, 1.15 } do
		kit.post(model, 0.2, diameter, CFrame.new(0, (i - 1) * 0.19, 0), palette.rope, "Turn")
	end
	kit.post(model, 0.2, 0.6, CFrame.new(0, 0.42, 0), palette.soot, "Eye")
	kit.detail(model)
end

-- note: two poles with a fishing net hung to dry and a row of cork floats
local function makeNetRack(kit, palette, folder: Instance)
	local model = kit.model(folder, "NetRack", CFrame.new())
	for _, x in { -3, 3 } do
		kit.part(model, Vector3.new(0.3, 6.2, 0.3), CFrame.new(x, 3.1, 0), palette.driftwood, "Pole")
	end
	kit.part(model, Vector3.new(6.6, 0.22, 0.22), CFrame.new(0, 5.9, 0), palette.driftwood, "Bar")

	local net = kit.part(model, Vector3.new(5.8, 4.4, 0.08), CFrame.new(0, 3.7, 0.12) * CFrame.Angles(math.rad(4), 0, 0), palette.net, "Net")
	net.Transparency = 0.2
	for i = 0, 5 do
		kit.ellipsoid(model, Vector3.new(0.5, 0.32, 0.32), CFrame.new(-2.5 + i, 5.6, 0.18), palette.oak_light, "Cork")
	end
	kit.detail(model, true)
end

local function makeAnchor(kit, palette, folder: Instance)
	local model = kit.model(folder, "Anchor", CFrame.new())
	local lean = CFrame.Angles(math.rad(-20), 0, 0)
	kit.part(model, Vector3.new(0.3, 3.4, 0.3), lean * CFrame.new(0, 1.7, 0), palette.iron, "Shank")
	kit.part(model, Vector3.new(2.4, 0.3, 0.3), lean * CFrame.new(0, 3.1, 0), palette.iron, "Stock")
	for _, side in { -1, 1 } do
		kit.part(model, Vector3.new(1.5, 0.28, 0.3), lean * CFrame.new(side * 0.6, 0.45, 0) * CFrame.Angles(0, 0, side * math.rad(35)), palette.iron, "Arm")
		kit.part(model, Vector3.new(0.5, 0.5, 0.32), lean * CFrame.new(side * 1.2, 0.9, 0) * CFrame.Angles(0, 0, math.rad(45)), palette.iron, "Fluke")
	end
	kit.cylinder(model, 0.14, 0.75, lean * CFrame.new(0, 3.6, 0) * CFrame.Angles(0, math.rad(90), 0), palette.iron, "Ring")
	kit.detail(model, true)
end

-- Containers ----------------------------------------------------------------

-- note: a bellied barrel built from three drums, iron hoops and a lid
local function makeBarrel(kit, palette, folder: Instance)
	local model = kit.model(folder, "Barrel", CFrame.new())
	kit.post(model, 1, 2.15, CFrame.new(), palette.oak, "Stave")
	kit.post(model, 1.4, 2.42, CFrame.new(0, 1, 0), palette.oak, "Stave")
	kit.post(model, 1, 2.15, CFrame.new(0, 2.4, 0), palette.oak, "Stave")
	for _, hoop in { { 0.35, 2.22 }, { 1.15, 2.47 }, { 2.25, 2.47 }, { 3.05, 2.22 } } do
		kit.post(model, 0.14, hoop[2], CFrame.new(0, hoop[1], 0), palette.iron, "Hoop")
	end
	kit.post(model, 0.08, 2, CFrame.new(0, 3.38, 0), palette.oak_light, "Lid")
	kit.detail(model, true)
	kit.collider(model, Vector3.new(2.4, 3.4, 2.4), CFrame.new(0, 1.7, 0))
end

local function makeCrate(kit, palette, folder: Instance)
	local model = kit.model(folder, "Crate", CFrame.new())
	kit.part(model, Vector3.new(2.5, 2.5, 2.5), CFrame.new(0, 1.25, 0), palette.pine, "Box")
	for _, corner in { Vector2.new(-1, -1), Vector2.new(1, -1), Vector2.new(1, 1), Vector2.new(-1, 1) } do
		kit.part(model, Vector3.new(0.3, 2.6, 0.3), CFrame.new(corner.X * 1.15, 1.3, corner.Y * 1.15), palette.oak, "Corner")
	end
	for _, y in { 0.2, 2.4 } do
		for _, side in { -1, 1 } do
			kit.part(model, Vector3.new(2.6, 0.3, 0.2), CFrame.new(0, y, side * 1.2), palette.oak, "Band")
			kit.part(model, Vector3.new(0.2, 0.3, 2.6), CFrame.new(side * 1.2, y, 0), palette.oak, "Band")
		end
	end
	kit.detail(model, true)
	kit.collider(model, Vector3.new(2.6, 2.6, 2.6), CFrame.new(0, 1.3, 0))
end

local function makeSack(kit, palette, folder: Instance, name: string, open: boolean)
	local model = kit.model(folder, name, CFrame.new())
	kit.ellipsoid(model, Vector3.new(1.9, 2.5, 1.5), CFrame.new(0, 1.15, 0), palette.hessian, "Body")
	if open then
		kit.post(model, 0.3, 1.45, CFrame.new(0, 2.05, 0), palette.hessian, "Rim")
		kit.post(model, 0.12, 1.3, CFrame.new(0, 2.25, 0), { material = material.Sand, color = rgb(214, 184, 120) }, "Grain")
	else
		kit.post(model, 0.35, 0.5, CFrame.new(0, 2.2, 0), palette.rope, "Tie")
		kit.ellipsoid(model, Vector3.new(0.9, 0.6, 0.7), CFrame.new(0, 2.65, 0), palette.hessian, "Tuft")
	end
	kit.detail(model, true)
end

local function makeBasket(kit, palette, folder: Instance)
	local model = kit.model(folder, "Basket", CFrame.new())
	local wicker = { material = material.WoodPlanks, color = rgb(176, 142, 92) }
	kit.post(model, 1, 1.8, CFrame.new(), wicker, "Body")
	kit.post(model, 0.16, 1.95, CFrame.new(0, 0.95, 0), palette.oak_light, "Rim")
	kit.part(model, Vector3.new(1.7, 0.14, 0.14), CFrame.new(0, 2, 0), palette.oak_light, "Handle")
	for _, x in { -0.82, 0.82 } do
		kit.part(model, Vector3.new(0.14, 1.1, 0.14), CFrame.new(x, 1.5, 0), palette.oak_light, "Handle")
	end
	kit.detail(model, true)
end

local function makeWaterButt(kit, palette, folder: Instance)
	local model = kit.model(folder, "WaterButt", CFrame.new())
	kit.post(model, 4.2, 2.6, CFrame.new(), palette.oak, "Body")
	for _, y in { 0.5, 2.1, 3.7 } do
		kit.post(model, 0.16, 2.7, CFrame.new(0, y, 0), palette.iron, "Hoop")
	end
	kit.post(model, 0.1, 2.5, CFrame.new(0, 4.2, 0), palette.oak_light, "Lid")
	kit.detail(model, true)
	kit.collider(model, Vector3.new(2.6, 4.3, 2.6), CFrame.new(0, 2.15, 0))
end

-- Garden --------------------------------------------------------------------

-- note: a picket garden gate between two posts, left standing ajar; pivot on the ground at the gateway's centre, facing -z
local function makeGate(kit, palette, folder: Instance)
	local model = kit.model(folder, "Gate", CFrame.new())
	for _, x in { -2.2, 2.2 } do
		kit.part(model, Vector3.new(0.5, 3.8, 0.5), CFrame.new(x, 1.9, 0), palette.oak, "Post")
		kit.part(model, Vector3.new(0.6, 0.2, 0.6), CFrame.new(x, 3.9, 0), palette.oak, "Cap")
	end

	local hinge = CFrame.new(-1.95, 0, 0) * CFrame.Angles(0, math.rad(-38), 0)
	for _, y in { 0.9, 2.3 } do
		kit.part(model, Vector3.new(3.9, 0.3, 0.14), hinge * CFrame.new(1.95, y, 0.12), palette.frame_white, "Rail")
	end
	for i = 0, 5 do
		local x = 0.3 + i * 0.66
		kit.part(model, Vector3.new(0.34, 2.7, 0.12), hinge * CFrame.new(x, 1.55, 0.24), palette.frame_white, "Picket")
		kit.part(model, Vector3.new(0.24, 0.24, 0.12), hinge * CFrame.new(x, 2.9, 0.24) * CFrame.Angles(0, 0, math.rad(45)), palette.frame_white, "Point")
	end
	kit.detail(model, true)
end

-- note: two posts and a line of drying paper sheets pegged on; pivot on the ground between the posts
local function makePaperLine(kit, palette, folder: Instance)
	local model = kit.model(folder, "PaperLine", CFrame.new())
	local span = 14
	for _, x in { -span / 2, span / 2 } do
		kit.part(model, Vector3.new(0.45, 6.6, 0.45), CFrame.new(x, 3.3, 0), palette.oak, "Post")
	end

	kit.part(model, Vector3.new(span, 0.07, 0.07), CFrame.new(0, 6.25, 0), palette.rope, "Line")
	for i = 0, 5 do
		local x = -span / 2 + 1.6 + i * 2.15
		local sway = math.rad((i % 2) * 6 - 3)
		kit.part(model, Vector3.new(1.7, 2.3, 0.04), CFrame.new(x, 5.07, 0) * CFrame.Angles(sway, 0, 0), palette.paper, "Sheet")
		kit.part(model, Vector3.new(0.12, 0.4, 0.14), CFrame.new(x, 6.2, 0), palette.oak_light, "Peg")
	end
	kit.detail(model, true)
end

-- Build -----------------------------------------------------------------------

function prefabs.build(kit, palette, nature): Instance
	local folder = kit.prefabFolder()
	folder:ClearAllChildren()

	local stone_window = { w = 4, h = 5.4, cols = 2, rows = 3, frame = palette.frame_white, lintel = palette.dressed_stone, sill = palette.dressed_stone }
	makeWindow(kit, palette, folder, "Window", stone_window)
	makeWindow(kit, palette, folder, "WindowWide", { w = 6, h = 5.4, cols = 3, rows = 3, frame = palette.frame_white, lintel = palette.dressed_stone, sill = palette.dressed_stone })
	makeWindow(kit, palette, folder, "WindowSmall", { w = 3, h = 3.4, cols = 2, rows = 2, frame = palette.frame_white, lintel = palette.timber, sill = palette.dressed_stone })
	makeWindow(kit, palette, folder, "WindowTimber", { w = 4, h = 5.4, cols = 2, rows = 3, frame = palette.frame_white, lintel = palette.timber, sill = palette.timber })
	for _, paint in { "sage", "navy", "teal", "oxblood" } do
		local shutters = palette["paint_" .. paint]
		local suffix = string.upper(string.sub(paint, 1, 1)) .. string.sub(paint, 2)
		makeWindow(kit, palette, folder, "WindowShuttered" .. suffix, { w = 4, h = 5.4, cols = 2, rows = 3, frame = palette.frame_white, lintel = palette.timber, sill = palette.dressed_stone, shutters = shutters })
	end
	makeLouvre(kit, palette, folder, "LouvreVent", 4, 5)
	makeShopWindow(kit, palette, folder, "ShopWindow", 9, 7.5, palette.paint_green)

	local cottage_door = { w = 5.6, h = 8.4, leaves = 1, frame = palette.oak, wall = WALL, leaf_z = 0.35, step = palette.dressed_stone }
	for _, paint in { "oak", "sage", "navy", "teal", "oxblood", "mustard" } do
		local spec = table.clone(cottage_door) :: any
		spec.leaf = if paint == "oak" then palette.oak else palette["paint_" .. paint]
		makeDoor(kit, palette, folder, "Door" .. string.upper(string.sub(paint, 1, 1)) .. string.sub(paint, 2), spec)
	end

	makeDoor(kit, palette, folder, "DoorInn", { w = 6, h = 10.2, leaves = 1, leaf = palette.paint_oxblood, frame = palette.timber, wall = WALL, leaf_z = 0.35, transom = 1.4, surround = palette.dressed_stone, step = palette.dressed_stone, knocker = true })
	makeDoor(kit, palette, folder, "DoorShop", { w = 6, h = 10.2, leaves = 1, leaf = palette.paint_green, frame = palette.paint_green, wall = WALL, leaf_z = 0.35, transom = 1.4, step = palette.dressed_stone, knocker = true })
	makeDoor(kit, palette, folder, "DoubleDoor", { w = 9.4, h = 10.4, leaves = 2, leaf = palette.oak, frame = palette.timber, wall = WALL, leaf_z = 0.35, surround = palette.dressed_stone, step = palette.dressed_stone })
	makeDoor(kit, palette, folder, "DoorInterior", { w = 4.8, h = 8, leaves = 1, leaf = palette.oak_light, frame = palette.oak, wall = 0.8, leaf_z = 0 })

	makeChimney(kit, palette, folder, "ChimneyBrick", palette.brick, { 1.5, 1.1 })
	makeChimney(kit, palette, folder, "ChimneyStone", palette.stone, { 1.3, 1.6, 1.1 })

	makeLampPost(kit, palette, folder)
	makeWallLantern(kit, palette, folder)
	makeHangingSign(kit, palette, folder)
	makeFingerpost(kit, palette, folder)
	makeBench(kit, palette, folder)
	makeFlowerTub(kit, palette, nature, folder)
	makeWindowBox(kit, palette, nature, folder)
	makeWell(kit, palette, folder)
	makeNoticeBoard(kit, palette, folder)

	makeRowboat(kit, palette, folder, "RowboatBlue", { material = material.WoodPlanks, color = rgb(84, 104, 118) }, palette.frame_white)
	makeRowboat(kit, palette, folder, "RowboatRed", { material = material.WoodPlanks, color = rgb(150, 66, 54) }, palette.frame_white)
	makeRowboat(kit, palette, folder, "RowboatGreen", { material = material.WoodPlanks, color = rgb(66, 98, 82) }, palette.paint_mustard)
	makeMooringPost(kit, palette, folder)
	makeBollard(kit, palette, folder)
	makeCrabPot(kit, palette, folder)
	makeBuoy(kit, palette, folder)
	makeFishBox(kit, palette, folder)
	makeRopeCoil(kit, palette, folder)
	makeNetRack(kit, palette, folder)
	makeAnchor(kit, palette, folder)

	makeBarrel(kit, palette, folder)
	makeCrate(kit, palette, folder)
	makeSack(kit, palette, folder, "Sack", false)
	makeSack(kit, palette, folder, "SackOpen", true)
	makeBasket(kit, palette, folder)
	makeWaterButt(kit, palette, folder)

	makeGate(kit, palette, folder)
	makePaperLine(kit, palette, folder)
	return folder
end

return prefabs