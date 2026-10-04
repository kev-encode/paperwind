--!strict
--[[
	MovementController
	Momentum-based walking, sprinting and jumping for the local character.

	How it works
	- Roblox's PlayerModule still reads input and calls Humanoid:Move() every frame.
	- Right after it (RenderPriority.Input + 1) this script reads the same raw input, runs a
	  Source-style velocity model (acceleration, friction, limited air control), then re-issues
	  Humanoid:Move() and WalkSpeed with the smoothed result.
	- Air control can steer but never adds speed, and landings shed a little speed, so bunny
	  hopping is never faster than running.
	- Extras: sprint FOV kick, coyote time, jump buffering, snappier falls, landing camera dip,
	  and a sprint toggle button on touch devices.

	Character attributes (optional hooks for other systems)
	  SpeedMultiplier (number, read)   - scales walk and sprint speed, e.g. slows or buffs.
	  MovementDisabled (boolean, read) - hands control back to the default Humanoid behaviour.
	  Sprinting (boolean, written)     - true while the player is sprinting.

	Tuning lives in ReplicatedStorage.Movement.MovementConfig.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Movement"):WaitForChild("MovementConfig"))

local player = Players.LocalPlayer
local State = Enum.HumanoidStateType

local GROUND_STATES = {
	[State.Running] = true,
	[State.RunningNoPhysics] = true,
	[State.Landed] = true,
}
local AIR_STATES = {
	[State.Jumping] = true,
	[State.Freefall] = true,
}

local LANDING_SPRING = 150 -- stiffness of the landing camera-dip spring
local LANDING_DAMPING = 2 * math.sqrt(LANDING_SPRING) -- critically damped

-- Character state -------------------------------------------------------------

local character: Model? = nil
local humanoid: Humanoid? = nil
local rootPart: BasePart? = nil
local characterConnections: { RBXScriptConnection } = {}

local velocity = Vector3.zero -- horizontal velocity the controller is driving
local speedCap = Config.Speed.Walk
local lastGroundedTime = 0
local jumpedSinceGrounded = false
local lastAirVerticalSpeed = 0
local dipPosition, dipVelocity = 0, 0
local dipActive = false
local fieldOfView = Config.Camera.BaseFOV
local sprintingAttribute = false

-- Input -----------------------------------------------------------------------

local sprintHeld = false
local sprintToggled = false
local sprintToggleUsed = false -- the player has moved since toggling sprint on
local idleTime = 0
local lastJumpPressTime = -math.huge
local handledJumpPressTime = -math.huge

local moveAction: InputAction? = nil
local jumpActionHooked = false

local touchButton: ImageButton? = nil

-- The PlayerModule exposes its input as InputActions; read them directly so this works for
-- keyboard, gamepad and touch thumbsticks alike.
local function hookCharacterActions()
	if moveAction then
		return
	end
	local playerModule = StarterPlayer:FindFirstChild("PlayerModule")
	local contexts = playerModule and playerModule:FindFirstChild("InputContexts")
	local characterContext = contexts and contexts:FindFirstChild("CharacterContext")
	if not characterContext then
		return
	end
	moveAction = characterContext:FindFirstChild("MoveAction") :: InputAction?
	local jumpAction = characterContext:FindFirstChild("JumpAction") :: InputAction?
	if jumpAction and not jumpActionHooked then
		jumpActionHooked = true
		jumpAction.Pressed:Connect(function()
			lastJumpPressTime = os.clock()
		end)
	end
end

-- Camera-relative input (X = right, Y = forward) to a flat world-space vector.
local function cameraRelativeToWorld(input: Vector2): Vector3
	local camera = Workspace.CurrentCamera
	if not camera or input.Magnitude < 1e-3 then
		return Vector3.zero
	end
	local _, _, _, r00, r01, r02, _, _, r12, _, _, r22 = camera.CFrame:GetComponents()
	local c, s
	if r12 < 1 and r12 > -1 then
		c, s = r22, r02
	else
		c, s = r00, -r01 * math.sign(r12)
	end
	local norm = math.sqrt(c * c + s * s)
	local x, z = input.X, -input.Y
	return Vector3.new((c * x + s * z) / norm, 0, (c * z - s * x) / norm)
end

local function readMoveInput(hum: Humanoid): Vector3
	if UserInputService:GetFocusedTextBox() then
		return Vector3.zero
	end
	hookCharacterActions()
	if moveAction then
		local value = moveAction:GetState()
		if typeof(value) == "Vector2" then
			return cameraRelativeToWorld(value)
		end
	end
	-- Fallback for the classic PlayerModule, which already called Move() this frame.
	local direction = hum.MoveDirection
	return Vector3.new(direction.X, 0, direction.Z)
end

-- Sprint input ----------------------------------------------------------------

local function updateTouchButtonLook()
	if not touchButton then
		return
	end
	touchButton.BackgroundColor3 = if sprintToggled then Color3.fromRGB(255, 186, 60) else Color3.fromRGB(20, 20, 20)
	touchButton.BackgroundTransparency = if sprintToggled then 0.15 else 0.45
end

local function setSprintToggled(on: boolean)
	sprintToggled = on
	sprintToggleUsed = false
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
	for _, keyCode in Config.Input.SprintHoldKeys do
		local binding = Instance.new("InputBinding")
		binding.KeyCode = keyCode
		binding.Parent = hold
	end
	hold.Parent = context

	local toggle = Instance.new("InputAction")
	toggle.Name = "SprintToggle"
	toggle.Type = Enum.InputActionType.Bool
	for _, keyCode in Config.Input.SprintToggleKeys do
		local binding = Instance.new("InputBinding")
		binding.KeyCode = keyCode
		binding.Parent = toggle
	end
	toggle.Parent = context

	hold.StateChanged:Connect(function(value)
		sprintHeld = value == true
	end)
	toggle.Pressed:Connect(function()
		idleTime = 0
		setSprintToggled(not sprintToggled)
	end)

	context.Parent = script
	return toggle
end

local function layoutTouchButton()
	if not touchButton then
		return
	end
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1024, 768)
	local small = math.min(viewport.X, viewport.Y) <= 500
	-- Up and to the left of Roblox's touch jump button.
	local size = if small then 54 else 84
	local center = if small then Vector2.new(-138, -78) else Vector2.new(-232, -150)
	touchButton.Size = UDim2.fromOffset(size, size)
	touchButton.Position = UDim2.new(1, center.X, 1, center.Y)
end

local function createTouchSprintButton(toggleAction: InputAction)
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
	binding.Parent = toggleAction

	touchButton = button
	layoutTouchButton()
	updateTouchButtonLook()

	local function refreshVisibility()
		gui.Enabled = UserInputService.PreferredInput == Enum.PreferredInput.Touch
	end
	refreshVisibility()
	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(refreshVisibility)
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutTouchButton)
	end

	gui.Parent = player:WaitForChild("PlayerGui")
