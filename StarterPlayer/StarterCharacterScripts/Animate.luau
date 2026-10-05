--!strict
--[[
	Animate
	What: replaces Roblox's default character Animate script
	Locomotion: blends idle, walk, run, and sprint by real ground speed, phase-synced so feet stay planted
	Also: jump, fall, climb, swim, sit, tools, and emotes (emote wheel, /e)
	Tuning: ReplicatedStorage.Movement.MovementConfig (clip ids, stride speeds)
]]

local run_service = game:GetService("RunService")
local replicated_storage = game:GetService("ReplicatedStorage")
local config = require(replicated_storage:WaitForChild("Movement"):WaitForChild("MovementConfig"))
local clips = config.animations
local emotes = config.emotes :: { [string]: { ids: { string }, looped: boolean } }

local character = script.Parent :: Model -- note: `script.Parent :: Model` is marked as an error on IDE
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local root_part = character:WaitForChild("HumanoidRootPart") :: BasePart
local animator = humanoid:WaitForChild("Animator") :: Animator
local STATE = Enum.HumanoidStateType
local PRIORITY = Enum.AnimationPriority
local EPSILON = 0.001
local WEIGHT_RESPONSE = 20 -- note: how fast gait weights follow speed, per second
local GROUP_RESPONSE = 16 -- note: how fast locomotion fades around jumps, emotes and climbing
local IDLE_SPEED = 0.5 -- note: below this ground speed the character idles
local WALK_IN_SPEED = 2.5 -- note: idle has fully blended into walk by this speed
local MIN_RATE, MAX_RATE = 0.35, 2.5 -- note: clamp on gait playback speed

if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
	warn("[Animate] Paperwind animations are R15-only. Set Game Settings > Avatar > Avatar Type to R15.")
end

--------------------------------------------------------------------
-- Tracks
--------------------------------------------------------------------

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
	natural: number, -- note: studs/s the feet travel at playback speed 1
	strike: number, -- note: normalized time the right foot plants
	weight: number,
}

local function gaitClip(clip: { id: string, natural_speed: number, strike_phase: number }): Gait
	return {
		track = loadTrack(clip.id, PRIORITY.Core, true),
		natural = clip.natural_speed,
		strike = clip.strike_phase,
		weight = 0,
	}
end

local walk, run, sprint = gaitClip(clips.walk), gaitClip(clips.run), gaitClip(clips.sprint)
local gaits = { walk, run, sprint }
local idle_main = loadTrack(clips.idle[1].id, PRIORITY.Core, true)
local idle_alt = loadTrack(clips.idle[2].id, PRIORITY.Core, true)
local idle_alt_chance = clips.idle[2].weight / (clips.idle[1].weight + clips.idle[2].weight)

local overlays = {
	jump = loadTrack(clips.jump.id, PRIORITY.Core, false),
	fall = loadTrack(clips.fall.id, PRIORITY.Core, true),
	climb = loadTrack(clips.climb.id, PRIORITY.Core, true),
	swim = loadTrack(clips.swim.id, PRIORITY.Core, true),
	swim_idle = loadTrack(clips.swim_idle.id, PRIORITY.Core, true),
	sit = loadTrack(clips.sit.id, PRIORITY.Core, true),
}

local tool_none = loadTrack(clips.tool_none.id, PRIORITY.Idle, true)
local tool_slash = loadTrack(clips.tool_slash.id, PRIORITY.Action, false)
local tool_lunge = loadTrack(clips.tool_lunge.id, PRIORITY.Action, false)

-- note: only send weight and speed changes that matter, they replicate to other players
local sent_weights: { [AnimationTrack]: number } = {}
local sent_speeds: { [AnimationTrack]: number } = {}

local function setWeight(track: AnimationTrack, weight: number)
	weight = math.max(weight, EPSILON)
	
	local last = sent_weights[track]
	if not last or math.abs(weight - last) > 0.01 then
		track:AdjustWeight(weight, 0)
		sent_weights[track] = weight
	end
end

local function setSpeed(track: AnimationTrack, speed: number)
	local last = sent_speeds[track]
	if not last or math.abs(speed - last) > 0.02 then
		track:AdjustSpeed(speed)
		sent_speeds[track] = speed
	end
end

--------------------------------------------------------------------
-- State
--------------------------------------------------------------------

local mode = "Ground" -- note: ground, ledge, jump, fall, climb, swim, sit or inactive
local mode_time = 0
local group_weight = 1 -- note: visibility of the whole locomotion layer
local idle_weight, idle_mix, idle_alt_timer = 1, 0, 0
local smoothed_speed = 0
local current_overlay: AnimationTrack? = nil
local emote_track: AnimationTrack? = nil

local function enterMode(new_mode: string)
	mode = new_mode
	mode_time = 0
end

-- note: overlays are the exclusive non-locomotion poses
local function setOverlay(track: AnimationTrack?, fade: number, restart: boolean?)
	if track == current_overlay and not restart then
		return
	end
	if current_overlay and current_overlay ~= track then
		current_overlay:Stop(fade)
	end
	current_overlay = track
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
	local track = emote_track
	if track then
		emote_track = nil
		track:Stop(fade)
	end
