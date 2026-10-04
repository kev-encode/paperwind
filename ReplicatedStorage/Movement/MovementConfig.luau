--!strict
--[[
	MovementConfig
	Tuning values for Paperwind's player movement (MovementController) and locomotion
	animation (Animate). Everything a designer might tweak lives here.

	Speeds are in studs/second. Feel target: Nico's Nextbots-style momentum, without
	bunny-hop speed gain.
]]

local MovementConfig = {}

MovementConfig.Speed = {
	Walk = 20,
	Sprint = 40,
	-- Seconds for the top speed to ramp between walk and sprint.
	SprintRampTime = 0.25,
}

MovementConfig.Ground = {
	-- How hard the character pushes toward the wanted speed (higher = snappier starts/turns).
	Acceleration = 12,
	-- How quickly the character slows down when not pushing (higher = shorter stops).
	Friction = 8,
	-- Below this speed friction acts as if moving at this speed, so stops end crisply.
	StopSpeed = 6,
}

MovementConfig.Air = {
	-- Air steering strength. Air control can redirect momentum but never adds speed (no b-hop gain).
	Acceleration = 3,
	-- Extra gravity while falling, for snappier jump arcs. 1 = normal gravity.
	FallGravityMultiplier = 1.3,
	MaxFallSpeed = 160,
}

MovementConfig.Jump = {
	Height = 7.5,
	-- Grace period to still jump after running off a ledge.
	CoyoteTime = 0.12,
	-- A jump pressed this long before landing still fires on touchdown.
	BufferTime = 0.12,
	-- Fraction of horizontal speed kept on landing. Below 1 makes chained hops slower than running.
	LandingSpeedKeep = 0.9,
}

MovementConfig.Camera = {
	BaseFOV = 70,
	-- Reached at full sprint speed.
	SprintFOV = 90,
	-- FOV smoothing; higher reacts faster.
	FOVResponse = 7,
	-- Max camera dip (studs) on a hard landing.
	LandingDip = 0.45,
}

MovementConfig.Input = {
	-- Hold to sprint.
	SprintHoldKeys = { Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift },
	-- Press to toggle sprint (gamepad stick click). Touch devices get an on-screen toggle button.
	SprintToggleKeys = { Enum.KeyCode.ButtonL3 },
	-- A toggled sprint switches off after the player stops moving for this long (seconds).
	SprintToggleIdleCancel = 0.6,
}

--[[
	Locomotion animations (Roblox-made clips, loadable in any experience).
	NaturalSpeed: studs/s the clip's feet travel at playback speed 1 on a HipHeight-2 character,
	measured from the clip's keyframes on an R15 avatar. StrikePhase: normalized clip time where
	the right foot plants. Animate plays each clip at the rate that keeps its feet planted, and only
	cross-fades (phase-synced) inside the GaitBands below. Re-measure both values if a clip is swapped.
]]
MovementConfig.GaitBands = {
	-- World speeds (studs/s) where one clip cross-fades into the next. Walk speed (18) sits on
	-- pure Run and sprint speed (30) on pure Sprint, so both look clean.
	WalkToRun = { 8, 11 },
	RunToSprint = { 22, 27 },
}

MovementConfig.Animations = {
	Idle = {
		{ Id = "rbxassetid://18537376492", Weight = 9 }, -- adidas Sports idle
		{ Id = "rbxassetid://18537371272", Weight = 1 }, -- adidas Sports idle (variation)
	},
	Walk = { Id = "rbxassetid://913402848", NaturalSpeed = 5.6, StrikePhase = 0.730 }, -- Roblox R15 walk
	Run = { Id = "rbxassetid://913376220", NaturalSpeed = 12.8, StrikePhase = 0.747 }, -- Roblox R15 run
	Sprint = { Id = "rbxassetid://18537384940", NaturalSpeed = 27.6, StrikePhase = 0.180 }, -- adidas Sports run
	Jump = { Id = "rbxassetid://119846112151352" }, -- NFL jump
	Fall = { Id = "rbxassetid://129773241321032" }, -- NFL fall
	Climb = { Id = "rbxassetid://507765644" },
	Swim = { Id = "rbxassetid://913384386" },
	SwimIdle = { Id = "rbxassetid://913389285" },
	Sit = { Id = "rbxassetid://2506281703" },
	ToolNone = { Id = "rbxassetid://507768375" },
	ToolSlash = { Id = "rbxassetid://522635514" },
	ToolLunge = { Id = "rbxassetid://522638767" },
}

-- Default Roblox emotes (emote wheel and /e commands). Looped emotes play until the player moves.
MovementConfig.Emotes = {
	wave = { Ids = { "rbxassetid://507770239" }, Looped = false },
	point = { Ids = { "rbxassetid://507770453" }, Looped = false },
	dance = { Ids = { "rbxassetid://507771019", "rbxassetid://507771955", "rbxassetid://507772104" }, Looped = true },
	dance2 = { Ids = { "rbxassetid://507776043", "rbxassetid://507776720", "rbxassetid://507776879" }, Looped = true },
	dance3 = { Ids = { "rbxassetid://507777268", "rbxassetid://507777451", "rbxassetid://507777623" }, Looped = true },
	laugh = { Ids = { "rbxassetid://507770818" }, Looped = false },
	cheer = { Ids = { "rbxassetid://507770677" }, Looped = false },
}

return MovementConfig