end

-- Velocity model --------------------------------------------------------------

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function approach(current: number, target: number, maxDelta: number): number
	if current < target then
		return math.min(current + maxDelta, target)
	end
	return math.max(current - maxDelta, target)
end

local function applyFriction(v: Vector3, dt: number): Vector3
	local speed = v.Magnitude
	if speed < 1e-3 then
		return Vector3.zero
	end
	local control = math.max(speed, Config.Ground.StopSpeed)
	local newSpeed = math.max(speed - control * Config.Ground.Friction * dt, 0)
	return v * (newSpeed / speed)
end

local function accelerate(v: Vector3, wishDirection: Vector3, wishSpeed: number, acceleration: number, dt: number): Vector3
	if wishSpeed <= 0 then
		return v
	end
	local addSpeed = wishSpeed - v:Dot(wishDirection)
	if addSpeed <= 0 then
		return v
	end
	return v + wishDirection * math.min(acceleration * wishSpeed * dt, addSpeed)
end

-- Jumping ---------------------------------------------------------------------

local function forceJump(hum: Humanoid, root: BasePart)
	jumpedSinceGrounded = true
	pcall(function()
		hum:ChangeState(State.Jumping)
	end)
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X, math.sqrt(2 * Workspace.Gravity * hum.JumpHeight), v.Z)
end

