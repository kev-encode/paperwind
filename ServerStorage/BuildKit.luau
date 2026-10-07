--!strict
--[[
	BuildKit
	What: edit-time helpers for building towns: parts, walls with openings, roofs, masonry trim, floors, stairs, ground and prefabs
	Used by: the studio assistant while building; nothing requires it at runtime
	Frames: a wall's local x runs to the right seen from outside, y up, z outward
	Buildings: the cframe sits at the footprint centre on the floor; the front wall faces the lookvector (local -z)
	Wall props: pivot on the wall surface with local z pointing away from the wall
	Prefabs: ServerStorage.Prefabs, cloned with placePrefab()
	Detail: decorative parts go through detail(), so they cast no shadow and skip collision, touch and queries
]]

local collection_service = game:GetService("CollectionService")
local server_storage = game:GetService("ServerStorage")
local workspace = game:GetService("Workspace")

export type Style = {
	material: Enum.Material,
	color: Color3,
	variant: string?,
	transparency: number?,
}

export type Opening = {
	x: number, -- note: centre along the wall
	y: number, -- note: bottom above the floor
	w: number,
	h: number,
	prefab: string?, -- note: window or door prefab fitted into the hole
	label: string?, -- note: object text on a door's prompt
}

export type Openings = {
	front: { Opening }?,
	back: { Opening }?,
	left: { Opening }?,
	right: { Opening }?,
}

export type Hole = {
	x: number,
	z: number,
	w: number, -- note: size along local x
	d: number, -- note: size along local z
}

export type StoreySpec = {
	length: number,
	width: number,
	height: number,
	thickness: number,
	style: Style,
	openings: Openings?,
	floor: Style?,
	lining: Style?, -- note: plaster skin on the inner faces
	fittings: Instance?, -- note: where window and door prefabs go; defaults to the storey's parent
}

export type RoofSpec = {
	length: number, -- note: along the ridge (local x), end wall to end wall
	span: number, -- note: across the ridge (local z), side wall to side wall
	rise: number,
	eave: number, -- note: overhang past the side walls
	gable: number, -- note: overhang past the end walls
	thickness: number,
	style: Style,
	ridge: Style?,
	trim: Style?, -- note: liggers on thatch, bargeboards and fascias on slate
	wall: number?, -- note: side wall thickness; fills the wedge between wall top and roof underside
	drop: number?, -- note: eave height above the floor; slate roofs run downpipes to the floor
}

local LINING = 0.2
local SMALL_PART = 0.6 -- note: parts this small never cast shadows
local IRON = { material = Enum.Material.Metal, color = Color3.fromRGB(46, 46, 48) }

local build_kit = {}

-- Parts ---------------------------------------------------------------------

local function applyStyle(part: BasePart, style: Style)
	part.Anchored = true
	part.Material = style.material
	part.Color = style.color
	part.Transparency = style.transparency or 0
	part.MaterialVariant = style.variant or ""
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanTouch = false

	local size = part.Size
	if math.max(size.X, size.Y, size.Z) <= SMALL_PART then
		part.CastShadow = false
	end
end

local function newPart(class_name: string, parent: Instance, size: Vector3, cframe: CFrame, style: Style, name: string): BasePart
	local part = Instance.new(class_name) :: BasePart
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	applyStyle(part, style)
	part.Parent = parent
	return part
end

function build_kit.part(parent: Instance, size: Vector3, cframe: CFrame, style: Style, name: string?): Part
	return newPart("Part", parent, size, cframe, style, name or "Part") :: Part
end

-- note: a wedge is full height at its local +z end and slopes down to its -z end
function build_kit.wedge(parent: Instance, size: Vector3, cframe: CFrame, style: Style, name: string?): WedgePart
	return newPart("WedgePart", parent, size, cframe, style, name or "Wedge") :: WedgePart
end

