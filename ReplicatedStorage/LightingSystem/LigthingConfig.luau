--!strict
--[[
	LightingConfig
	What: global lighting settings, day/night timing, and time-of-day keyframes
	Keyframes: key moments on the 24h clock; LightingBlender eases between them; each must list the same properties
	Preview: require(game.ReplicatedStorage.LightingSystem.LightingBlender).preview(17.5)
]]

local rgb = Color3.fromRGB
local config = {}

--------------------------------------------------------------------
-- Fixed look (not time-dependent)
--------------------------------------------------------------------

config.global = {
	LightingStyle = Enum.LightingStyle.Realistic,
	PrioritizeLightingQuality = true,
	-- note: noon sun ~63 degrees high in the south, it sets over the west pass
	GeographicLatitude = 50,
	EnvironmentDiffuseScale = 1,
	EnvironmentSpecularScale = 1,
	GlobalShadows = true,
}

-- note: properties per object that never change with time
config.static = {
	Sky = {
		SkyboxBk = "rbxassetid://6444884337",
		SkyboxDn = "rbxassetid://6444884785",
		SkyboxFt = "rbxassetid://6444884337",
		SkyboxLf = "rbxassetid://6444884337",
		SkyboxRt = "rbxassetid://6444884337",
		SkyboxUp = "rbxassetid://6412503613",
		SunTextureId = "rbxassetid://6196665106",
		MoonTextureId = "rbxassetid://6444320592",
		SunAngularSize = 11,
		MoonAngularSize = 9,
		StarCount = 3000,
		CelestialBodiesShown = true,
	},
	
	Bloom = { Size = 24 },
	-- note: only far scenery softens, nothing near the player blurs
	DepthOfField = {
		FocusDistance = 60,
		InFocusRadius = 70,
		NearIntensity = 0,
	},
}

--------------------------------------------------------------------
-- Day/night timing
--------------------------------------------------------------------

config.cycle = {
	day_length = 12, -- note: one full 24h day, in real minutes
	start_time = 9, -- note: clock time when a server starts
	-- note: daylight window in clock hours and its share of real time, nights pass faster
	daytime_start = 5.5,
	daytime_end = 19,
	daytime_share = 0.72, -- note: 12 min day gives ~8.6 min of daylight, ~3.4 min of night
	-- note: lighting baked into the place so studio looks right while building
	edit_preview_time = 10,
}

--------------------------------------------------------------------
-- Time-of-day keyframes
--------------------------------------------------------------------

