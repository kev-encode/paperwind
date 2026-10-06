--!strict
--[[
	MovementController
	What: momentum-based walk, sprint, and jump for the local character
	How: runs right after the PlayerModule each frame, smooths velocity, then re-issues Humanoid:Move() and WalkSpeed; the camera tilt runs after the camera updates
	Rules: air control never adds speed and landings shed speed, so b-hopping is never faster than running
	Extras: sprint FOV, strafe camera tilt, coyote time, jump buffer, faster falls, landing camera dip, touch sprint button
	Reads: SpeedMultiplier (number), MovementDisabled (boolean) character attributes
	Writes: Sprinting (boolean) character attribute
	Tuning: ReplicatedStorage.Movement.MovementConfig
]]

local players = game:GetService("Players")
local run_service = game:GetService("RunService")
local user_input_service = game:GetService("UserInputService")
local replicated_storage = game:GetService("ReplicatedStorage")
local starter_player = game:GetService("StarterPlayer")
local workspace = game:GetService("Workspace")
local config = require(replicated_storage:WaitForChild("Movement"):WaitForChild("MovementConfig"))

local player = players.LocalPlayer
local STATE = Enum.HumanoidStateType
local GROUND_STATES = {
	[STATE.Running] = true,
	[STATE.RunningNoPhysics] = true,
	[STATE.Landed] = true,
}

local AIR_STATES = {
	[STATE.Jumping] = true,
	[STATE.Freefall] = true,
}

local LANDING_SPRING = 150 -- note: stiffness of the landing camera dip
local LANDING_DAMPING = 2 * math.sqrt(LANDING_SPRING) -- note: critically damped

--------------------------------------------------------------------
-- Character state
--------------------------------------------------------------------

local character: Model? = nil
local humanoid: Humanoid? = nil
local root_part: BasePart? = nil
local connections: { RBXScriptConnection } = {}
local velocity = Vector3.zero -- note: horizontal velocity the controller drives
local speed_cap = config.speed.walk
local last_grounded = 0
local jumped = false -- note: jumped since last touching the ground
local fall_speed = 0 -- note: last vertical speed while airborne
local dip_position = 0
local dip_velocity = 0
local dip_active = false
local fov = config.camera.fov
local tilt = 0 -- note: current camera roll in degrees, positive leans right
local sprint_attribute = false

--------------------------------------------------------------------
-- Input
--------------------------------------------------------------------

local sprint_held = false
local sprint_toggled = false
local toggle_used = false -- note: the player has moved since toggling sprint on
local idle_time = 0
local last_jump_press = -math.huge
local handled_jump_press = -math.huge
local move_action: InputAction? = nil
local jump_hooked = false
local touch_button: ImageButton? = nil

-- note: the playermodule exposes input as inputactions, so keyboard, gamepad and touch all work
local function hookCharacterActions()
	if move_action then
		return
	end

	local player_module = starter_player:FindFirstChild("PlayerModule")
	local contexts = player_module and player_module:FindFirstChild("InputContexts")

	local character_context = contexts and contexts:FindFirstChild("CharacterContext")
	if not character_context then
		return
	end

	move_action = character_context:FindFirstChild("MoveAction") :: InputAction?

	local jump_action = character_context:FindFirstChild("JumpAction") :: InputAction?
	if jump_action and not jump_hooked then
		jump_hooked = true

		jump_action.Pressed:Connect(function()
			last_jump_press = os.clock()
		end)
	end
end

-- note: camera-relative input (x right, y forward) to a flat world vector
local function cameraRelativeToWorld(input: Vector2): Vector3
	local camera = workspace.CurrentCamera
	if not camera or input.Magnitude < 1e-3 then
		return Vector3.zero
	end

	local _, _, _, r00, r01, r02, _, _, r12, _, _, r22 = camera.CFrame:GetComponents()
	local cos = 0
	local sin = 0

	if r12 < 1 and r12 > -1 then
		cos = r22
		sin = r02

	else
		cos = r00
		sin = -r01 * math.sign(r12)
	end

	local norm = math.sqrt(cos * cos + sin * sin)
	local x = input.X
	local z = -input.Y

	return Vector3.new((cos * x + sin * z) / norm, 0, (cos * z - sin * x) / norm)