end

humanoid.StateChanged:Connect(function(i, new)
	if new == STATE.Jumping then
		stopEmote(0.1)
		enterMode("Jump")
		setOverlay(overlays.jump, 0.1, true)
		
	elseif new == STATE.Freefall then
		if mode ~= "Jump" and mode ~= "Fall" then
			enterMode("Ledge") -- note: stepped off an edge, keep the gait going for a beat
		end
		
	elseif new == STATE.Running or new == STATE.RunningNoPhysics or new == STATE.Landed then
		if mode ~= "Ground" then
			enterMode("Ground")
			setOverlay(nil, 0.15)
		end
		
	elseif new == STATE.Climbing then
		stopEmote(0.1)
		enterMode("Climb")
		setOverlay(overlays.climb, 0.15)
		
	elseif new == STATE.Swimming then
		stopEmote(0.1)
		enterMode("Swim")
		
	elseif new == STATE.Seated then
		stopEmote(0.1)
		enterMode("Sit")
		setOverlay(overlays.sit, 0.3)
		
	else
		-- note: dead, ragdoll, physics and similar hold the rest pose
		stopEmote(0.1)
		enterMode("Inactive")
		setOverlay(nil, 0.2)
	end
end)

--------------------------------------------------------------------
-- Emotes (emote wheel and /e commands call this)
--------------------------------------------------------------------

local play_emote = script:FindFirstChild("PlayEmote") :: BindableFunction?
if not play_emote then
	local created = Instance.new("BindableFunction")
	created.Name = "PlayEmote"
	created.Parent = script
	play_emote = created
end