-- note: the cylinder's axis runs along the cframe's x axis
function build_kit.cylinder(parent: Instance, length: number, diameter: number, cframe: CFrame, style: Style, name: string?): Part
	local part = build_kit.part(parent, Vector3.new(length, diameter, diameter), cframe, style, name or "Cylinder")
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- note: an upright cylinder standing on the cframe, height along y
function build_kit.post(parent: Instance, height: number, diameter: number, cframe: CFrame, style: Style, name: string?): Part
	return build_kit.cylinder(parent, height, diameter, cframe * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), style, name or "Post")
end

function build_kit.ball(parent: Instance, diameter: number, cframe: CFrame, style: Style, name: string?): Part
	local part = build_kit.part(parent, Vector3.new(diameter, diameter, diameter), cframe, style, name or "Ball")
	part.Shape = Enum.PartType.Ball
	return part
end

-- note: ball parts stay round, so a sphere mesh shapes uneven ones
function build_kit.ellipsoid(parent: Instance, size: Vector3, cframe: CFrame, style: Style, name: string?): Part
	local part = build_kit.part(parent, size, cframe, style, name or "Ellipsoid")
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

function build_kit.model(parent: Instance, name: string, pivot: CFrame?): Model
	local model = Instance.new("Model")
	model.Name = name
	if pivot then
		model.WorldPivot = pivot
	end

	model.Parent = parent
	return model
end

function build_kit.folder(parent: Instance, name: string): Instance
	local found = parent:FindFirstChild(name)
	if found then
		return found
	end

	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = parent
	return created
end

function build_kit.tag(instance: Instance, name: string)
	collection_service:AddTag(instance, name)
end

-- note: a copy of a style in another color
function build_kit.tint(style: Style, color: Color3): Style
	return { material = style.material, color = color, variant = style.variant, transparency = style.transparency }
end

-- note: decorative parts cast no shadow (unless kept) and skip collision, touch and queries
function build_kit.detail(target: Instance, keep_shadow: boolean?)
	local function apply(part: BasePart)
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		if not keep_shadow then
			part.CastShadow = false
		end
	end

	if target:IsA("BasePart") then
		apply(target)
	end

	for _, descendant in target:GetDescendants() do
		if descendant:IsA("BasePart") then
			apply(descendant)
		end
	end
end

-- note: under a root, parts no bigger than limit stop casting shadows; indoors, small things add cost and almost no look
function build_kit.quietShadows(root: Instance, limit: number)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			local size = descendant.Size
			if math.max(size.X, size.Y, size.Z) <= limit then
				descendant.CastShadow = false
			end
		end
	end
end

-- note: an invisible box that stands in for a prop's collision, so detailed props stay cheap and never snag
function build_kit.collider(parent: Instance, size: Vector3, cframe: CFrame): Part
	local part = Instance.new("Part")
	part.Name = "Collider"
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.Transparency = 1
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

-- Ground --------------------------------------------------------------------

local ground_params = RaycastParams.new()
ground_params.FilterType = Enum.RaycastFilterType.Include
ground_params.FilterDescendantsInstances = { workspace.Terrain }
ground_params.IgnoreWater = true

function build_kit.groundY(x: number, z: number): number
	local result = workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -800, 0), ground_params)
	if result then
		return result.Position.Y
	end

	return 0
end

-- note: lowest and highest ground under a footprint, sampled about every 2 studs
function build_kit.groundRange(cframe: CFrame, length: number, width: number): (number, number)
	local low = math.huge
	local high = -math.huge
	local steps_x = math.max(math.ceil(length / 2), 1)
	local steps_z = math.max(math.ceil(width / 2), 1)

	for i = 0, steps_x do
		for j = 0, steps_z do
			local x = -length / 2 + length * i / steps_x
			local z = -width / 2 + width * j / steps_z
			local point = cframe:PointToWorldSpace(Vector3.new(x, 0, z))
			local y = build_kit.groundY(point.X, point.Z)
			low = math.min(low, y)
			high = math.max(high, y)
		end
	end

	return low, high
end

