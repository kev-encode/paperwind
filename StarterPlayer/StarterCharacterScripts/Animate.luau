--!strict
--[[
	Animate (replaces Roblox's default character Animate script)

	Locomotion is a speed-driven blend: Idle -> Walk -> Run -> Sprint, picked from the character's
	real ground speed. The cyclic clips are phase-synced (right feet plant together) and their
	playback rates match the distance their feet travel, so steps stay planted at any speed.

	Also handles jump, fall, climb, swim, sit, tool hold/slash/lunge and emotes (emote wheel, /e).
	Clip IDs and measured stride speeds live in ReplicatedStorage.Movement.MovementConfig.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Movement"):WaitForChild("MovementConfig"))
local Clips = Config.Animations
local Emotes = Config.Emotes :: { [string]: { Ids: { string }, Looped: boolean } }

local character = script.Parent :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart
local animator = humanoid:WaitForChild("Animator") :: Animator
local State = Enum.HumanoidStateType
local Priority = Enum.AnimationPriority

local EPSILON = 0.001
local WEIGHT_RESPONSE = 20 -- how fast gait blend weights follow speed (1/s)
local GROUP_RESPONSE = 16 -- how fast locomotion fades around jumps, emotes, climbing...
local IDLE_SPEED = 0.5 -- below this ground speed the character idles
local WALK_IN_SPEED = 2.5 -- idle has fully blended into walk by this speed
local MIN_RATE, MAX_RATE = 0.35, 2.5 -- clamp on gait playback speed

if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
	warn("[Animate] Paperwind animations are R15-only. Set Game Settings > Avatar > Avatar Type to R15.")
end

-- Tracks ----------------------------------------------------------------------

local function loadTrack(id: string, priority: Enum.AnimationPriority, looped: boolean?): AnimationTrack
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local track = animator:LoadAnimation(animation)
	track.Priority = priority
	if looped ~= nil then
		track.Looped = looped
	end
	return track
end

type Gait = {
	track: AnimationTrack,
	natural: number, -- studs/s the feet travel at playback speed 1 (HipHeight 2)
	strike: number, -- normalized time the right foot plants
	weight: number,
}

local function gaitClip(def: { Id: string, NaturalSpeed: number, StrikePhase: number }): Gait
	return {
		track = loadTrack(def.Id, Priority.Core, true),
		natural = def.NaturalSpeed,
		strike = def.StrikePhase,
		weight = 0,
	}
end

local walk, run, sprint = gaitClip(Clips.Walk), gaitClip(Clips.Run), gaitClip(Clips.Sprint)
local gaits = { walk, run, sprint }

local idleMain = loadTrack(Clips.Idle[1].Id, Priority.Core, true)
local idleAlt = loadTrack(Clips.Idle[2].Id, Priority.Core, true)
local idleAltChance = Clips.Idle[2].Weight / (Clips.Idle[1].Weight + Clips.Idle[2].Weight)

local overlays = {
	Jump = loadTrack(Clips.Jump.Id, Priority.Core, false),
	Fall = loadTrack(Clips.Fall.Id, Priority.Core, true),
	Climb = loadTrack(Clips.Climb.Id, Priority.Core, true),
	Swim = loadTrack(Clips.Swim.Id, Priority.Core, true),
	SwimIdle = loadTrack(Clips.SwimIdle.Id, Priority.Core, true),
	Sit = loadTrack(Clips.Sit.Id, Priority.Core, true),
}

local toolNone = loadTrack(Clips.ToolNone.Id, Priority.Idle, true)
local toolSlash = loadTrack(Clips.ToolSlash.Id, Priority.Action, false)
local toolLunge = loadTrack(Clips.ToolLunge.Id, Priority.Action, false)

-- Only send weight/speed changes that matter (they replicate to other players).
local sentWeights: { [AnimationTrack]: number } = {}
local sentSpeeds: { [AnimationTrack]: number } = {}

local function setWeight(track: AnimationTrack, weight: number)
	weight = math.max(weight, EPSILON)
	local last = sentWeights[track]
	if not last or math.abs(weight - last) > 0.01 then
		track:AdjustWeight(weight, 0)
		sentWeights[track] = weight
	end
end

local function setSpeed(track: AnimationTrack, speed: number)
	local last = sentSpeeds[track]
	if not last or math.abs(speed - last) > 0.02 then
		track:AdjustSpeed(speed)
		sentSpeeds[track] = speed
	end
end

-- State -----------------------------------------------------------------------

local mode = "Ground" -- Ground | Ledge | Jump | Fall | Climb | Swim | Sit | Inactive
local modeTime = 0
local groupWeight = 1 -- visibility of the whole locomotion layer
local idleWeight, idleMix, idleAltTimer = 1, 0, 0
local smoothedSpeed = 0
local currentOverlay: AnimationTrack? = nil
local emoteTrack: AnimationTrack? = nil

local function enterMode(newMode: string)
	mode = newMode
	modeTime = 0
end

-- Overlays are the exclusive non-locomotion poses (jump, fall, climb, swim, sit).
local function setOverlay(track: AnimationTrack?, fade: number, restart: boolean?)
	if track == currentOverlay and not restart then
		return
	end
	if currentOverlay and currentOverlay ~= track then
		currentOverlay:Stop(fade)
	end
	currentOverlay = track
	if track then
		if track.IsPlaying then
			if restart then
				track.TimePosition = 0
			end
		else
			track:Play(fade, 1, 1)
		end
	end
end

local function stopEmote(fade: number)
	local track = emoteTrack
	if track then
		emoteTrack = nil
		track:Stop(fade)
	end
end

humanoid.StateChanged:Connect(function(_, new)
	if new == State.Jumping then
		stopEmote(0.1)
		enterMode("Jump")
		setOverlay(overlays.Jump, 0.1, true)
	elseif new == State.Freefall then
		if mode ~= "Jump" and mode ~= "Fall" then
			enterMode("Ledge") -- stepped off an edge: keep the gait going for a beat
		end
	elseif new == State.Running or new == State.RunningNoPhysics or new == State.Landed then
		if mode ~= "Ground" then
			enterMode("Ground")
			setOverlay(nil, 0.15)
		end
	elseif new == State.Climbing then
		stopEmote(0.1)
		enterMode("Climb")
		setOverlay(overlays.Climb, 0.15)
	elseif new == State.Swimming then
		stopEmote(0.1)
		enterMode("Swim")
	elseif new == State.Seated then
		stopEmote(0.1)
		enterMode("Sit")
		setOverlay(overlays.Sit, 0.3)
	else
		-- Dead, PlatformStanding, Physics, Ragdoll, FallingDown, GettingUp...: hold the rest pose.
		stopEmote(0.1)
		enterMode("Inactive")
		setOverlay(nil, 0.2)
	end
end)

-- Emotes (emote wheel and /e commands call this) --------------------------------

local playEmote = script:FindFirstChild("PlayEmote") :: BindableFunction?
if not playEmote then
	local created = Instance.new("BindableFunction")
	created.Name = "PlayEmote"
	created.Parent = script
	playEmote = created
end

(playEmote :: BindableFunction).OnInvoke = function(emote: any): (boolean, AnimationTrack?)
	-- Only while standing still on the ground.
	if mode ~= "Ground" or smoothedSpeed > IDLE_SPEED then
		return false, nil
	end
	local track: AnimationTrack? = nil
	if typeof(emote) == "string" then
		local def = Emotes[emote]
		if def then
			track = loadTrack(def.Ids[math.random(1, #def.Ids)], Priority.Core, def.Looped)
		end
	elseif typeof(emote) == "Instance" and emote:IsA("Animation") then
		track = animator:LoadAnimation(emote)
	end
	if not track then
		return false, nil
	end
	local playing = track :: AnimationTrack
	stopEmote(0.1)
	emoteTrack = playing
	playing.Stopped:Once(function()
		if emoteTrack == playing then
			emoteTrack = nil
		end
		task.delay(0.5, function()
			playing:Destroy()
		end)
	end)
	playing:Play(0.1)
	return true, playing
end

-- Tools -----------------------------------------------------------------------

local equippedTool: Tool? = nil
local toolAnimConnection: RBXScriptConnection? = nil

local function refreshTool()
	local tool = character:FindFirstChildOfClass("Tool")
	if tool == equippedTool then
		return
	end
	if toolAnimConnection then
		toolAnimConnection:Disconnect()
		toolAnimConnection = nil
	end
	equippedTool = tool
	if tool and tool:FindFirstChild("Handle") then
		toolNone:Play(0.1)
		-- Classic tool scripts request swings by adding a StringValue named "toolanim".
		toolAnimConnection = tool.ChildAdded:Connect(function(child)
			if child.Name == "toolanim" and child:IsA("StringValue") then
				if child.Value == "Slash" then
					toolSlash:Play(0.05)
				elseif child.Value == "Lunge" then
					toolLunge:Play(0.05)
				end
				child:Destroy()
			end
		end)
	else
		toolNone:Stop(0.1)
	end
end

character.ChildAdded:Connect(function(child)
	if child:IsA("Tool") then
		refreshTool()
	end
end)
character.ChildRemoved:Connect(function(child)
	if child:IsA("Tool") then
		refreshTool()
	end
end)

-- Locomotion ------------------------------------------------------------------

local function heightScale(): number
	if humanoid.AutomaticScalingEnabled then
		return math.max(humanoid.HipHeight / 2, 0.3)
	end
	return math.max(character:GetScale(), 0.3)
end

-- Target weights for idle / walk / run / sprint at a given ground speed. Outside the cross-fade
-- bands a single clip plays, rate-matched so its feet stay planted.
local walkToRun, runToSprint = Config.GaitBands.WalkToRun, Config.GaitBands.RunToSprint

local function gaitTargets(speed: number): (number, number, number, number)
	if speed < IDLE_SPEED then
		return 1, 0, 0, 0
	elseif speed < WALK_IN_SPEED then
		local t = (speed - IDLE_SPEED) / (WALK_IN_SPEED - IDLE_SPEED)
		return 1 - t, t, 0, 0
	elseif speed <= walkToRun[1] then
		return 0, 1, 0, 0
	elseif speed <= walkToRun[2] then
		local t = (speed - walkToRun[1]) / (walkToRun[2] - walkToRun[1])
		return 0, 1 - t, t, 0
	elseif speed <= runToSprint[1] then
		return 0, 0, 1, 0
	elseif speed <= runToSprint[2] then
		local t = (speed - runToSprint[1]) / (runToSprint[2] - runToSprint[1])
		return 0, 0, 1 - t, t
	end
	return 0, 0, 0, 1
end

idleMain.DidLoop:Connect(function()
	if idleAltTimer <= 0 and idleAlt.Length > 0 and math.random() < idleAltChance then
		idleAlt.TimePosition = 0
		idleAltTimer = idleAlt.Length
	end
end)

local function update(dt: number)
	if not character.Parent then
		return
	end
	dt = math.min(dt, 0.1)
	modeTime += dt

	local velocity = rootPart.AssemblyLinearVelocity
	local groundSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	smoothedSpeed += (groundSpeed - smoothedSpeed) * (1 - math.exp(-20 * dt))
	local scale = heightScale()

	-- Timed transitions
	if mode == "Jump" then
		local jump = overlays.Jump
		local finished = jump.Length > 0 and modeTime >= jump.Length * 0.95
		if (modeTime > 0.12 and velocity.Y < 0) or finished then
			enterMode("Fall")
			setOverlay(overlays.Fall, 0.3)
		end
	elseif mode == "Ledge" then
		if velocity.Y > 15 then
			enterMode("Jump") -- coyote-time jump
			setOverlay(overlays.Jump, 0.1, true)
		elseif modeTime > 0.18 then
			enterMode("Fall")
			setOverlay(overlays.Fall, 0.25)
		end
	elseif mode == "Climb" then
		setSpeed(overlays.Climb, math.clamp(velocity.Y / (5 * scale), -3, 3))
	elseif mode == "Swim" then
		if velocity.Magnitude > 1 then
			setOverlay(overlays.Swim, 0.4)
			setSpeed(overlays.Swim, math.clamp(velocity.Magnitude / (10 * scale), 0.3, 2.5))
		else
			setOverlay(overlays.SwimIdle, 0.4)
		end
	end

	-- Emotes end as soon as the player moves or leaves the ground.
	if emoteTrack and (smoothedSpeed > IDLE_SPEED or mode ~= "Ground") then
		stopEmote(0.15)
	end

	-- Locomotion layer visibility
	local groundLike = mode == "Ground" or mode == "Ledge"
	local groupTarget = if groundLike and not emoteTrack then 1 else 0
	groupWeight += (groupTarget - groupWeight) * (1 - math.exp(-GROUP_RESPONSE * dt))

	-- Gait blend from real speed
	local tIdle, tWalk, tRun, tSprint = gaitTargets(smoothedSpeed)
	local k = 1 - math.exp(-WEIGHT_RESPONSE * dt)
	idleWeight += (tIdle - idleWeight) * k
	walk.weight += (tWalk - walk.weight) * k
	run.weight += (tRun - run.weight) * k
	sprint.weight += (tSprint - sprint.weight) * k

	-- Cycle rate: the blended stride must cover the ground speed exactly.
	local gaitTotal = math.max(walk.weight + run.weight + sprint.weight, EPSILON)
	local cycleDistance = 0
	for _, gait in gaits do
		local length = gait.track.Length
		if length > 0 then
			cycleDistance += (gait.weight / gaitTotal) * gait.natural * scale * length
		end
	end
	local cyclesPerSecond = if cycleDistance > 1e-3 then smoothedSpeed / cycleDistance else 0

	-- Phase sync: the heaviest clip leads, the others follow its foot timing.
	local leader: Gait? = nil
	for _, gait in gaits do
		if gait.track.Length > 0 and (not leader or gait.weight > leader.weight) then
			leader = gait
		end
	end
	if leader and leader.weight > 0.02 then
		local phase = (leader.track.TimePosition / leader.track.Length - leader.strike) % 1
		for _, gait in gaits do
			local length = gait.track.Length
			if gait ~= leader and length > 0 then
				local desired = ((phase + gait.strike) % 1) * length
				local drift = (gait.track.TimePosition - desired + length / 2) % length - length / 2
				if math.abs(drift) > 0.04 * length then
					gait.track.TimePosition = desired
				end
			end
		end
	end

	for _, gait in gaits do
		local length = gait.track.Length
		local rate = if length > 0 and cyclesPerSecond > 0
			then math.clamp(cyclesPerSecond * length, MIN_RATE, MAX_RATE)
			else 1
		setWeight(gait.track, gait.weight * groupWeight)
		setSpeed(gait.track, rate)
	end

	-- Idle (with an occasional variation)
	if idleAltTimer > 0 then
		idleAltTimer -= dt
	end
	idleMix += ((if idleAltTimer > 0 then 1 else 0) - idleMix) * (1 - math.exp(-3 * dt))
	local idleVisible = idleWeight * groupWeight
	setWeight(idleMain, idleVisible * (1 - idleMix))
	setWeight(idleAlt, idleVisible * idleMix)
end

-- Start -----------------------------------------------------------------------

for _, gait in gaits do
	gait.track:Play(0, EPSILON, 1)
	sentWeights[gait.track] = EPSILON
end
idleMain:Play(0.1, 1, 1)
sentWeights[idleMain] = 1
idleAlt:Play(0, EPSILON, 1)
sentWeights[idleAlt] = EPSILON
refreshTool()

local stepSignal: RBXScriptSignal = RunService.Heartbeat
pcall(function()
	stepSignal = (RunService :: any).PreAnimation
end)
stepSignal:Connect(update)
