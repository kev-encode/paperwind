--!strict
--[[
	LightingConfig
	Paperwind's lighting: global settings, day/night timing, and time-of-day presets.

	Keyframes are the key moments of the day on the 24h clock. LightingBlender eases between
	neighbouring keyframes, so you only author those moments; every keyframe must list the same
	properties. Preview any time in Studio's command bar (edit mode):
	  require(game.ReplicatedStorage.LightingSystem.LightingBlender).preview(17.5)
]]

local C = Color3.fromRGB

local LightingConfig = {}

-- Fixed look (not time-dependent) -------------------------------------------------
LightingConfig.Global = {
	LightingStyle = Enum.LightingStyle.Realistic,
	PrioritizeLightingQuality = true,
	-- Noon sun ~63 degrees high in the south (longer, readable shadows); it sets over the west pass.
	GeographicLatitude = 50,
	EnvironmentDiffuseScale = 1,
	EnvironmentSpecularScale = 1,
	GlobalShadows = true,
}

-- Properties per object that never change with time.
LightingConfig.Static = {
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
	-- Only far scenery softens; nothing near the player blurs.
	DepthOfField = { FocusDistance = 60, InFocusRadius = 70, NearIntensity = 0 },
}

-- Day/night timing -------------------------------------------------------------------
LightingConfig.Cycle = {
	DayLengthMinutes = 12, -- one full 24h day, in real minutes
	StartClockTime = 9, -- clock time when a server starts
	-- Daylight window (clock hours) and the share of real time it gets; nights pass faster.
	DaytimeStart = 5.5,
	DaytimeEnd = 19,
	DaytimeShare = 0.72, -- 12 min day: ~8.6 min of daylight, ~3.4 min of night
	-- Lighting baked into the place so Studio looks right while building.
	EditPreviewClockTime = 10,
}