-- note: the same frame moved down onto the terrain
function build_kit.onGround(frame: CFrame): CFrame
	local position = frame.Position
	return frame + Vector3.new(0, build_kit.groundY(position.X, position.Z) - position.Y, 0)
end

-- note: grass decoration grows up through floors, so the terrain under a footprint turns to plain ground
function build_kit.clearGrass(cframe: CFrame, length: number, width: number)
	local min_corner = Vector3.new(math.huge, 0, math.huge)
	local max_corner = Vector3.new(-math.huge, 0, -math.huge)
	for _, x in { -length / 2, length / 2 } do
		for _, z in { -width / 2, width / 2 } do
			local point = cframe:PointToWorldSpace(Vector3.new(x, 0, z))
			min_corner = min_corner:Min(point)
			max_corner = max_corner:Max(point)
		end
	end

	local low, high = build_kit.groundRange(cframe, length, width)
	local region = Region3.new(Vector3.new(min_corner.X, low - 8, min_corner.Z), Vector3.new(max_corner.X, high + 8, max_corner.Z)):ExpandToGrid(4)
	for _, grass in { Enum.Material.Grass, Enum.Material.LeafyGrass } do
		workspace.Terrain:ReplaceMaterial(region, 4, grass, Enum.Material.Ground)
	end
end

-- Walls ---------------------------------------------------------------------

-- note: a solid wall with rectangular holes; cframe sits on the floor at the wall's centre line
-- note: with a lining, the inner face gets a thin plaster skin and the outer leaf keeps the wall style
function build_kit.wall(parent: Instance, cframe: CFrame, length: number, height: number, thickness: number, style: Style, openings: { Opening }?, lining: Style?)
	local holes = openings or {}
	local cuts = { -length / 2, length / 2 }
	for _, hole in holes do
		table.insert(cuts, hole.x - hole.w / 2)
		table.insert(cuts, hole.x + hole.w / 2)
	end

	table.sort(cuts)

	local function segment(left: number, right: number, bottom: number, top: number)
		if right - left < 1e-3 or top - bottom < 1e-3 then
			return
		end

		local span = right - left
		local rise = top - bottom
		local centre_x = (left + right) / 2
		local centre_y = (bottom + top) / 2
		if lining then
			local outer = thickness - LINING
			build_kit.part(parent, Vector3.new(span, rise, outer), cframe * CFrame.new(centre_x, centre_y, LINING / 2), style, "Wall")
			build_kit.part(parent, Vector3.new(span, rise, LINING), cframe * CFrame.new(centre_x, centre_y, -thickness / 2 + LINING / 2), lining, "Lining")
			return
		end

		build_kit.part(parent, Vector3.new(span, rise, thickness), cframe * CFrame.new(centre_x, centre_y, 0), style, "Wall")
	end

	for i = 1, #cuts - 1 do
		local left = math.max(cuts[i], -length / 2)
		local right = math.min(cuts[i + 1], length / 2)
		local middle = (left + right) / 2

		-- note: every hole covering this column, bottom to top
		local covering = {}
		for _, hole in holes do
			if middle > hole.x - hole.w / 2 and middle < hole.x + hole.w / 2 then
				table.insert(covering, hole)
			end
		end

		table.sort(covering, function(a, b)
			return a.y < b.y
		end)

		local bottom = 0
		for _, hole in covering do
			segment(left, right, bottom, hole.y)
			bottom = hole.y + hole.h
		end

		segment(left, right, bottom, height)
	end
end