end

local function readMoveInput(hum: Humanoid): Vector3
	if user_input_service:GetFocusedTextBox() then
		return Vector3.zero
	end

	hookCharacterActions()

	if move_action then
		local value = move_action:GetState()
		if typeof(value) == "Vector2" then
			return cameraRelativeToWorld(value)
		end
	end

	-- note: fallback for the classic playermodule, which already called move() this frame
	local direction = hum.MoveDirection
	return Vector3.new(direction.X, 0, direction.Z)
end

--------------------------------------------------------------------
-- Sprint input
--------------------------------------------------------------------

local function updateTouchButtonLook()
	if not touch_button then
		return
	end

	touch_button.BackgroundColor3 = if sprint_toggled then Color3.fromRGB(255, 186, 60) else Color3.fromRGB(20, 20, 20)
	touch_button.BackgroundTransparency = if sprint_toggled then 0.15 else 0.45
end

local function setSprintToggled(on: boolean)
	sprint_toggled = on
	toggle_used = false
	updateTouchButtonLook()
end

local function createSprintInput(): InputAction
	local context = Instance.new("InputContext")
	context.Name = "MovementInput"
	context.Priority = 2000

	pcall(function()
		(context :: any).Sink = false
	end)

	local hold = Instance.new("InputAction")
	hold.Name = "SprintHold"
	hold.Type = Enum.InputActionType.Bool

	for _, key in config.input.sprint_hold do
		local binding = Instance.new("InputBinding")
		binding.KeyCode = key
		binding.Parent = hold
	end

	hold.Parent = context

	local toggle = Instance.new("InputAction")
	toggle.Name = "SprintToggle"
	toggle.Type = Enum.InputActionType.Bool

	for _, key in config.input.sprint_toggle do
		local binding = Instance.new("InputBinding")
		binding.KeyCode = key
		binding.Parent = toggle
	end

	toggle.Parent = context

	hold.StateChanged:Connect(function(value)
		sprint_held = value == true
	end)

	toggle.Pressed:Connect(function()
		idle_time = 0
		setSprintToggled(not sprint_toggled)
	end)

	context.Parent = script
	return toggle
end

local function layoutTouchButton()
	if not touch_button then
		return
	end

	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1024, 768)
	local small = math.min(viewport.X, viewport.Y) <= 500
	-- note: up and to the left of roblox's touch jump button
	local size = if small then 54 else 84
	local center = if small then Vector2.new(-138, -78) else Vector2.new(-232, -150)
	touch_button.Size = UDim2.fromOffset(size, size)
	touch_button.Position = UDim2.new(1, center.X, 1, center.Y)
end

local function createTouchSprintButton(toggle_action: InputAction)
	local gui = Instance.new("ScreenGui")
	gui.Name = "SprintTouchGui"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.DisplayOrder = 5

	local button = Instance.new("ImageButton")
	button.Name = "SprintButton"
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.AutoButtonColor = false
	button.Image = ""
	button.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 2
	stroke.Transparency = 0.35
	stroke.Parent = button

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.72, 0.36)
	label.Font = Enum.Font.GothamBold
	label.Text = "SPRINT"
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = button

	local binding = Instance.new("InputBinding")
	binding.Name = "TouchButtonBinding"
	binding.UIButton = button
	binding.Parent = toggle_action

	touch_button = button
	layoutTouchButton()
	updateTouchButtonLook()

	local function refreshVisibility()
		gui.Enabled = user_input_service.PreferredInput == Enum.PreferredInput.Touch
	end

	refreshVisibility()
	user_input_service:GetPropertyChangedSignal("PreferredInput"):Connect(refreshVisibility)

	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutTouchButton)
	end

	gui.Parent = player:WaitForChild("PlayerGui") -- note: `player:WaitForChild` is marked as an error in IDE