-- Time-of-day keyframes ----------------------------------------------------------------
LightingConfig.Keyframes = {
	{
		Time = 0, Name = "Midnight",
		Lighting = { Brightness = 3, ExposureCompensation = 0.75, Ambient = C(54, 62, 92), OutdoorAmbient = C(95, 108, 150), ColorShift_Top = C(120, 140, 200), ShadowSoftness = 0.45 },
		Atmosphere = { Density = 0.28, Offset = 0.1, Color = C(36, 44, 64), Decay = C(12, 16, 28), Glare = 0, Haze = 0.3 },
		ColorCorrection = { Brightness = 0.02, Contrast = 0.08, Saturation = -0.4, TintColor = C(185, 205, 255) },
		Bloom = { Intensity = 0.6, Threshold = 1.2 },
		SunRays = { Intensity = 0, Spread = 0.6 },
		DepthOfField = { FarIntensity = 0.12 },
		Clouds = { Cover = 0.5, Density = 0.55, Color = C(60, 70, 92) },
	},
	{
		Time = 5.2, Name = "PreDawn",
		Lighting = { Brightness = 2.6, ExposureCompensation = 1, Ambient = C(66, 66, 98), OutdoorAmbient = C(125, 124, 168), ColorShift_Top = C(140, 130, 190), ShadowSoftness = 0.4 },
		Atmosphere = { Density = 0.32, Offset = 0.14, Color = C(120, 115, 160), Decay = C(45, 42, 82), Glare = 0.3, Haze = 0.9 },
		ColorCorrection = { Brightness = 0.02, Contrast = 0.06, Saturation = -0.15, TintColor = C(220, 220, 255) },
		Bloom = { Intensity = 0.5, Threshold = 1.3 },
		SunRays = { Intensity = 0, Spread = 0.6 },
		DepthOfField = { FarIntensity = 0.1 },
		Clouds = { Cover = 0.5, Density = 0.6, Color = C(130, 120, 160) },
	},
	{
		Time = 6.15, Name = "Sunrise",
		Lighting = { Brightness = 2, ExposureCompensation = 0.7, Ambient = C(98, 88, 104), OutdoorAmbient = C(168, 148, 168), ColorShift_Top = C(255, 170, 115), ShadowSoftness = 0.25 },
		Atmosphere = { Density = 0.32, Offset = 0.2, Color = C(255, 190, 155), Decay = C(120, 100, 150), Glare = 1.8, Haze = 1.7 },
		ColorCorrection = { Brightness = 0, Contrast = 0.08, Saturation = 0.08, TintColor = C(255, 236, 226) },
		Bloom = { Intensity = 0.45, Threshold = 1.5 },
		SunRays = { Intensity = 0.18, Spread = 0.75 },
		DepthOfField = { FarIntensity = 0.1 },
		Clouds = { Cover = 0.55, Density = 0.6, Color = C(255, 200, 185) },
	},
	{
		Time = 7.6, Name = "Morning",
		Lighting = { Brightness = 2.6, ExposureCompensation = 0.05, Ambient = C(84, 84, 94), OutdoorAmbient = C(135, 133, 140), ColorShift_Top = C(255, 228, 195), ShadowSoftness = 0.18 },
		Atmosphere = { Density = 0.28, Offset = 0.22, Color = C(215, 210, 205), Decay = C(110, 125, 155), Glare = 0.6, Haze = 0.9 },
		ColorCorrection = { Brightness = 0, Contrast = 0.1, Saturation = 0.06, TintColor = C(255, 248, 240) },
		Bloom = { Intensity = 0.4, Threshold = 1.7 },
		SunRays = { Intensity = 0.08, Spread = 0.65 },
		DepthOfField = { FarIntensity = 0.08 },
		Clouds = { Cover = 0.55, Density = 0.6, Color = C(255, 245, 235) },
	},
	{
		Time = 12.5, Name = "Midday",
		Lighting = { Brightness = 3, ExposureCompensation = 0, Ambient = C(80, 84, 96), OutdoorAmbient = C(128, 130, 138), ColorShift_Top = C(255, 248, 238), ShadowSoftness = 0.15 },
		Atmosphere = { Density = 0.26, Offset = 0.22, Color = C(199, 206, 218), Decay = C(104, 122, 156), Glare = 0.2, Haze = 0.45 },
		ColorCorrection = { Brightness = 0, Contrast = 0.1, Saturation = 0.05, TintColor = C(255, 255, 255) },
		Bloom = { Intensity = 0.35, Threshold = 1.8 },
		SunRays = { Intensity = 0.05, Spread = 0.6 },
		DepthOfField = { FarIntensity = 0.08 },
		Clouds = { Cover = 0.55, Density = 0.6, Color = C(255, 255, 255) },
	},
	{
		Time = 15.8, Name = "Afternoon",
		Lighting = { Brightness = 2.8, ExposureCompensation = 0, Ambient = C(84, 82, 90), OutdoorAmbient = C(136, 132, 134), ColorShift_Top = C(255, 238, 215), ShadowSoftness = 0.16 },
		Atmosphere = { Density = 0.27, Offset = 0.22, Color = C(212, 206, 200), Decay = C(115, 120, 150), Glare = 0.5, Haze = 0.7 },
		ColorCorrection = { Brightness = 0, Contrast = 0.1, Saturation = 0.07, TintColor = C(255, 250, 242) },
		Bloom = { Intensity = 0.38, Threshold = 1.75 },
		SunRays = { Intensity = 0.07, Spread = 0.65 },
		DepthOfField = { FarIntensity = 0.08 },
		Clouds = { Cover = 0.55, Density = 0.6, Color = C(255, 250, 240) },
	},
	{
		Time = 17, Name = "GoldenHour",
		Lighting = { Brightness = 2.4, ExposureCompensation = 0.2, Ambient = C(100, 90, 90), OutdoorAmbient = C(170, 152, 145), ColorShift_Top = C(255, 200, 140), ShadowSoftness = 0.2 },
		Atmosphere = { Density = 0.29, Offset = 0.22, Color = C(255, 210, 165), Decay = C(140, 115, 125), Glare = 1.2, Haze = 1.3 },
		ColorCorrection = { Brightness = 0, Contrast = 0.1, Saturation = 0.08, TintColor = C(255, 240, 222) },
		Bloom = { Intensity = 0.45, Threshold = 1.6 },
		SunRays = { Intensity = 0.15, Spread = 0.75 },
		DepthOfField = { FarIntensity = 0.09 },
		Clouds = { Cover = 0.55, Density = 0.6, Color = C(255, 225, 190) },
	},
	{
		Time = 17.85, Name = "Sunset",
		Lighting = { Brightness = 1.9, ExposureCompensation = 0.8, Ambient = C(100, 84, 98), OutdoorAmbient = C(168, 140, 158), ColorShift_Top = C(255, 140, 85), ShadowSoftness = 0.3 },
		Atmosphere = { Density = 0.31, Offset = 0.18, Color = C(255, 155, 110), Decay = C(110, 75, 130), Glare = 2.2, Haze = 2 },
		ColorCorrection = { Brightness = 0, Contrast = 0.1, Saturation = 0.12, TintColor = C(255, 224, 208) },
		Bloom = { Intensity = 0.5, Threshold = 1.4 },
		SunRays = { Intensity = 0.22, Spread = 0.8 },
		DepthOfField = { FarIntensity = 0.1 },
		Clouds = { Cover = 0.55, Density = 0.6, Color = C(255, 165, 130) },
	},
	{
		Time = 18.45, Name = "Dusk",
		Lighting = { Brightness = 2, ExposureCompensation = 1.1, Ambient = C(70, 66, 100), OutdoorAmbient = C(135, 128, 175), ColorShift_Top = C(150, 120, 190), ShadowSoftness = 0.4 },
		Atmosphere = { Density = 0.3, Offset = 0.15, Color = C(140, 115, 165), Decay = C(45, 40, 85), Glare = 0.5, Haze = 1.2 },
		ColorCorrection = { Brightness = 0.02, Contrast = 0.06, Saturation = -0.05, TintColor = C(232, 226, 255) },
		Bloom = { Intensity = 0.55, Threshold = 1.3 },
		SunRays = { Intensity = 0, Spread = 0.6 },
		DepthOfField = { FarIntensity = 0.11 },
		Clouds = { Cover = 0.5, Density = 0.6, Color = C(170, 125, 170) },
	},
	{
		Time = 19.5, Name = "Night",
		Lighting = { Brightness = 3, ExposureCompensation = 0.75, Ambient = C(54, 62, 92), OutdoorAmbient = C(95, 108, 150), ColorShift_Top = C(120, 140, 200), ShadowSoftness = 0.45 },
		Atmosphere = { Density = 0.28, Offset = 0.1, Color = C(36, 44, 64), Decay = C(12, 16, 28), Glare = 0, Haze = 0.3 },
		ColorCorrection = { Brightness = 0.02, Contrast = 0.08, Saturation = -0.4, TintColor = C(185, 205, 255) },
		Bloom = { Intensity = 0.6, Threshold = 1.2 },
		SunRays = { Intensity = 0, Spread = 0.6 },
		DepthOfField = { FarIntensity = 0.12 },
		Clouds = { Cover = 0.5, Density = 0.55, Color = C(60, 70, 92) },
	},
}

return LightingConfig