-- note: four walls around a footprint; returns each wall's frame for placing windows and doors
function build_kit.shell(parent: Instance, cframe: CFrame, length: number, width: number, height: number, thickness: number, style: Style, openings: Openings?, lining: Style?): { [string]: CFrame }
	local holes: Openings = openings or {}
	local inset = thickness / 2
	local sides = {
		front = { offset = Vector3.new(0, 0, -width / 2 + inset), outward = -Vector3.zAxis, span = length },
		back = { offset = Vector3.new(0, 0, width / 2 - inset), outward = Vector3.zAxis, span = length },
		left = { offset = Vector3.new(-length / 2 + inset, 0, 0), outward = -Vector3.xAxis, span = width - thickness * 2 },
		right = { offset = Vector3.new(length / 2 - inset, 0, 0), outward = Vector3.xAxis, span = width - thickness * 2 },
	}

	local frames = {}
	for side, info in sides do
		local position = cframe:PointToWorldSpace(info.offset)
		local outward = cframe:VectorToWorldSpace(info.outward)
		local up = cframe.UpVector
		local wall_frame = CFrame.fromMatrix(position, up:Cross(outward), up)
		frames[side] = wall_frame
		build_kit.wall(parent, wall_frame, info.span, height, thickness, style, (holes :: any)[side], lining)
	end

	return frames
end

-- note: a frame on a wall's inner face, local z into the room and x to the right seen from inside, y on the floor
function build_kit.innerFace(cframe: CFrame, length: number, width: number, thickness: number, side: string, along: number?): CFrame
	local normal = -Vector3.xAxis
	local position = Vector3.new(length / 2 - thickness, 0, 0)
	if side == "front" then
		normal = Vector3.zAxis
		position = Vector3.new(0, 0, -width / 2 + thickness)
	elseif side == "back" then
		normal = -Vector3.zAxis
		position = Vector3.new(0, 0, width / 2 - thickness)
	elseif side == "left" then
		normal = Vector3.xAxis
		position = Vector3.new(-length / 2 + thickness, 0, 0)
	end

	local right = Vector3.yAxis:Cross(normal)
	return cframe * CFrame.fromMatrix(position + right * (along or 0), right, Vector3.yAxis, normal)
end

-- Masonry -------------------------------------------------------------------

-- note: dressed corner stones up all four corners, long and short faces alternating like real quoins
function build_kit.quoins(parent: Instance, cframe: CFrame, length: number, width: number, height: number, style: Style, course: number?)
	local course_height = course or 1.2
	local proud = 0.08
	local count = math.floor(height / course_height)
	for _, corner in { Vector2.new(-1, -1), Vector2.new(1, -1), Vector2.new(1, 1), Vector2.new(-1, 1) } do
		for i = 0, count - 1 do
			local long_on_x = (i + (corner.X + corner.Y) / 2) % 2 == 0
			local along_x = if long_on_x then 2.4 else 1.3
			local along_z = if long_on_x then 1.3 else 2.4
			local x = corner.X * (length / 2 - along_x / 2 + proud)
			local z = corner.Y * (width / 2 - along_z / 2 + proud)
			local y = i * course_height + course_height / 2
			build_kit.part(parent, Vector3.new(along_x, course_height - 0.08, along_z), cframe * CFrame.new(x, y, z), style, "Quoin")
		end
	end
end

-- note: a horizontal band around a footprint, proud of the walls (plinth course, string course, jetty bressumer)
function build_kit.band(parent: Instance, cframe: CFrame, length: number, width: number, y: number, height: number, proud: number, style: Style, name: string?)
	local depth = proud + 0.4
	local label = name or "Band"
	for _, side in { -1, 1 } do
		local z = side * (width / 2 + (proud - 0.4) / 2)
		build_kit.part(parent, Vector3.new(length + proud * 2, height, depth), cframe * CFrame.new(0, y, z), style, label)

		local x = side * (length / 2 + (proud - 0.4) / 2)
		build_kit.part(parent, Vector3.new(depth, height, width - 0.8), cframe * CFrame.new(x, y, 0), style, label)
	end
end

-- Roofs ---------------------------------------------------------------------

