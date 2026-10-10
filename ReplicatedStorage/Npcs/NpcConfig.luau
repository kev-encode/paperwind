--!strict
--[[
	NpcConfig
	What: tunables for the town's NPCs, shared by the TownBuilds.Npcs builder (edit time) and NpcController (client)
	NPCs: models tagged Npc in Workspace.FoldHaven.Npcs; each carries NpcId, Role and Building attributes
	Prompt: each NPC's TalkPrompt sits in an Attachment on its HumanoidRootPart; nothing handles it yet
]]

local rgb = Color3.fromRGB

local config = {
	tag = "Npc",
	idle = "rbxassetid://507766388", -- note: roblox r15 idle
	idle_speed = NumberRange.new(0.9, 1.1), -- note: each npc breathes at its own pace

	prompt = {
		action_text = "Talk",
		key = Enum.KeyCode.E,
		gamepad_key = Enum.KeyCode.ButtonX,
		distance = 10, -- note: studs; reaches across a counter
		offset = Vector3.new(0, 0.6, -1.2), -- note: in front of the chest, so the npc's own body never blocks line of sight
	},

	name_tag = {
		max_distance = 200, -- note: studs from the camera; covers the village core, fades before glimmerwood's clearings
		height = 1.7, -- note: studs from the head's centre to the tag's centre
		size = Vector2.new(7, 1.6), -- note: studs, so the tag shrinks with distance like a real sign
		screen_size = Vector2.new(110, 30), -- note: pixels added to the stud size, so far tags stay readable
		name_font = Enum.Font.Fondamento,
		role_font = Enum.Font.Merriweather,
		name_color = rgb(255, 246, 226),
		role_color = rgb(232, 206, 150),
		stroke_color = rgb(30, 22, 14),
	},
}

return config