config.keyframes = {
	{
		time = 0,
		name = "Midnight",
		Lighting = {
			Brightness = 3,
			ExposureCompensation = 0.75,
			Ambient = rgb(54, 62, 92),
			OutdoorAmbient = rgb(95, 108, 150),
			ColorShift_Top = rgb(120, 140, 200),
			ShadowSoftness = 0.45,
		},
		Atmosphere = {
			Density = 0.28,
			Offset = 0.1,
			Color = rgb(36, 44, 64),
			Decay = rgb(12, 16, 28),
			Glare = 0,
			Haze = 0.3,
		},
		ColorCorrection = {
			Brightness = 0.02,
			Contrast = 0.08,
			Saturation = -0.4,
			TintColor = rgb(185, 205, 255),
		},
		Bloom = { Intensity = 0.6, Threshold = 1.2 },
		SunRays = { Intensity = 0, Spread = 0.6 },
		DepthOfField = { FarIntensity = 0.12 },
		Clouds = {
			Cover = 0.5,
			Density = 0.55,
			Color = rgb(60, 70, 92),
		},
	},
	{
		time = 5.2,
		name = "PreDawn",
		Lighting = {
			Brightness = 2.6,
			ExposureCompensation = 1,
			Ambient = rgb(66, 66, 98),
			OutdoorAmbient = rgb(125, 124, 168),
			ColorShift_Top = rgb(140, 130, 190),
			ShadowSoftness = 0.4,
		},
		Atmosphere = {
			Density = 0.32,
			Offset = 0.14,
			Color = rgb(120, 115, 160),
			Decay = rgb(45, 42, 82),
			Glare = 0.3,
			Haze = 0.9,
		},
		ColorCorrection = {
			Brightness = 0.02,
			Contrast = 0.06,
			Saturation = -0.15,
			TintColor = rgb(220, 220, 255),
		},
		Bloom = { Intensity = 0.5, Threshold = 1.3 },
		SunRays = { Intensity = 0, Spread = 0.6 },
		DepthOfField = { FarIntensity = 0.1 },
		Clouds = {
			Cover = 0.5,
			Density = 0.6,
			Color = rgb(130, 120, 160),
		},
	},
	{
		time = 6.15,
		name = "Sunrise",
		Lighting = {
			Brightness = 2,
			ExposureCompensation = 0.7,
			Ambient = rgb(98, 88, 104),
			OutdoorAmbient = rgb(168, 148, 168),
			ColorShift_Top = rgb(255, 170, 115),
			ShadowSoftness = 0.25,
		},
		Atmosphere = {
			Density = 0.32,
			Offset = 0.2,
			Color = rgb(255, 190, 155),
			Decay = rgb(120, 100, 150),
			Glare = 1.8,
			Haze = 1.7,
		},
		ColorCorrection = {
			Brightness = 0,
			Contrast = 0.08,
			Saturation = 0.08,
			TintColor = rgb(255, 236, 226),
		},
		Bloom = { Intensity = 0.45, Threshold = 1.5 },
		SunRays = { Intensity = 0.18, Spread = 0.75 },
		DepthOfField = { FarIntensity = 0.1 },
		Clouds = {
			Cover = 0.55,
			Density = 0.6,
			Color = rgb(255, 200, 185),
		},
	},
	{
		time = 7.6,
		name = "Morning",
		Lighting = {
			Brightness = 2.6,
			ExposureCompensation = 0.05,
			Ambient = rgb(84, 84, 94),
			OutdoorAmbient = rgb(135, 133, 140),
			ColorShift_Top = rgb(255, 228, 195),
			ShadowSoftness = 0.18,
		},
		Atmosphere = {
			Density = 0.28,
			Offset = 0.22,
			Color = rgb(215, 210, 205),
			Decay = rgb(110, 125, 155),
			Glare = 0.6,
			Haze = 0.9,
		},
		ColorCorrection = {
			Brightness = 0,
			Contrast = 0.1,
			Saturation = 0.06,
			TintColor = rgb(255, 248, 240),
		},
		Bloom = { Intensity = 0.4, Threshold = 1.7 },
		SunRays = { Intensity = 0.08, Spread = 0.65 },
		DepthOfField = { FarIntensity = 0.08 },
		Clouds = {
			Cover = 0.55,
			Density = 0.6,
			Color = rgb(255, 245, 235),
		},
	},
	{
		time = 12.5,
		name = "Midday",
		Lighting = {
			Brightness = 3,
			ExposureCompensation = 0,
			Ambient = rgb(80, 84, 96),
			OutdoorAmbient = rgb(128, 130, 138),
			ColorShift_Top = rgb(255, 248, 238),
			ShadowSoftness = 0.15,
		},
		Atmosphere = {
			Density = 0.26,
			Offset = 0.22,
			Color = rgb(199, 206, 218),
			Decay = rgb(104, 122, 156),
			Glare = 0.2,
			Haze = 0.45,
		},
		ColorCorrection = {
			Brightness = 0,
			Contrast = 0.1,
			Saturation = 0.05,
			TintColor = rgb(255, 255, 255),
		},
		Bloom = { Intensity = 0.35, Threshold = 1.8 },
		SunRays = { Intensity = 0.05, Spread = 0.6 },
		DepthOfField = { FarIntensity = 0.08 },
		Clouds = {
			Cover = 0.55,
			Density = 0.6,
			Color = rgb(255, 255, 255),
		},
	},
	{
		time = 15.8,
		name = "Afternoon",
		Lighting = {
			Brightness = 2.8,
			ExposureCompensation = 0,
			Ambient = rgb(84, 82, 90),
			OutdoorAmbient = rgb(136, 132, 134),
			ColorShift_Top = rgb(255, 238, 215),
			ShadowSoftness = 0.16,
		},
		Atmosphere = {
			Density = 0.27,
			Offset = 0.22,
			Color = rgb(212, 206, 200),
			Decay = rgb(115, 120, 150),
			Glare = 0.5,
			Haze = 0.7,
		},
		ColorCorrection = {
			Brightness = 0,
			Contrast = 0.1,
			Saturation = 0.07,
			TintColor = rgb(255, 250, 242),
		},
		Bloom = { Intensity = 0.38, Threshold = 1.75 },
		SunRays = { Intensity = 0.07, Spread = 0.65 },
		DepthOfField = { FarIntensity = 0.08 },
		Clouds = {
			Cover = 0.55,
			Density = 0.6,
			Color = rgb(255, 250, 240),
		},
	},
	{
		time = 17,
		name = "GoldenHour",
		Lighting = {
			Brightness = 2.4,
			ExposureCompensation = 0.2,
			Ambient = rgb(100, 90, 90),
			OutdoorAmbient = rgb(170, 152, 145),
			ColorShift_Top = rgb(255, 200, 140),
			ShadowSoftness = 0.2,
		},
		Atmosphere = {
			Density = 0.29,
			Offset = 0.22,
			Color = rgb(255, 210, 165),
			Decay = rgb(140, 115, 125),
			Glare = 1.2,
			Haze = 1.3,
		},
		ColorCorrection = {
			Brightness = 0,
			Contrast = 0.1,
			Saturation = 0.08,
			TintColor = rgb(255, 240, 222),
		},
		Bloom = { Intensity = 0.45, Threshold = 1.6 },
		SunRays = { Intensity = 0.15, Spread = 0.75 },
		DepthOfField = { FarIntensity = 0.09 },
		Clouds = {
			Cover = 0.55,
			Density = 0.6,
			Color = rgb(255, 225, 190),
		},
	},
	{
		time = 17.85,
		name = "Sunset",
		Lighting = {
			Brightness = 1.9,
			ExposureCompensation = 0.8,
			Ambient = rgb(100, 84, 98),
			OutdoorAmbient = rgb(168, 140, 158),
			ColorShift_Top = rgb(255, 140, 85),
			ShadowSoftness = 0.3,
		},
		Atmosphere = {
			Density = 0.31,
			Offset = 0.18,
			Color = rgb(255, 155, 110),
			Decay = rgb(110, 75, 130),
			Glare = 2.2,
			Haze = 2,
		},
		ColorCorrection = {
			Brightness = 0,
			Contrast = 0.1,
			Saturation = 0.12,
			TintColor = rgb(255, 224, 208),
		},
		Bloom = { Intensity = 0.5, Threshold = 1.4 },
		SunRays = { Intensity = 0.22, Spread = 0.8 },
		DepthOfField = { FarIntensity = 0.1 },
		Clouds = {
			Cover = 0.55,
			Density = 0.6,
			Color = rgb(255, 165, 130),
		},
	},
	{
		time = 18.45,
		name = "Dusk",
		Lighting = {
			Brightness = 2,
			ExposureCompensation = 1.1,
			Ambient = rgb(70, 66, 100),
			OutdoorAmbient = rgb(135, 128, 175),
			ColorShift_Top = rgb(150, 120, 190),
			ShadowSoftness = 0.4,
		},
		Atmosphere = {
			Density = 0.3,
			Offset = 0.15,
			Color = rgb(140, 115, 165),
			Decay = rgb(45, 40, 85),
			Glare = 0.5,
			Haze = 1.2,
		},
		ColorCorrection = {
			Brightness = 0.02,
			Contrast = 0.06,
			Saturation = -0.05,
			TintColor = rgb(232, 226, 255),
		},
		Bloom = { Intensity = 0.55, Threshold = 1.3 },
		SunRays = { Intensity = 0, Spread = 0.6 },
		DepthOfField = { FarIntensity = 0.11 },
		Clouds = {
			Cover = 0.5,
			Density = 0.6,
			Color = rgb(170, 125, 170),
		},
	},
	{
		time = 19.5,
		name = "Night",
		Lighting = {
			Brightness = 3,
			ExposureCompensation = 0.75,
			Ambient = rgb(54, 62, 92),
			OutdoorAmbient = rgb(95, 108, 150),
			ColorShift_Top = rgb(120, 140, 200),
			ShadowSoftness = 0.45,
		},
		Atmosphere = {
			Density = 0.28,
			Offset = 0.1,
			Color = rgb(36, 44, 64),
			Decay = rgb(12, 16, 28),
			Glare = 0,
			Haze = 0.3,
		},
		ColorCorrection = {
			Brightness = 0.02,
			Contrast = 0.08,
			Saturation = -0.4,
			TintColor = rgb(185, 205, 255),
		},
		Bloom = { Intensity = 0.6, Threshold = 1.2 },
		SunRays = { Intensity = 0, Spread = 0.6 },
		DepthOfField = { FarIntensity = 0.12 },
		Clouds = {
			Cover = 0.5,
			Density = 0.55,
			Color = rgb(60, 70, 92),
		},
	},
}

return config