-- note: frame of one roof slope at its centre; on the +z side local z runs down the slope, on the -z side up it
local function slopeFrame(cframe: CFrame, spec: RoofSpec, side: number): (CFrame, number, number)
	local angle = math.atan(spec.rise / (spec.span / 2))
	local run = spec.span / 2 + spec.eave
	local slope_length = run / math.cos(angle)
	local down = Vector3.new(0, -math.sin(angle), side * math.cos(angle))
	local normal = Vector3.new(0, math.cos(angle), side * math.sin(angle))
	local centre = Vector3.new(0, spec.rise, 0) + down * (slope_length / 2) + normal * (spec.thickness / 2)
	return cframe * CFrame.new(centre) * CFrame.Angles(side * angle, 0, 0), slope_length, angle
end

-- note: wedges on top of the side walls, filling the gap up to the roof's underside so no sky shows inside
local function eaveInfill(parent: Instance, cframe: CFrame, spec: RoofSpec, style: Style)
	local wall = spec.wall
	if not wall then
		return
	end

	local angle = math.atan(spec.rise / (spec.span / 2))
	local height = wall * math.tan(angle) + 0.1
	for _, side in { -1, 1 } do
		local inward = cframe:VectorToWorldSpace(Vector3.new(0, 0, -side))
		local up = cframe.UpVector
		local position = cframe:PointToWorldSpace(Vector3.new(0, height / 2, side * (spec.span / 2 - wall / 2)))
		build_kit.wedge(parent, Vector3.new(spec.length, height, wall), CFrame.fromMatrix(position, up:Cross(inward), up, inward), style, "EaveFill")
	end
end

-- note: a thick thatched gable roof with rolled eaves and a block-cut ridge; cframe sits at eave height, ridge along local x
function build_kit.thatchRoof(parent: Instance, cframe: CFrame, spec: RoofSpec, infill: Style?)
	local full_length = spec.length + spec.gable * 2
	local ridge_style = spec.ridge or spec.style
	local ligger_style = spec.trim or ridge_style
	local apron_depth = 3
	local apron_thickness = 0.5
	local point = 1.6

	for _, side in { -1, 1 } do
		local frame, slope_length = slopeFrame(cframe, spec, side)
		build_kit.part(parent, Vector3.new(full_length, spec.thickness, slope_length), frame, spec.style, "Thatch")

		-- note: the eave rolls under into a soft rounded edge
		local eave_edge = frame * CFrame.new(0, -spec.thickness * 0.1, side * (slope_length / 2 - spec.thickness * 0.35))
		build_kit.cylinder(parent, full_length, spec.thickness * 1.1, eave_edge, spec.style, "EaveRoll")

		-- note: the ridge apron sits proud along the top, and its lower edge is cut into points
		local apron = frame * CFrame.new(0, spec.thickness / 2 + apron_thickness / 2 - 0.1, -side * (slope_length / 2 - apron_depth / 2))
		build_kit.part(parent, Vector3.new(full_length - 0.4, apron_thickness, apron_depth), apron, ridge_style, "RidgeApron")

		local count = math.floor((full_length - 1) / point)
		local edge = apron * CFrame.new(0, 0, side * apron_depth / 2)
		local diamond = point / math.sqrt(2)
		for i = 0, count - 1 do
			local x = -((count - 1) * point) / 2 + i * point
			local point_frame = edge * CFrame.new(x, 0, 0) * CFrame.Angles(0, math.rad(45), 0)
			build_kit.detail(build_kit.part(parent, Vector3.new(diamond, apron_thickness, diamond), point_frame, ridge_style, "RidgePoint"))
		end

		-- note: hazel liggers pin the ridge, two rows along the apron
		for _, z in { -0.7, 0.6 } do
			local ligger = apron * CFrame.new(0, apron_thickness / 2 + 0.03, side * z)
			build_kit.detail(build_kit.part(parent, Vector3.new(full_length - 0.8, 0.08, 0.14), ligger, ligger_style, "Ligger"))
		end
	end

	-- note: a slim roll softens the apex; it stops short of the verges so its ends stay hidden
	local angle = math.atan(spec.rise / (spec.span / 2))
	local apex = cframe * CFrame.new(0, spec.rise + spec.thickness / math.cos(angle) - spec.thickness * 0.55, 0)
	build_kit.cylinder(parent, full_length - 1.2, spec.thickness * 0.95, apex, ridge_style, "RidgeRoll")

	if infill then
		eaveInfill(parent, cframe, spec, infill)
	end
