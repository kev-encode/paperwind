--!strict
--[[
	NpcController
	What: plays an idle loop on every NPC tagged Npc while it is streamed in on this client
	How: npcs are anchored and skip the humanoid state machine, so only clients animate them; each starts at a random
		point in the loop and runs at its own speed, so neighbours never breathe in step
	Streaming: npcs are atomic models, so the humanoid arrives with the tag
]]

local collection_service = game:GetService("CollectionService")
local replicated_storage = game:GetService("ReplicatedStorage")

local config = require(replicated_storage:WaitForChild("Npcs"):WaitForChild("NpcConfig"))

local idle = Instance.new("Animation")
idle.AnimationId = config.idle

local tracks: { [Instance]: AnimationTrack } = {}

-- Idle ----------------------------------------------------------------------

-- note: a track's length is 0 until its animation loads
local function startPartWay(track: AnimationTrack)
	if track.Length == 0 then
		track:GetPropertyChangedSignal("Length"):Wait()
	end

	track.TimePosition = math.random() * track.Length
end

local function addNpc(instance: Instance)
	if not instance:IsA("Model") or tracks[instance] then
		return
	end

	local humanoid = instance:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local track = (animator :: Animator):LoadAnimation(idle)
	local speed = config.idle_speed
	track.Looped = true
	track:Play(0)
	track:AdjustSpeed(speed.Min + math.random() * (speed.Max - speed.Min))
	tracks[instance] = track

	task.spawn(startPartWay, track)
end

local function removeNpc(instance: Instance)
	local track = tracks[instance]
	if not track then
		return
	end

	track:Stop(0)
	track:Destroy()
	tracks[instance] = nil
end

-- Start ---------------------------------------------------------------------

collection_service:GetInstanceAddedSignal(config.tag):Connect(addNpc)
collection_service:GetInstanceRemovedSignal(config.tag):Connect(removeNpc)
for _, instance in collection_service:GetTagged(config.tag) do
	addNpc(instance)
end