end

--------------------------------------------------------------------
-- Velocity model
--------------------------------------------------------------------

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function approach(current: number, target: number, step_size: number): number
	if current < target then
		return math.min(current + step_size, target)
	end

	return math.max(current - step_size, target)
end

local function applyFriction(current: Vector3, dt: number): Vector3
	local speed = current.Magnitude
	if speed < 1e-3 then
		return Vector3.zero
	end

	local control = math.max(speed, config.ground.stop_speed)
	local new_speed = math.max(speed - control * config.ground.friction * dt, 0)
	return current * (new_speed / speed)
end

local function accelerate(current: Vector3, direction: Vector3, wish_speed: number, acceleration: number, dt: number): Vector3
	if wish_speed <= 0 then
		return current
	end

	local add_speed = wish_speed - current:Dot(direction)
	if add_speed <= 0 then
		return current
	end

	return current + direction * math.min(acceleration * wish_speed * dt, add_speed)
end

--------------------------------------------------------------------
-- Jumping
--------------------------------------------------------------------

local function forceJump(hum: Humanoid, root: BasePart)
	jumped = true
	pcall(function()
		hum:ChangeState(STATE.Jumping)
	end)

	local current = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(current.X, math.sqrt(2 * workspace.Gravity * hum.JumpHeight), current.Z)
end

local function handleJumpInput(hum: Humanoid, root: BasePart, state: Enum.HumanoidStateType, grounded: boolean, now: number)
	if last_jump_press <= handled_jump_press then
		return
	end

	local age = now - last_jump_press

	if grounded and age <= config.jump.buffer_time then
		-- note: a fresh press, or one buffered just before touchdown
		hum.Jump = true
		handled_jump_press = last_jump_press

	elseif state == STATE.Freefall and not jumped and now - last_grounded <= config.jump.coyote_time then
		-- note: coyote time, ran off a ledge a moment ago
		forceJump(hum, root)
		handled_jump_press = last_jump_press

	elseif age > config.jump.buffer_time then
		handled_jump_press = last_jump_press
	end
end

local function onStateChanged(old: Enum.HumanoidStateType, new: Enum.HumanoidStateType)
	if new == STATE.Jumping then
		jumped = true

	elseif GROUND_STATES[new] then
		jumped = false
		if AIR_STATES[old] then
			-- note: landing sheds a little speed and dips the camera on hard landings
			velocity *= config.jump.landing_keep
			local strength = math.clamp((-fall_speed - 30) / 70, 0, 1)
			if strength > 0 then
				dip_velocity -= config.camera.landing_dip * strength * math.sqrt(LANDING_SPRING) * math.exp(1)
				dip_active = true
			end
		end
	end
end

--------------------------------------------------------------------
-- Camera
--------------------------------------------------------------------

local function updateCamera(hum: Humanoid, root: BasePart, dt: number)
	local camera = workspace.CurrentCamera
	if camera then
		local speed = flat(root.AssemblyLinearVelocity).Magnitude
		local span = math.max(config.speed.sprint - config.speed.walk, 1)
		local blend = math.clamp((speed - config.speed.walk) / span, 0, 1)
		local target = config.camera.fov + (config.camera.sprint_fov - config.camera.fov) * blend
		fov += (target - fov) * (1 - math.exp(-config.camera.fov_response * dt))
		camera.FieldOfView = fov
	end

	if dip_active then
		local acceleration = -LANDING_SPRING * dip_position - LANDING_DAMPING * dip_velocity
		dip_velocity += acceleration * dt
		dip_position += dip_velocity * dt

		if math.abs(dip_position) < 1e-3 and math.abs(dip_velocity) < 1e-2 then
			dip_position = 0
			dip_velocity = 0
			dip_active = false
		end

		hum.CameraOffset = Vector3.new(0, dip_position, 0)
	end