end

-- note: a slate gable roof with an angular ridge, bargeboards, fascias, gutters and downpipes; cframe sits at eave height
function build_kit.slateRoof(parent: Instance, cframe: CFrame, spec: RoofSpec, infill: Style?)
	local full_length = spec.length + spec.gable * 2
	local trim = spec.trim or spec.style
	local angle = math.atan(spec.rise / (spec.span / 2))
	local eave_drop = spec.eave * math.tan(angle)

	for _, side in { -1, 1 } do
		local frame, slope_length = slopeFrame(cframe, spec, side)
		build_kit.part(parent, Vector3.new(full_length, spec.thickness, slope_length), frame, spec.style, "Slates")

		-- note: bargeboards follow the verge at both gable ends, in the gable's plane
		for _, end_side in { -1, 1 } do
			local barge = frame * CFrame.new(end_side * (full_length / 2 - 0.12), -spec.thickness / 2 - 0.35, 0)
			build_kit.part(parent, Vector3.new(0.24, 0.8, slope_length), barge, trim, "Bargeboard")
		end

		-- note: an upright fascia under the eave edge with a half-round gutter in front of it
		local eave_z = side * (spec.span / 2 + spec.eave)
		build_kit.part(parent, Vector3.new(full_length, 0.8, 0.2), cframe * CFrame.new(0, -eave_drop - 0.2, eave_z + side * 0.05), trim, "Fascia")
		local gutter_y = -eave_drop - 0.45
		build_kit.detail(build_kit.cylinder(parent, full_length, 0.5, cframe * CFrame.new(0, gutter_y, eave_z + side * 0.4), IRON, "Gutter"))

		-- note: one downpipe per side, at the +x end, down the wall to the floor
		local drop = spec.drop
		if drop then
			local pipe_x = spec.length / 2 - 0.8
			local pipe_z = side * (spec.span / 2 + 0.35)
			local top = gutter_y - 0.2
			local bottom = -drop + 0.3
			local pipe = cframe * CFrame.new(pipe_x, (top + bottom) / 2, pipe_z) * CFrame.Angles(0, 0, math.rad(90))
			build_kit.detail(build_kit.cylinder(parent, top - bottom, 0.4, pipe, IRON, "Downpipe"), true)
			local neck_length = math.abs(eave_z + side * 0.4 - pipe_z)
			local neck = cframe * CFrame.new(pipe_x, top, (eave_z + side * 0.4 + pipe_z) / 2) * CFrame.Angles(0, math.rad(90), 0)
			build_kit.detail(build_kit.cylinder(parent, neck_length, 0.36, neck, IRON, "SwanNeck"))
		end
	end

	local cap = spec.thickness * 1.5
	local ridge_style = spec.ridge or spec.style
	local ridge_y = spec.rise + spec.thickness / math.cos(angle) - cap * 0.3
	build_kit.part(parent, Vector3.new(full_length + 0.2, cap, cap), cframe * CFrame.new(0, ridge_y, 0) * CFrame.Angles(math.rad(45), 0, 0), ridge_style, "Ridge")

	if infill then
		eaveInfill(parent, cframe, spec, infill)
	end
end

-- note: triangles that close the roof above the two end walls (local -x and +x)
function build_kit.gableEnds(parent: Instance, cframe: CFrame, length: number, span: number, rise: number, thickness: number, style: Style)
	local up = cframe.UpVector

	for _, end_side in { -1, 1 } do
		local x = end_side * (length / 2 - thickness / 2)
		for _, half in { -1, 1 } do
			local position = cframe:PointToWorldSpace(Vector3.new(x, rise / 2, half * span / 4))
			local toward_ridge = cframe:VectorToWorldSpace(Vector3.new(0, 0, -half))
			local wedge_frame = CFrame.fromMatrix(position, up:Cross(toward_ridge), up, toward_ridge)
			build_kit.wedge(parent, Vector3.new(thickness, rise, span / 2), wedge_frame, style, "Gable")
		end
	end