(play_emote :: BindableFunction).OnInvoke = function(emote: any): (boolean, AnimationTrack?)
	-- note: only while standing still on the ground
	if mode ~= "Ground" or smoothed_speed > IDLE_SPEED then
		return false, nil
	end
	
	local track: AnimationTrack? = nil
	
	if typeof(emote) == "string" then
		local entry = emotes[emote]
		if entry then
			track = loadTrack(entry.ids[math.random(1, #entry.ids)], PRIORITY.Core, entry.looped)
		end
		
    elseif typeof(emote) == "Instance" and emote:IsA("Animation") then -- note: `emote:IsA` is marked as an error on IDE
		track = animator:LoadAnimation(emote)
	end
	
	if not track then
		return false, nil
	end
	
	local playing = track :: AnimationTrack
	stopEmote(0.1)
	emote_track = playing
	
	playing.Stopped:Once(function()
		if emote_track == playing then
			emote_track = nil
		end
		
		task.delay(0.5, function()
			playing:Destroy()
		end)
	end)
	
	playing:Play(0.1)
	return true, playing
end

--------------------------------------------------------------------
-- Tools
--------------------------------------------------------------------

local equipped_tool: Tool? = nil
local tool_connection: RBXScriptConnection? = nil

local function refreshTool()
	local tool = character:FindFirstChildOfClass("Tool")
	if tool == equipped_tool then
		return
	end
	
	if tool_connection then
		tool_connection:Disconnect()
		tool_connection = nil
	end
	
	equipped_tool = tool
	
	if tool and tool:FindFirstChild("Handle") then
		tool_none:Play(0.1)
		
		-- note: classic tool scripts request swings with a stringvalue named "toolanim"
		tool_connection = tool.ChildAdded:Connect(function(child)
			if child.Name == "toolanim" and child:IsA("StringValue") then
				if child.Value == "Slash" then
					tool_slash:Play(0.05)
					
				elseif child.Value == "Lunge" then
					tool_lunge:Play(0.05)
				end
				
				child:Destroy()
			end
		end)
		
	else
		tool_none:Stop(0.1)
		
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

--------------------------------------------------------------------
-- Locomotion
--------------------------------------------------------------------

local function heightScale(): number
	if humanoid.AutomaticScalingEnabled then
		return math.max(humanoid.HipHeight / 2, 0.3)
	end
	
	return math.max(character:GetScale(), 0.3)
end

-- note: outside the cross-fade bands a single clip plays, rate-matched so its feet stay planted
local walk_to_run, run_to_sprint = config.gait_bands.walk_to_run, config.gait_bands.run_to_sprint

local function gaitTargets(speed: number): (number, number, number, number)
	if speed < IDLE_SPEED then
		return 1, 0, 0, 0
		
	elseif speed < WALK_IN_SPEED then
		local blend = (speed - IDLE_SPEED) / (WALK_IN_SPEED - IDLE_SPEED)
		return 1 - blend, blend, 0, 0
		
	elseif speed <= walk_to_run[1] then
		return 0, 1, 0, 0
		
	elseif speed <= walk_to_run[2] then
		local blend = (speed - walk_to_run[1]) / (walk_to_run[2] - walk_to_run[1])
		return 0, 1 - blend, blend, 0
		
	elseif speed <= run_to_sprint[1] then
		return 0, 0, 1, 0
		
	elseif speed <= run_to_sprint[2] then
		local blend = (speed - run_to_sprint[1]) / (run_to_sprint[2] - run_to_sprint[1])
		return 0, 0, 1 - blend, blend
	end
	
	return 0, 0, 0, 1
end

idle_main.DidLoop:Connect(function()
	if idle_alt_timer <= 0 and idle_alt.Length > 0 and math.random() < idle_alt_chance then
		idle_alt.TimePosition = 0
		idle_alt_timer = idle_alt.Length
	end
end)

local function update(dt: number)
	if not character.Parent then
		return
	end
	
	dt = math.min(dt, 0.1)
	mode_time += dt
	
	local velocity = root_part.AssemblyLinearVelocity
	local ground_speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	smoothed_speed += (ground_speed - smoothed_speed) * (1 - math.exp(-20 * dt))
	local scale = heightScale()

	-- note: timed transitions
	if mode == "Jump" then
		local jump = overlays.jump
		local finished = jump.Length > 0 and mode_time >= jump.Length * 0.95
		
		if (mode_time > 0.12 and velocity.Y < 0) or finished then
			enterMode("Fall")
			setOverlay(overlays.fall, 0.3)
		end
		
	elseif mode == "Ledge" then
		if velocity.Y > 15 then
			enterMode("Jump") -- note: coyote-time jump
			setOverlay(overlays.jump, 0.1, true)
			
		elseif mode_time > 0.18 then
			enterMode("Fall")
			setOverlay(overlays.fall, 0.25)
		end
		
	elseif mode == "Climb" then
		setSpeed(overlays.climb, math.clamp(velocity.Y / (5 * scale), -3, 3))
		
	elseif mode == "Swim" then
		if velocity.Magnitude > 1 then
			setOverlay(overlays.swim, 0.4)
            setSpeed(overlays.swim, math.clamp(velocity.Magnitude / (10 * scale), 0.3, 2.5))
            
		else
			setOverlay(overlays.swim_idle, 0.4)
		end
	end

	-- note: emotes end as soon as the player moves or leaves the ground
	if emote_track and (smoothed_speed > IDLE_SPEED or mode ~= "Ground") then
		stopEmote(0.15)
	end

	-- note: locomotion layer visibility
	local ground_like = mode == "Ground" or mode == "Ledge"
	local group_target = if ground_like and not emote_track then 1 else 0
	group_weight += (group_target - group_weight) * (1 - math.exp(-GROUP_RESPONSE * dt))

	-- note: gait blend from real speed
	local idle_target, walk_target, run_target, sprint_target = gaitTargets(smoothed_speed)
	local rate = 1 - math.exp(-WEIGHT_RESPONSE * dt)
	idle_weight += (idle_target - idle_weight) * rate
	walk.weight += (walk_target - walk.weight) * rate
	run.weight += (run_target - run.weight) * rate
	sprint.weight += (sprint_target - sprint.weight) * rate

	-- note: the blended stride must cover the ground speed exactly
	local gait_total = math.max(walk.weight + run.weight + sprint.weight, EPSILON)
    local cycle_distance = 0
    
	for i, gait in gaits do
		local length = gait.track.Length
		if length > 0 then
			cycle_distance += (gait.weight / gait_total) * gait.natural * scale * length
		end
    end
    
	local cycles_per_second = if cycle_distance > 1e-3 then smoothed_speed / cycle_distance else 0

	-- note: the heaviest clip leads, the others follow its foot timing
	local leader: Gait? = nil
	for i, gait in gaits do
		if gait.track.Length > 0 and (not leader or gait.weight > leader.weight) then
			leader = gait
		end
    end
    
	if leader and leader.weight > 0.02 then
        local phase = (leader.track.TimePosition / leader.track.Length - leader.strike) % 1
        
		for i, gait in gaits do
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

	for i, gait in gaits do
		local length = gait.track.Length
		local playback = if length > 0 and cycles_per_second > 0
			then math.clamp(cycles_per_second * length, MIN_RATE, MAX_RATE)
            else 1
        
		setWeight(gait.track, gait.weight * group_weight)
		setSpeed(gait.track, playback)
	end

	-- note: idle with an occasional variation
	if idle_alt_timer > 0 then
		idle_alt_timer -= dt
    end
    
	idle_mix += ((if idle_alt_timer > 0 then 1 else 0) - idle_mix) * (1 - math.exp(-3 * dt))
	local idle_visible = idle_weight * group_weight
	setWeight(idle_main, idle_visible * (1 - idle_mix))
	setWeight(idle_alt, idle_visible * idle_mix)
end

--------------------------------------------------------------------
-- Start
--------------------------------------------------------------------

for i, gait in gaits do
	gait.track:Play(0, EPSILON, 1)
	sent_weights[gait.track] = EPSILON
end

idle_main:Play(0.1, 1, 1)
sent_weights[idle_main] = 1
idle_alt:Play(0, EPSILON, 1)
sent_weights[idle_alt] = EPSILON
refreshTool()

local step_signal: RBXScriptSignal = run_service.Heartbeat
pcall(function()
	step_signal = (run_service :: any).PreAnimation
end)

step_signal:Connect(update)