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
	-- note: false lets low-end devices scale lighting down instead of dropping frames
	PrioritizeLightingQuality = false,
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
	-- note: darker, less cyan water so it reads like real sea
	Terrain = {
		WaterColor = rgb(34, 60, 64),
		WaterTransparency = 0.45,
		WaterReflectance = 0.5,
	},
	-- note: only far scenery softens, nothing near the player blurs
	DepthOfField = {
		FocusDistance = 60,
		InFocusRadius = 70,
		NearIntensity = 0,
	},
}

-- note: muted, natural terrain colors (keys are terrain material names)
config.material_colors = {
	Grass = rgb(90, 100, 64),
	Sand = rgb(164, 152, 124),
	Rock = rgb(102, 100, 96),
	Snow = rgb(226, 230, 234),
	Ground = rgb(112, 100, 80),
	Mud = rgb(90, 80, 68),
	Limestone = rgb(104, 98, 88),
}

--------------------------------------------------------------------
-- Day/night timing
--------------------------------------------------------------------

config.cycle = {
	day_length = 12, -- note: one full 24h day, in real minutes
	start_time = 17.85, -- note: clock time when a server starts (sunset keyframe)
	-- note: daylight window in clock hours and its share of real time, nights pass faster
	daytime_start = 5.5,
	daytime_end = 19,
	daytime_share = 0.72, -- note: 12 min day gives ~8.6 min of daylight, ~3.4 min of night
	-- note: lighting baked into the place so studio looks right while building
	edit_preview_time = 17.85,
	-- note: blends per second; changes between updates are far too small to see
	update_rate = 10,
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
			ExposureCompensation = 0.95,
			Ambient = rgb(64, 64, 86),
			OutdoorAmbient = rgb(118, 118, 150),
			ColorShift_Top = rgb(140, 135, 180),
			ShadowSoftness = 0.4,
		},
		Atmosphere = {
			Density = 0.33,
			Offset = 0.14,
			Color = rgb(112, 110, 138),
			Decay = rgb(44, 44, 72),
			Glare = 0.2,
			Haze = 1.3,
		},
		ColorCorrection = {
			Brightness = 0.02,
			Contrast = 0.06,
			Saturation = -0.3,
			TintColor = rgb(222, 224, 245),
		},
		Bloom = { Intensity = 0.35, Threshold = 1.5 },
		SunRays = { Intensity = 0, Spread = 0.6 },
		DepthOfField = { FarIntensity = 0.1 },
		Clouds = {
			Cover = 0.5,
			Density = 0.6,
			Color = rgb(120, 116, 145),
		},
	},
	{
		time = 6.15,
		name = "Sunrise",
		Lighting = {
			Brightness = 2,
			ExposureCompensation = 0.65,
			Ambient = rgb(92, 86, 96),
			OutdoorAmbient = rgb(158, 144, 152),
			ColorShift_Top = rgb(255, 180, 130),
			ShadowSoftness = 0.25,
		},
		Atmosphere = {
			Density = 0.31,
			Offset = 0.2,
			Color = rgb(228, 190, 165),
			Decay = rgb(112, 100, 128),
			Glare = 1.3,
			Haze = 1.8,
		},
		ColorCorrection = {
			Brightness = 0,
			Contrast = 0.1,
			Saturation = -0.06,
			TintColor = rgb(255, 238, 226),
		},
		Bloom = { Intensity = 0.3, Threshold = 1.8 },
		SunRays = { Intensity = 0.14, Spread = 0.75 },
		DepthOfField = { FarIntensity = 0.1 },
		Clouds = {
			Cover = 0.55,
			Density = 0.6,
			Color = rgb(238, 200, 185),
		},
	},
	{
		time = 7.6,
		name = "Morning",
		Lighting = {
			Brightness = 2.6,
			ExposureCompensation = 0,
			Ambient = rgb(78, 80, 86),
			OutdoorAmbient = rgb(128, 128, 132),
			ColorShift_Top = rgb(255, 232, 205),
			ShadowSoftness = 0.18,
		},
		Atmosphere = {
			Density = 0.3,
			Offset = 0.24,
			Color = rgb(204, 204, 202),
			Decay = rgb(118, 126, 142),
			Glare = 0.4,
			Haze = 1.6,
		},
		ColorCorrection = {
			Brightness = 0,
			Contrast = 0.12,
			Saturation = -0.2,
			TintColor = rgb(255, 249, 242),
		},
		Bloom = { Intensity = 0.22, Threshold = 2.1 },
		SunRays = { Intensity = 0.06, Spread = 0.65 },
		DepthOfField = { FarIntensity = 0.08 },
		Clouds = {
			Cover = 0.6,
			Density = 0.62,
			Color = rgb(240, 238, 234),
		},
	},
	{
		time = 12.5,
		name = "Midday",
		Lighting = {
			Brightness = 3,
			ExposureCompensation = -0.1,
			Ambient = rgb(74, 76, 82),
			OutdoorAmbient = rgb(122, 124, 128),
			ColorShift_Top = rgb(255, 248, 236),
			ShadowSoftness = 0.15,
		},
		Atmosphere = {
			Density = 0.29,
			Offset = 0.25,
			Color = rgb(192, 198, 206),
			Decay = rgb(116, 126, 144),
			Glare = 0.15,
			Haze = 1.4,
		},
		ColorCorrection = {
			Brightness = 0,
			Contrast = 0.12,
			Saturation = -0.24,
			TintColor = rgb(255, 253, 248),
		},
		Bloom = { Intensity = 0.18, Threshold = 2.3 },
		SunRays = { Intensity = 0.03, Spread = 0.6 },
		DepthOfField = { FarIntensity = 0.08 },
		Clouds = {
			Cover = 0.6,
			Density = 0.62,
			Color = rgb(242, 242, 240),
		},
	},
	{
		time = 15.8,
		name = "Afternoon",
		Lighting = {
			Brightness = 2.8,
			ExposureCompensation = -0.05,
			Ambient = rgb(78, 76, 82),
			OutdoorAmbient = rgb(130, 126, 126),
			ColorShift_Top = rgb(255, 240, 220),
			ShadowSoftness = 0.16,
		},
		Atmosphere = {
			Density = 0.3,
			Offset = 0.24,
			Color = rgb(206, 202, 196),
			Decay = rgb(122, 122, 140),
			Glare = 0.35,
			Haze = 1.6,
		},
		ColorCorrection = {
			Brightness = 0,
			Contrast = 0.12,
			Saturation = -0.2,
			TintColor = rgb(255, 250, 242),
		},
		Bloom = { Intensity = 0.2, Threshold = 2.2 },
		SunRays = { Intensity = 0.05, Spread = 0.65 },
		DepthOfField = { FarIntensity = 0.08 },
		Clouds = {
			Cover = 0.6,
			Density = 0.62,
			Color = rgb(240, 236, 228),
		},
	},
	{
		time = 17,
		name = "GoldenHour",
		Lighting = {
			Brightness = 2.4,
			ExposureCompensation = 0.15,
			Ambient = rgb(94, 86, 86),
			OutdoorAmbient = rgb(160, 146, 138),
			ColorShift_Top = rgb(255, 204, 150),
			ShadowSoftness = 0.2,
		},
		Atmosphere = {
			Density = 0.3,
			Offset = 0.22,
			Color = rgb(232, 204, 170),
			Decay = rgb(132, 114, 118),
			Glare = 0.9,
			Haze = 1.6,
		},
		ColorCorrection = {
			Brightness = 0,
			Contrast = 0.12,
			Saturation = -0.06,
			TintColor = rgb(255, 240, 222),
		},
		Bloom = { Intensity = 0.28, Threshold = 1.9 },
		SunRays = { Intensity = 0.12, Spread = 0.75 },
		DepthOfField = { FarIntensity = 0.09 },
		Clouds = {
			Cover = 0.6,
			Density = 0.62,
			Color = rgb(240, 215, 185),
		},
	},
	{
		time = 17.85,
		name = "Sunset",
		Lighting = {
			Brightness = 1.9,
			ExposureCompensation = 0.75,
			Ambient = rgb(94, 82, 92),
			OutdoorAmbient = rgb(158, 136, 148),
			ColorShift_Top = rgb(255, 150, 95),
			ShadowSoftness = 0.3,
		},
		Atmosphere = {
			Density = 0.32,
			Offset = 0.18,
			Color = rgb(230, 160, 122),
			Decay = rgb(104, 76, 116),
			Glare = 1.6,
			Haze = 1.9,
		},
		ColorCorrection = {
			Brightness = 0,
			Contrast = 0.12,
			Saturation = -0.04,
			TintColor = rgb(255, 228, 210),
		},
		Bloom = { Intensity = 0.32, Threshold = 1.7 },
		SunRays = { Intensity = 0.18, Spread = 0.8 },
		DepthOfField = { FarIntensity = 0.1 },
		Clouds = {
			Cover = 0.55,
			Density = 0.6,
			Color = rgb(232, 165, 135),
		},
	},
	{
		time = 18.45,
		name = "Dusk",
		Lighting = {
			Brightness = 2,
			ExposureCompensation = 1.05,
			Ambient = rgb(68, 66, 92),
			OutdoorAmbient = rgb(128, 124, 160),
			ColorShift_Top = rgb(150, 128, 180),
			ShadowSoftness = 0.4,
		},
		Atmosphere = {
			Density = 0.33,
			Offset = 0.15,
			Color = rgb(128, 112, 150),
			Decay = rgb(44, 40, 78),
			Glare = 0.4,
			Haze = 1.6,
		},
		ColorCorrection = {
			Brightness = 0.02,
			Contrast = 0.06,
			Saturation = -0.22,
			TintColor = rgb(232, 228, 250),
		},
		Bloom = { Intensity = 0.35, Threshold = 1.5 },
		SunRays = { Intensity = 0, Spread = 0.6 },
		DepthOfField = { FarIntensity = 0.11 },
		Clouds = {
			Cover = 0.5,
			Density = 0.6,
			Color = rgb(150, 120, 150),
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