end

-- Foundations ---------------------------------------------------------------

-- note: a plinth from below the lowest ground up to the floor; clears the grass under it and returns the floor height
function build_kit.plinth(parent: Instance, cframe: CFrame, length: number, width: number, style: Style, lift: number?): (number, Part)
	local low, high = build_kit.groundRange(cframe, length + 2, width + 2)
	local floor_y = high + (lift or 0.8)
	local bottom = low - 3
	local flat = cframe - cframe.Position + Vector3.new(cframe.X, (floor_y + bottom) / 2, cframe.Z)
	local base = build_kit.part(parent, Vector3.new(length + 1, floor_y - bottom, width + 1), flat, style, "Plinth")
	build_kit.clearGrass(cframe, length + 1, width + 1)
	return floor_y, base
end

-- Floors --------------------------------------------------------------------

-- note: a level slab whose top sits on the cframe, with an optional rectangular hole such as a stairwell
function build_kit.slab(parent: Instance, cframe: CFrame, length: number, width: number, thickness: number, style: Style, hole: Hole?, name: string?)
	local label = name or "Slab"
	local function piece(x0: number, x1: number, z0: number, z1: number)
		if x1 - x0 < 1e-3 or z1 - z0 < 1e-3 then
			return
		end

		local size = Vector3.new(x1 - x0, thickness, z1 - z0)
		build_kit.part(parent, size, cframe * CFrame.new((x0 + x1) / 2, -thickness / 2, (z0 + z1) / 2), style, label)
	end

	if not hole then
		piece(-length / 2, length / 2, -width / 2, width / 2)
		return
	end

	local hole_x0 = hole.x - hole.w / 2
	local hole_x1 = hole.x + hole.w / 2
	local hole_z0 = hole.z - hole.d / 2
	local hole_z1 = hole.z + hole.d / 2
	piece(-length / 2, length / 2, -width / 2, hole_z0)
	piece(-length / 2, length / 2, hole_z1, width / 2)
	piece(-length / 2, hole_x0, hole_z0, hole_z1)
	piece(hole_x1, length / 2, hole_z0, hole_z1)
end

-- note: a boarded ceiling on exposed joists; cframe sits on the floor below and height is the next floor level
function build_kit.beamedCeiling(parent: Instance, cframe: CFrame, length: number, width: number, height: number, board: Style, beam: Style, spacing: number, hole: Hole?)
	local thickness = 0.5
	build_kit.slab(parent, cframe * CFrame.new(0, height, 0), length, width, thickness, board, hole, "Ceiling")

	local count = math.max(math.floor(length / spacing), 1)
	local beam_y = height - thickness - 0.45
	for i = 0, count - 1 do
		local x = -length / 2 + (i + 0.5) * length / count
		local crosses_hole = hole and math.abs(x - hole.x) < hole.w / 2 + 0.5
		if hole and crosses_hole then
			-- note: joists stop short of the stairwell on both sides
			local near = hole.z - hole.d / 2 + width / 2
			local far = width / 2 - (hole.z + hole.d / 2)
			if near > 0.5 then
				build_kit.part(parent, Vector3.new(0.8, 0.9, near), cframe * CFrame.new(x, beam_y, -width / 2 + near / 2), beam, "Joist")
			end
			if far > 0.5 then
				build_kit.part(parent, Vector3.new(0.8, 0.9, far), cframe * CFrame.new(x, beam_y, width / 2 - far / 2), beam, "Joist")
			end
		else
			build_kit.part(parent, Vector3.new(0.8, 0.9, width), cframe * CFrame.new(x, beam_y, 0), beam, "Joist")
		end
	end
end

