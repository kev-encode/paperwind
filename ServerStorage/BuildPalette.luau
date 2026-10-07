--!strict
--[[
	BuildPalette
	What: shared materials and colors for town builds, as BuildKit styles
	Used by: the studio assistant with BuildKit and the TownBuilds modules; nothing requires it at runtime
	Look: warm, muted tones that read well under realistic lighting; one palette keeps every building cohesive
	Variants: generated MaterialVariants in MaterialService (LimeRender, RubbleStone, ThatchReed, Flagstone, OakBoards)
]]

local rgb = Color3.fromRGB
local material = Enum.Material

local palette = {
	-- Masonry -----------------------------------------------------------------

	-- note: LimeRender reads as coursed stone; its tint decides honey stone or whitewash
	stone = { material = material.Plaster, color = rgb(192, 182, 162), variant = "LimeRender" },
	whitewash = { material = material.Plaster, color = rgb(255, 253, 247), variant = "LimeRender" },
	rubble = { material = material.Cobblestone, color = rgb(214, 208, 198), variant = "RubbleStone" },
	dressed_stone = { material = material.Limestone, color = rgb(192, 184, 168) },
	granite = { material = material.Granite, color = rgb(150, 146, 140) },
	brick = { material = material.Brick, color = rgb(146, 96, 76) },
	flagstone = { material = material.Slate, color = rgb(214, 206, 192), variant = "Flagstone" },
	hearth = { material = material.Slate, color = rgb(72, 68, 64) },
	soot = { material = material.Slate, color = rgb(34, 32, 30) },

	-- Render and plaster ------------------------------------------------------

	render_cream = { material = material.Plaster, color = rgb(236, 224, 198) },
	render_pink = { material = material.Plaster, color = rgb(238, 216, 204) },
	plaster = { material = material.Plaster, color = rgb(234, 228, 214) },

	-- Timber ------------------------------------------------------------------

	timber = { material = material.Wood, color = rgb(66, 52, 42) },
	oak = { material = material.Wood, color = rgb(124, 94, 68) },
	oak_light = { material = material.Wood, color = rgb(166, 134, 98) },
	pine = { material = material.WoodPlanks, color = rgb(178, 144, 106) },
	-- note: the OakBoards texture runs red, so a grey-brown tint keeps floors honey rather than orange
	boards = { material = material.WoodPlanks, color = rgb(132, 120, 108), variant = "OakBoards" },
	weatherboard = { material = material.WoodPlanks, color = rgb(224, 220, 210) },
	tarred = { material = material.WoodPlanks, color = rgb(56, 54, 52) },
	wet_wood = { material = material.WoodPlanks, color = rgb(88, 76, 64) },
	driftwood = { material = material.Wood, color = rgb(152, 142, 128) },

	-- Roofs -------------------------------------------------------------------

	thatch = { material = material.Grass, color = rgb(160, 140, 102), variant = "ThatchReed" },
	thatch_ridge = { material = material.Grass, color = rgb(136, 120, 88), variant = "ThatchReed" },
	slate_roof = { material = material.RoofShingles, color = rgb(86, 90, 98) },
	ridge_tile = { material = material.Slate, color = rgb(70, 72, 76) },
	lead = { material = material.Metal, color = rgb(94, 98, 102) },

	-- Metal -------------------------------------------------------------------

	iron = { material = material.Metal, color = rgb(42, 42, 44) },
	brass = { material = material.Metal, color = rgb(178, 142, 78) },
	copper = { material = material.Metal, color = rgb(170, 106, 76) },

	-- Paint -------------------------------------------------------------------

	frame_white = { material = material.Wood, color = rgb(236, 232, 222) },
	paint_sage = { material = material.WoodPlanks, color = rgb(114, 134, 116) },
	paint_navy = { material = material.WoodPlanks, color = rgb(58, 72, 96) },
	paint_oxblood = { material = material.WoodPlanks, color = rgb(118, 52, 46) },
	paint_teal = { material = material.WoodPlanks, color = rgb(64, 112, 114) },
	paint_mustard = { material = material.WoodPlanks, color = rgb(188, 152, 76) },
	paint_green = { material = material.WoodPlanks, color = rgb(54, 84, 66) },

	-- Glass -------------------------------------------------------------------

	glass = { material = material.Glass, color = rgb(180, 198, 202), transparency = 0.55 },
	glass_green = { material = material.Glass, color = rgb(86, 122, 84), transparency = 0.25 },
	glass_amber = { material = material.Glass, color = rgb(164, 98, 48), transparency = 0.25 },
	glass_blue = { material = material.Glass, color = rgb(70, 96, 140), transparency = 0.25 },
	glass_clear = { material = material.Glass, color = rgb(222, 230, 232), transparency = 0.6 },
	lamp_glass = { material = material.Glass, color = rgb(222, 208, 178), transparency = 0.35 },

	-- Cloth -------------------------------------------------------------------

	linen = { material = material.Fabric, color = rgb(226, 218, 200) },
	wool_red = { material = material.Fabric, color = rgb(146, 62, 54) },
	wool_green = { material = material.Fabric, color = rgb(86, 104, 74) },
	wool_blue = { material = material.Fabric, color = rgb(70, 86, 116) },
	wool_ochre = { material = material.Fabric, color = rgb(186, 142, 74) },
	hessian = { material = material.Fabric, color = rgb(172, 148, 110) },
	rope = { material = material.Fabric, color = rgb(162, 142, 110) },
	net = { material = material.Fabric, color = rgb(72, 84, 72) },
	leather = { material = material.Leather, color = rgb(110, 72, 48) },

	-- Paper -------------------------------------------------------------------

	paper = { material = material.Fabric, color = rgb(240, 234, 216) },
	paper_white = { material = material.Fabric, color = rgb(248, 246, 240) },
	kraft = { material = material.Cardboard, color = rgb(186, 152, 110) },
	pulp = { material = material.Plaster, color = rgb(228, 224, 208) },
	felt = { material = material.Fabric, color = rgb(152, 148, 140) },
	ink = { material = material.SmoothPlastic, color = rgb(52, 56, 66) },

	-- Nature ------------------------------------------------------------------

	bark = { material = material.Wood, color = rgb(88, 76, 64) },
	leaf_dark = { material = material.LeafyGrass, color = rgb(58, 78, 46) },
	leaf = { material = material.LeafyGrass, color = rgb(74, 98, 56) },
	leaf_light = { material = material.LeafyGrass, color = rgb(102, 124, 66) },
	turf = { material = material.Grass, color = rgb(94, 114, 64) },
	soil = { material = material.Ground, color = rgb(88, 72, 58) },
	-- note: field stone for boulders and clitter; Granite reads as coarse moorland stone
	boulder = { material = material.Granite, color = rgb(134, 130, 124) },

	-- Light -------------------------------------------------------------------

	flame = { material = material.Neon, color = rgb(255, 164, 82) },
	ember = { material = material.Neon, color = rgb(216, 86, 42) },
}

return palette