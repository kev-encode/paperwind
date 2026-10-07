--!strict
--[[
	DoorController
	What: swings doors on this client whenever their Open or Swing attribute changes
	How: each Leaf turns about its Hinge; the closed pose comes from the leaf's ClosedOffset attribute, relative to the
		door's Head, so it holds even if the door streamed out while open
	Streaming: doors are atomic models, so a door's frame and leaves arrive together; a door that streams in open snaps open
]]

local collection_service = game:GetService("CollectionService")
local replicated_storage = game:GetService("ReplicatedStorage")
local tween_service = game:GetService("TweenService")

local config = require(replicated_storage:WaitForChild("Doors"):WaitForChild("DoorConfig"))

type Leaf = {
	model: Model,
	hand: number,
	offset: CFrame,
	angle: NumberValue,
	tween: Tween?,
}

type Door = {
	head: BasePart,
	leaves: { Leaf },
	connections: { RBXScriptConnection },
}

local doors: { [Instance]: Door } = {}

-- Swinging ------------------------------------------------------------------

local function targetAngle(model: Model, leaf: Leaf): number
	if not model:GetAttribute("Open") then
		return 0
	end

	local swing = (model:GetAttribute("Swing") :: number?) or 1
	return swing * leaf.hand * config.open_angle
end

local function update(model: Model, instant: boolean)
	local door = doors[model]
	if not door then
		return
	end

	for _, leaf in door.leaves do
		local target = targetAngle(model, leaf)
		local tween = leaf.tween
		if tween then
			tween:Cancel()
		end

		if instant then
			leaf.angle.Value = target
		else
			-- note: a part-way swing takes part of the time
			local full = if target ~= 0 then config.open_time else config.close_time
			local share = math.abs(target - leaf.angle.Value) / config.open_angle
			local info = TweenInfo.new(math.max(full * share, 0.1), Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local created = tween_service:Create(leaf.angle, info, { Value = target })
			leaf.tween = created
			created:Play()
		end
	end
end

-- Tracking ------------------------------------------------------------------

local function addDoor(instance: Instance)
	if not instance:IsA("Model") or doors[instance] then
		return
	end

	local head = instance:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		return
	end

	local door: Door = { head = head, leaves = {}, connections = {} }
	for _, child in instance:GetChildren() do
		local offset = child:GetAttribute("ClosedOffset")
		if child:IsA("Model") and child.Name == "Leaf" and child.PrimaryPart and typeof(offset) == "CFrame" then
			local leaf: Leaf = {
				model = child,
				hand = (child:GetAttribute("Hand") :: number?) or 1,
				offset = offset,
				angle = Instance.new("NumberValue"),
				tween = nil,
			}
			table.insert(door.connections, leaf.angle.Changed:Connect(function(value: number)
				child:PivotTo(head.CFrame * leaf.offset * CFrame.Angles(0, math.rad(value), 0))
			end))
			table.insert(door.leaves, leaf)

			-- note: start from the closed pose; a leaf that streamed out open may still hold its old local pose
			child:PivotTo(head.CFrame * offset)
		end
	end

	doors[instance] = door
	for _, attribute in { "Open", "Swing" } do
		table.insert(door.connections, instance:GetAttributeChangedSignal(attribute):Connect(function()
			update(instance, false)
		end))
	end

	update(instance, true)
end

local function removeDoor(instance: Instance)
	local door = doors[instance]
	if not door then
		return
	end

	for _, connection in door.connections do
		connection:Disconnect()
	end

	for _, leaf in door.leaves do
		local tween = leaf.tween
		if tween then
			tween:Cancel()
		end
		leaf.angle:Destroy()
	end

	doors[instance] = nil
end

-- Start ---------------------------------------------------------------------

collection_service:GetInstanceAddedSignal(config.tag):Connect(addDoor)
collection_service:GetInstanceRemovedSignal(config.tag):Connect(removeDoor)
for _, instance in collection_service:GetTagged(config.tag) do
	addDoor(instance)
end