-- note: a straight flight; cframe sits on the floor at the front edge of the first step and the flight climbs toward local +z
-- note: steps are solid blocks under oak treads, so the flight reads as boxed in; rail is the side (-1 or 1) for a handrail
function build_kit.stairs(parent: Instance, cframe: CFrame, width: number, steps: number, rise: number, run: number, body: Style, tread: Style, rail: number?)
	for i = 1, steps do
		local top = i * rise
		local z = (i - 0.5) * run
		build_kit.part(parent, Vector3.new(width, top, run), cframe * CFrame.new(0, top / 2, z), body, "Step")
		build_kit.part(parent, Vector3.new(width + 0.1, 0.16, run + 0.12), cframe * CFrame.new(0, top + 0.08, z - 0.06), tread, "Tread")
	end

	if not rail then
		return
	end

	local x = rail * (width / 2 - 0.2)
	local slope = rise / run
	local rail_height = 3
	local function railY(z: number): number
		return rise + rail_height + z * slope
	end

	local first = 0.3
	local last = (steps - 1) * run + 0.3
	build_kit.part(parent, Vector3.new(0.6, railY(first) + 0.5, 0.6), cframe * CFrame.new(x, (railY(first) + 0.5) / 2, first), tread, "Newel")
	local top_floor = steps * rise
	local top_post = railY(last) + 0.5 - top_floor
	build_kit.part(parent, Vector3.new(0.6, top_post, 0.6), cframe * CFrame.new(x, top_floor + top_post / 2, last), tread, "Newel")

	local span = last - first
	local length = span * math.sqrt(1 + slope * slope)
	local middle = (first + last) / 2
	build_kit.part(parent, Vector3.new(0.3, 0.35, length), cframe * CFrame.new(x, railY(middle), middle) * CFrame.Angles(-math.atan(slope), 0, 0), tread, "Handrail")

	for i = 2, steps - 1, 2 do
		local z = (i - 0.5) * run
		local bottom = i * rise + 0.16
		local height = railY(z) - bottom
		build_kit.detail(build_kit.part(parent, Vector3.new(0.18, height, 0.18), cframe * CFrame.new(x, bottom + height / 2, z), tread, "Baluster"), true)
	end
end

-- Prefabs -------------------------------------------------------------------

function build_kit.prefabFolder(): Instance
	return build_kit.folder(server_storage, "Prefabs")
end

function build_kit.placePrefab(name: string, parent: Instance, cframe: CFrame): Model
	local source = build_kit.prefabFolder():FindFirstChild(name)
	assert(source and source:IsA("Model"), "missing prefab " .. name)

	local copy = source:Clone()
	copy:PivotTo(cframe)
	copy.Parent = parent
	return copy
end

-- Storeys -------------------------------------------------------------------

-- note: a shell, the prefab in every opening that names one, and a floor inside; returns each wall's frame
function build_kit.storey(parent: Instance, cframe: CFrame, spec: StoreySpec): { [string]: CFrame }
	local holes: Openings = spec.openings or {}
	local frames = build_kit.shell(parent, cframe, spec.length, spec.width, spec.height, spec.thickness, spec.style, holes, spec.lining)
	local fittings = spec.fittings or parent

	for side, frame in frames do
		for _, hole in (holes :: any)[side] or {} do
			if hole.prefab then
				local placed = build_kit.placePrefab(hole.prefab, fittings, frame * CFrame.new(hole.x, hole.y + hole.h / 2, 0))
				local prompt = placed:FindFirstChildWhichIsA("ProximityPrompt", true)
				if prompt and hole.label then
					prompt.ObjectText = hole.label
				end
			end
		end
	end

	local floor = spec.floor
	if floor then
		local inner = Vector3.new(spec.length - spec.thickness * 2, 0.4, spec.width - spec.thickness * 2)
		-- note: sits 0.05 proud so it never z-fights with a plinth top
		build_kit.part(parent, inner, cframe * CFrame.new(0, -0.15, 0), floor, "Floor")
	end

	return frames
end

return build_kit