local function handleJumpInput(hum: Humanoid, root: BasePart, state: Enum.HumanoidStateType, grounded: boolean, now: number)
	if lastJumpPressTime <= handledJumpPressTime then
		return
	end
	local age = now - lastJumpPressTime
	if grounded and age <= Config.Jump.BufferTime then
		-- A fresh press, or one buffered just before touchdown.
		hum.Jump = true
		handledJumpPressTime = lastJumpPressTime
	elseif state == State.Freefall and not jumpedSinceGrounded and now - lastGroundedTime <= Config.Jump.CoyoteTime then
		-- Coyote time: ran off a ledge a moment ago.
		forceJump(hum, root)
		handledJumpPressTime = lastJumpPressTime
	elseif age > Config.Jump.BufferTime then
		handledJumpPressTime = lastJumpPressTime
	end
end

local function onStateChanged(old: Enum.HumanoidStateType, new: Enum.HumanoidStateType)
	if new == State.Jumping then
		jumpedSinceGrounded = true
	elseif GROUND_STATES[new] then
		jumpedSinceGrounded = false
		if AIR_STATES[old] then
			-- Landing: shed a little speed (no b-hop gain) and dip the camera on hard landings.
			velocity *= Config.Jump.LandingSpeedKeep
			local strength = math.clamp((-lastAirVerticalSpeed - 30) / 70, 0, 1)
			if strength > 0 then
				dipVelocity -= Config.Camera.LandingDip * strength * math.sqrt(LANDING_SPRING) * math.exp(1)
				dipActive = true
			end
		end
	end
end

-- Camera ----------------------------------------------------------------------

local function updateCamera(hum: Humanoid, root: BasePart, dt: number)
	local camera = Workspace.CurrentCamera
	if camera then
		local speed = flat(root.AssemblyLinearVelocity).Magnitude
		local span = math.max(Config.Speed.Sprint - Config.Speed.Walk, 1)
		local t = math.clamp((speed - Config.Speed.Walk) / span, 0, 1)
		local target = Config.Camera.BaseFOV + (Config.Camera.SprintFOV - Config.Camera.BaseFOV) * t
		fieldOfView += (target - fieldOfView) * (1 - math.exp(-Config.Camera.FOVResponse * dt))
		camera.FieldOfView = fieldOfView
	end

	if dipActive then
		local acceleration = -LANDING_SPRING * dipPosition - LANDING_DAMPING * dipVelocity
		dipVelocity += acceleration * dt
		dipPosition += dipVelocity * dt
		if math.abs(dipPosition) < 1e-3 and math.abs(dipVelocity) < 1e-2 then
			dipPosition, dipVelocity, dipActive = 0, 0, false
		end
		hum.CameraOffset = Vector3.new(0, dipPosition, 0)
	end
end

-- Per-frame update ------------------------------------------------------------

local function step(dt: number)
	local hum, root, char = humanoid, rootPart, character
	if not hum or not root or not char or hum.Health <= 0 then
		return
	end
	dt = math.min(dt, 1 / 15)
	local now = os.clock()
	local state = hum:GetState()
	local grounded = GROUND_STATES[state] == true
	if grounded then
		lastGroundedTime = now
	end

	local wish = readMoveInput(hum)
	local wishAmount = math.min(wish.Magnitude, 1)
	local wishDirection = if wishAmount > 1e-3 then wish.Unit else Vector3.zero

	-- Sprint (a toggled sprint ends once the player stops after having moved with it)
	idleTime = if wishAmount < 0.1 then idleTime + dt else 0
	if sprintToggled and wishAmount >= 0.1 then
		sprintToggleUsed = true
	end
	if sprintToggled and sprintToggleUsed and idleTime > Config.Input.SprintToggleIdleCancel then
		setSprintToggled(false)
	end
	local sprinting = (sprintHeld or sprintToggled) and wishAmount > 0.1
	if sprinting ~= sprintingAttribute then
		sprintingAttribute = sprinting
		char:SetAttribute("Sprinting", sprinting)
	end

	local multiplier = char:GetAttribute("SpeedMultiplier")
	local speedScale = if typeof(multiplier) == "number" then math.max(multiplier, 0) else 1
	local targetCap = (if sprinting then Config.Speed.Sprint else Config.Speed.Walk) * speedScale
	local rampRate = (Config.Speed.Sprint - Config.Speed.Walk) / math.max(Config.Speed.SprintRampTime, 1e-3)
	speedCap = approach(speedCap, targetCap, rampRate * dt)

	updateCamera(hum, root, dt)

	if char:GetAttribute("MovementDisabled") == true or not (grounded or AIR_STATES[state]) then
		-- Climbing, swimming, seated, ragdoll...: default Humanoid behaviour at the current top speed.
		hum.WalkSpeed = speedCap
		velocity = flat(root.AssemblyLinearVelocity)
		return
	end

	handleJumpInput(hum, root, state, grounded, now)

	-- Don't bank speed while pushing into a wall: bleed toward what the body is really doing.
	local actual = flat(root.AssemblyLinearVelocity)
	local speed = velocity.Magnitude
	if speed > 4 and actual:Dot(velocity / speed) < speed * 0.5 then
		velocity = velocity:Lerp(actual, 1 - math.exp(-12 * dt))
	end

	local wishSpeed = speedCap * wishAmount
	if grounded then
		velocity = applyFriction(velocity, dt)
		velocity = accelerate(velocity, wishDirection, wishSpeed, Config.Ground.Acceleration, dt)
	else
		-- Air: steer only. Speed can't grow past what you had, or your normal top speed.
		local before = velocity.Magnitude
		velocity = accelerate(velocity, wishDirection, wishSpeed, Config.Air.Acceleration, dt)
		local limit = math.max(before, wishSpeed)
		local after = velocity.Magnitude
		if after > limit then
			velocity *= limit / after
		end
	end

	speed = velocity.Magnitude
	if speed < 0.05 then
		velocity = Vector3.zero
		hum.WalkSpeed = speedCap
		hum:Move(Vector3.zero, false)
	else
		hum.WalkSpeed = speed
		hum:Move(velocity / speed, false)
	end