end

-- note: strafe roll like quake and nico's nextbots, the view leans into sideways movement
local function applyCameraTilt(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	-- note: only the default camera rebuilds its view every frame, so scripted cameras are left alone
	if camera.CameraType ~= Enum.CameraType.Custom then
		tilt = 0
		return
	end

	dt = math.min(dt, 1 / 15)

	local view = camera.CFrame
	local level_view = CFrame.lookAt(view.Position, view.Position + view.LookVector)

	local target = 0
	local hum = humanoid
	local root = root_part
	local char = character
	if hum and root and char and hum.Health > 0 and char:GetAttribute("MovementDisabled") ~= true then
		-- note: walking, running and airborne only, climbing, swimming and seated settle back to level
		local state = hum:GetState()
		if GROUND_STATES[state] or AIR_STATES[state] then
			local side_speed = flat(root.AssemblyLinearVelocity):Dot(level_view.RightVector)
			local amount = math.clamp(side_speed / math.max(config.camera.tilt_speed, 1), -1, 1)
			target = amount * config.camera.tilt
		end
	end

	tilt += (target - tilt) * (1 - math.exp(-config.camera.tilt_response * dt))
	if math.abs(tilt) < 1e-3 then
		return
	end

	-- note: the roll goes on a level copy of the view, so a frame the camera skips can't stack it
	camera.CFrame = level_view * CFrame.Angles(0, 0, math.rad(-tilt))
end

--------------------------------------------------------------------
-- Per-frame update
--------------------------------------------------------------------

local function step(dt: number)
	local hum = humanoid
	local root = root_part
	local char = character
	if not hum or not root or not char or hum.Health <= 0 then
		return
	end

	dt = math.min(dt, 1 / 15)
	local now = os.clock()
	local state = hum:GetState()

	local grounded = GROUND_STATES[state] == true
	if grounded then
		last_grounded = now
	end

	local wish = readMoveInput(hum)
	local amount = math.min(wish.Magnitude, 1)
	local direction = if amount > 1e-3 then wish.Unit else Vector3.zero

	-- note: a toggled sprint ends once the player stops after moving with it
	idle_time = if amount < 0.1 then idle_time + dt else 0
	if sprint_toggled and amount >= 0.1 then
		toggle_used = true
	end

	if sprint_toggled and toggle_used and idle_time > config.input.toggle_idle_cancel then
		setSprintToggled(false)
	end

	local sprinting = (sprint_held or sprint_toggled) and amount > 0.1
	if sprinting ~= sprint_attribute then
		sprint_attribute = sprinting
		char:SetAttribute("Sprinting", sprinting)
	end

	local multiplier = char:GetAttribute("SpeedMultiplier")
	local scale = if typeof(multiplier) == "number" then math.max(multiplier, 0) else 1
	local target_cap = (if sprinting then config.speed.sprint else config.speed.walk) * scale
	local ramp_rate = (config.speed.sprint - config.speed.walk) / math.max(config.speed.sprint_ramp, 1e-3)
	speed_cap = approach(speed_cap, target_cap, ramp_rate * dt)

	updateCamera(hum, root, dt)

	if char:GetAttribute("MovementDisabled") == true or not (grounded or AIR_STATES[state]) then
		-- note: climbing, swimming, seated and similar use default humanoid behaviour
		hum.WalkSpeed = speed_cap
		velocity = flat(root.AssemblyLinearVelocity)
		return
	end

	handleJumpInput(hum, root, state, grounded, now)

	-- note: don't bank speed while pushing into a wall
	local actual = flat(root.AssemblyLinearVelocity)

	local speed = velocity.Magnitude
	if speed > 4 and actual:Dot(velocity / speed) < speed * 0.5 then
		velocity = velocity:Lerp(actual, 1 - math.exp(-12 * dt))
	end

	local wish_speed = speed_cap * amount

	if grounded then
		velocity = applyFriction(velocity, dt)
		velocity = accelerate(velocity, direction, wish_speed, config.ground.acceleration, dt)

	else
		-- note: air steers only, speed can't pass what you had or your top speed
		local before = velocity.Magnitude
		velocity = accelerate(velocity, direction, wish_speed, config.air.acceleration, dt)
		local limit = math.max(before, wish_speed)

		local after = velocity.Magnitude
		if after > limit then
			velocity *= limit / after
		end
	end

	speed = velocity.Magnitude
	if speed < 0.05 then
		velocity = Vector3.zero
		hum.WalkSpeed = speed_cap
		hum:Move(Vector3.zero, false)

	else
		hum.WalkSpeed = speed
		hum:Move(velocity / speed, false)
	end
end

-- note: extra gravity on the way down for snappier jump arcs
local function applyFallGravity(dt: number)
	local hum = humanoid
	local root = root_part
	local char = character
	if not hum or not root or not char or hum.Health <= 0 then
		return
	end

	if not AIR_STATES[hum:GetState()] or char:GetAttribute("MovementDisabled") == true then
		return
	end

	local current = root.AssemblyLinearVelocity
	fall_speed = current.Y

	if current.Y < 0 and config.air.fall_gravity ~= 1 then
		local y = current.Y - (config.air.fall_gravity - 1) * workspace.Gravity * dt
		root.AssemblyLinearVelocity = Vector3.new(current.X, math.max(y, -config.air.max_fall_speed), current.Z)
	end
end

--------------------------------------------------------------------
-- Character lifecycle
--------------------------------------------------------------------

local function onCharacterAdded(new_character: Model)
	for _, connection in connections do
		connection:Disconnect()
	end

	table.clear(connections)

	character = new_character
	humanoid = nil
	root_part = nil
	local hum = new_character:WaitForChild("Humanoid") :: Humanoid
	local root = new_character:WaitForChild("HumanoidRootPart") :: BasePart
	if character ~= new_character then
		return -- note: respawned while waiting
	end

	humanoid = hum
	root_part = root
	hum.UseJumpPower = false
	hum.JumpHeight = config.jump.height
	hum.WalkSpeed = config.speed.walk

	velocity = Vector3.zero
	speed_cap = config.speed.walk
	jumped = false
	dip_position = 0
	dip_velocity = 0
	dip_active = false
	sprint_attribute = false
	new_character:SetAttribute("Sprinting", false)

	table.insert(connections, hum.StateChanged:Connect(onStateChanged))
end

local function onCharacterRemoving(old_character: Model)
	if old_character == character then
		character = nil
		humanoid = nil
		root_part = nil
	end
end

--------------------------------------------------------------------
-- Start
--------------------------------------------------------------------

local toggle_action = createSprintInput()
task.spawn(createTouchSprintButton, toggle_action)

user_input_service.JumpRequest:Connect(function()
	if not jump_hooked then
		last_jump_press = os.clock()
	end
end)

player.CharacterAdded:Connect(onCharacterAdded) -- note: `player.CharacterAdded` is marked as an error in IDE
player.CharacterRemoving:Connect(onCharacterRemoving) -- note: `player.CharacterRemoving` is marked as an error in IDE

if player.Character then -- note: `player.Character` is marked as an error in IDE
	task.spawn(onCharacterAdded, player.Character)
end

run_service:BindToRenderStep("PaperwindMovement", Enum.RenderPriority.Input.Value + 1, step)
run_service:BindToRenderStep("PaperwindCameraTilt", Enum.RenderPriority.Camera.Value + 1, applyCameraTilt)
run_service.PreSimulation:Connect(applyFallGravity)