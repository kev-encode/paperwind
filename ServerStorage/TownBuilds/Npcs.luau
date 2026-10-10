--!strict
--[[
	Npcs
	What: places the keepers of Fold Haven's four trade buildings into Workspace.FoldHaven.Npcs, each with a name tag
		and a Talk prompt; what talking does is not built yet
	Used by: the studio assistant (edit mode); nothing requires it at runtime
	Needs: config (ReplicatedStorage.Npcs.NpcConfig), passed in because studio caches required modules
	Look: r15 avatars dressed from the catalog through a HumanoidDescription: shirt, pants, hair and a dynamic head
	Cost: npcs skip the humanoid state machine and stay anchored; only the root part collides, and NpcController plays
		their idle on each client, so the server never animates them
]]

local collection_service = game:GetService("CollectionService")
local players = game:GetService("Players")
local workspace = game:GetService("Workspace")

local rgb = Color3.fromRGB

type Outfit = {
	skin: Color3,
	head: number, -- note: dynamic head asset
	brows: string, -- note: face accessory asset, or ""
	hair: string,
	shirt: number,
	pants: number,
}

type Keeper = {
	id: string,
	name: string,
	role: string,
	building: string,
	stand: Vector3, -- note: on the floor; the floor is found again by a ray from just above
	facing: Vector3,
	outfit: Outfit,
}

-- note: each keeper stands where customers meet them: behind a counter or at the head of the folding table,
-- clear of the till and the book press so their faces show from the customer's side
local KEEPERS: { Keeper } = {
	{
		id = "FoldKeeper",
		name = "Aldous Pell",
		role = "Fold Keeper",
		building = "FoldingWorkshop",
		stand = Vector3.new(-7.6, 14.1, -83),
		facing = Vector3.new(1, 0, 0.5), -- note: down the table, turned toward the front door
		outfit = {
			skin = rgb(224, 172, 138),
			head = 10725826963, -- note: man face
			brows = "10725837187",
			hair = "7611004838", -- note: white grandpa balding hair
			shirt = 17644960816, -- note: professor +
			pants = 13887926291, -- note: victorian brown tweed pants
		},
	},
	{
		id = "Papermaker",
		name = "Hob Vellum",
		role = "Papermaker",
		building = "PaperMill",
		stand = Vector3.new(17, 5.9, 43),
		facing = Vector3.new(1, 0, 0),
		outfit = {
			skin = rgb(196, 140, 104),
			head = 12954264879, -- note: joyful smile
			brows = "12954261247",
			hair = "9243992729", -- note: short and sleek, black
			shirt = 81289517033314, -- note: blacksmith (+), a leather work apron
			pants = 99221437133394, -- note: brown pants with riding boots
		},
	},
	{
		id = "Innkeeper",
		name = "Martha Tolley",
		role = "Innkeeper",
		building = "FoldedCraneInn",
		stand = Vector3.new(-70.5, 13.9, -25.5),
		facing = Vector3.new(1, 0, 0),
		outfit = {
			skin = rgb(234, 186, 152),
			head = 10725626210, -- note: woman face
			brows = "10725634831",
			hair = "2956239660", -- note: belle of belfast long red hair
			shirt = 14890887503, -- note: baker's shirt with apron
			pants = 11769772385, -- note: long skirt
		},
	},
	{
		id = "Shopkeeper",
		name = "Ned Tuppence",
		role = "Shopkeeper",
		building = "GeneralStore",
		stand = Vector3.new(61.2, 14.2, -34.3),
		facing = Vector3.new(-1, 0, 0),
		outfit = {
			skin = rgb(214, 160, 122),
			head = 11163789916, -- note: the winning smile
			brows = "",
			hair = "7193386173", -- note: side part, blonde
			shirt = 4500998761, -- note: the shopkeep
			pants = 99221437133394,
		},
	},
}

local npcs = {}

-- Body ----------------------------------------------------------------------

