--!strict
--[[
	MovementConfig
	What: tuning values for player movement and locomotion animation
	Used by: MovementController, Animate
	Units: speeds in studs/second
]]

local config = {}

config.speed = {
	walk = 20,
	sprint = 30,
	sprint_ramp = 0.25, -- note: seconds to ramp between walk and sprint
}

config.ground = {
	acceleration = 12, -- note: higher means snappier starts and turns
	friction = 8, -- note: higher means shorter stops
	stop_speed = 6, -- note: friction floor so stops end crisply
}

config.air = {
	acceleration = 3, -- note: steers momentum but never adds speed
	fall_gravity = 1.3, -- note: gravity multiplier while falling, 1 is normal
	max_fall_speed = 160,
}

config.jump = {
	height = 7.5,
	coyote_time = 0.12, -- note: grace period to jump after leaving a ledge
	buffer_time = 0.12, -- note: early presses still fire on landing
	landing_keep = 0.9, -- note: share of speed kept on landing, below 1 stops b-hop gain
}

config.camera = {
	fov = 70,
	sprint_fov = 90, -- note: reached at full sprint
	fov_response = 7, -- note: higher reacts faster
	landing_dip = 0.45, -- note: max dip in studs on hard landings
}

config.input = {
	sprint_hold = { Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift }, -- note: hold to sprint
	sprint_toggle = { Enum.KeyCode.ButtonL3 }, -- note: gamepad stick click, touch gets a button
	toggle_idle_cancel = 0.6, -- note: a toggled sprint ends after this long standing still
}

-- note: speeds where one gait clip cross-fades into the next; walk and sprint speeds sit on pure clips
config.gait_bands = {
	walk_to_run = { 8, 11 },
	run_to_sprint = { 22, 27 },
}

-- note: natural_speed is studs/s at playback 1 on a hip height 2 rig; strike_phase is when the right foot plants
-- todo: re-measure both values if a clip is swapped
config.animations = {
	idle = {
		{ id = "rbxassetid://18537376492", weight = 9 }, -- note: adidas sports idle
		{ id = "rbxassetid://18537371272", weight = 1 }, -- note: adidas sports idle variation
	},
	
	walk = { id = "rbxassetid://913402848", natural_speed = 5.6, strike_phase = 0.730 }, -- note: roblox r15 walk
	run = { id = "rbxassetid://913376220", natural_speed = 12.8, strike_phase = 0.747 }, -- note: roblox r15 run
	sprint = { id = "rbxassetid://18537384940", natural_speed = 27.6, strike_phase = 0.180 }, -- note: adidas sports run
	jump = { id = "rbxassetid://119846112151352" }, -- note: nfl jump
	fall = { id = "rbxassetid://129773241321032" }, -- note: nfl fall
	climb = { id = "rbxassetid://507765644" },
	swim = { id = "rbxassetid://913384386" },
	swim_idle = { id = "rbxassetid://913389285" },
	sit = { id = "rbxassetid://2506281703" },
	tool_none = { id = "rbxassetid://507768375" },
	tool_slash = { id = "rbxassetid://522635514" },
	tool_lunge = { id = "rbxassetid://522638767" },
}

-- note: default roblox emotes; looped ones play until the player moves
config.emotes = {
	wave = { ids = { "rbxassetid://507770239" }, looped = false },
	point = { ids = { "rbxassetid://507770453" }, looped = false },
	dance = { ids = { "rbxassetid://507771019", "rbxassetid://507771955", "rbxassetid://507772104" }, looped = true },
	dance2 = { ids = { "rbxassetid://507776043", "rbxassetid://507776720", "rbxassetid://507776879" }, looped = true },
	dance3 = { ids = { "rbxassetid://507777268", "rbxassetid://507777451", "rbxassetid://507777623" }, looped = true },
	laugh = { ids = { "rbxassetid://507770818" }, looped = false },
	cheer = { ids = { "rbxassetid://507770677" }, looped = false },
}

return config