end

-- Snappier jump arcs: extra gravity on the way down.
local function applyFallGravity(dt: number)
	local hum, root, char = humanoid, rootPart, character
	if not hum or not root or not char or hum.Health <= 0 then
		return
	end
	if not AIR_STATES[hum:GetState()] or char:GetAttribute("MovementDisabled") == true then
		return
	end
	local v = root.AssemblyLinearVelocity
	lastAirVerticalSpeed = v.Y
	if v.Y < 0 and Config.Air.FallGravityMultiplier ~= 1 then
		local y = v.Y - (Config.Air.FallGravityMultiplier - 1) * Workspace.Gravity * dt
		root.AssemblyLinearVelocity = Vector3.new(v.X, math.max(y, -Config.Air.MaxFallSpeed), v.Z)
	end
end

-- Character lifecycle ---------------------------------------------------------

local function onCharacterAdded(newCharacter: Model)
	for _, connection in characterConnections do
		connection:Disconnect()
	end
	table.clear(characterConnections)

	character, humanoid, rootPart = newCharacter, nil, nil
	local hum = newCharacter:WaitForChild("Humanoid") :: Humanoid
	local root = newCharacter:WaitForChild("HumanoidRootPart") :: BasePart
	if character ~= newCharacter then
		return -- respawned while waiting
	end
	humanoid, rootPart = hum, root

	hum.UseJumpPower = false
	hum.JumpHeight = Config.Jump.Height
	hum.WalkSpeed = Config.Speed.Walk

	velocity = Vector3.zero
	speedCap = Config.Speed.Walk
	jumpedSinceGrounded = false
	dipPosition, dipVelocity, dipActive = 0, 0, false
	sprintingAttribute = false
	newCharacter:SetAttribute("Sprinting", false)

	table.insert(characterConnections, hum.StateChanged:Connect(onStateChanged))
end

local function onCharacterRemoving(oldCharacter: Model)
	if oldCharacter == character then
		character, humanoid, rootPart = nil, nil, nil
	end
end

-- Startup ---------------------------------------------------------------------

local sprintToggleAction = createSprintInput()
task.spawn(createTouchSprintButton, sprintToggleAction)

UserInputService.JumpRequest:Connect(function()
	if not jumpActionHooked then
		lastJumpPressTime = os.clock()
	end
end)

player.CharacterAdded:Connect(onCharacterAdded)
player.CharacterRemoving:Connect(onCharacterRemoving)
if player.Character then
	task.spawn(onCharacterAdded, player.Character)
end

RunService:BindToRenderStep("PaperwindMovement", Enum.RenderPriority.Input.Value + 1, step)
RunService.PreSimulation:Connect(applyFallGravity)