local function describe(outfit: Outfit): HumanoidDescription
	local description = Instance.new("HumanoidDescription")
	description.Head = outfit.head
	description.FaceAccessory = outfit.brows
	description.HairAccessory = outfit.hair
	description.Shirt = outfit.shirt
	description.Pants = outfit.pants

	-- note: a new description's body colours are black
	description.HeadColor = outfit.skin
	description.TorsoColor = outfit.skin
	description.LeftArmColor = outfit.skin
	description.RightArmColor = outfit.skin
	description.LeftLegColor = outfit.skin
	description.RightLegColor = outfit.skin

	return description
end

-- note: a still npc needs no state machine, server animation, touch or limb collision; the anchored root keeps it solid
local function settle(model: Model, humanoid: Humanoid, root: BasePart)
	humanoid.EvaluateStateMachine = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false

	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end

	root.Anchored = true
	root.CanCollide = true
	root.CanQuery = true
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
end

-- note: the root rides hip height plus half its own height above the floor
local function standOn(model: Model, humanoid: Humanoid, root: BasePart, keeper: Keeper, ignore: Instance)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ignore }

	local hit = workspace:Raycast(keeper.stand + Vector3.new(0, 3, 0), Vector3.new(0, -6, 0), params)
	local floor = if hit then hit.Position else keeper.stand
	local position = floor + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)

	model:PivotTo(CFrame.lookAt(position, position + keeper.facing))
end

-- Name tag and prompt -------------------------------------------------------

local function line(parent: Instance, name: string, text: string, font: Enum.Font, color: Color3, stroke: Color3, top: number, height: number)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0, top)
	label.Size = UDim2.fromScale(1, height)
	label.Font = font
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true

	local outline = Instance.new("UIStroke")
	outline.Color = stroke
	outline.Thickness = 1.5
	outline.Transparency = 0.2
	outline.Parent = label

	label.Parent = parent
end

-- note: always on top, so players find keepers through walls; unlit, so it reads at night
local function nameTag(config: any, head: BasePart, keeper: Keeper)
	local settings = config.name_tag
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Adornee = head
	gui.Size = UDim2.new(settings.size.X, settings.screen_size.X, settings.size.Y, settings.screen_size.Y)
	gui.StudsOffsetWorldSpace = Vector3.new(0, settings.height, 0)
	gui.MaxDistance = settings.max_distance
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true

	line(gui, "Name", keeper.name, settings.name_font, settings.name_color, settings.stroke_color, 0, 0.6)
	line(gui, "Role", keeper.role, settings.role_font, settings.role_color, settings.stroke_color, 0.62, 0.38)
	gui.Parent = head
end

local function talkPrompt(config: any, root: BasePart, keeper: Keeper)
	local settings = config.prompt
	local attachment = Instance.new("Attachment")
	attachment.Name = "PromptAttachment"
	attachment.Position = settings.offset

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TalkPrompt"
	prompt.ObjectText = keeper.name
	prompt.ActionText = settings.action_text
	prompt.KeyboardKeyCode = settings.key
	prompt.GamepadKeyCode = settings.gamepad_key
	prompt.MaxActivationDistance = settings.distance
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = true
	prompt.Parent = attachment

	attachment.Parent = root
end

-- Build ---------------------------------------------------------------------

local function place(config: any, keeper: Keeper, folder: Instance)
	local model = players:CreateHumanoidModelFromDescription(describe(keeper.outfit), Enum.HumanoidRigType.R15)
	model.Name = keeper.name

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local head = model:FindFirstChild("Head") :: BasePart
	humanoid.DisplayName = keeper.name

	settle(model, humanoid, root)
	standOn(model, humanoid, root, keeper, folder)
	nameTag(config, head, keeper)
	talkPrompt(config, root, keeper)

	model:SetAttribute("NpcId", keeper.id)
	model:SetAttribute("Role", keeper.role)
	model:SetAttribute("Building", keeper.building)
	collection_service:AddTag(model, config.tag)
	model.Parent = folder
end

-- note: replaces Workspace.FoldHaven.Npcs; the town must be built first
function npcs.build(config: any): Folder
	local town = workspace:FindFirstChild("FoldHaven")
	assert(town, "build Fold Haven before its npcs")

	local old = town:FindFirstChild("Npcs")
	if old then
		old:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "Npcs"
	folder.Parent = town

	for _, keeper in KEEPERS do
		place(config, keeper, folder)
	end

	return folder
end

return npcs
