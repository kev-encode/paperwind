--!strict
--[[
	DoorService
	What: opens and closes every door tagged Door when a player uses its prompt
	How: flips the door's Open attribute and, when opening, sets Swing so the door swings away from the player;
		DoorController animates the leaves on each client, so the server never moves them
	Prompts: each door's ProximityPrompt sits in its Head (the frame), which never moves
]]

local collection_service = game:GetService("CollectionService")
local proximity_prompt_service = game:GetService("ProximityPromptService")
local replicated_storage = game:GetService("ReplicatedStorage")

local config = require(replicated_storage:WaitForChild("Doors"):WaitForChild("DoorConfig"))

local last_used: { [Instance]: number } = {}

-- Doors ---------------------------------------------------------------------

-- note: 1 when the player stands outside the door (its head's local +z side), so it swings inward, away from them
local function swingAwayFrom(head: BasePart, player: Player): number
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return 1
	end

	if head.CFrame:PointToObjectSpace(root.Position).Z > 0 then
		return 1
	end

	return -1
end

local function toggle(door: Model, head: BasePart, prompt: ProximityPrompt, player: Player)
	local now = os.clock()
	if now - (last_used[door] or 0) < config.toggle_cooldown then
		return
	end

	last_used[door] = now
	local open = not door:GetAttribute("Open")
	if open then
		door:SetAttribute("Swing", swingAwayFrom(head, player))
	end

	door:SetAttribute("Open", open)
	prompt.ActionText = if open then config.close_text else config.open_text
end

-- Start ---------------------------------------------------------------------

proximity_prompt_service.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
	local door = prompt:FindFirstAncestorWhichIsA("Model")
	if not (door and collection_service:HasTag(door, config.tag)) then
		return
	end

	local head = door:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		toggle(door, head, prompt, player)
	end
end)

collection_service:GetInstanceRemovedSignal(config.tag):Connect(function(door: Instance)
	last_used[door] = nil
end)