--!strict
--[[
	TimeCycle
	The shared in-game clock. The server stores a start point as attributes on Lighting; every
	client (and server script) computes the same clock time from Workspace:GetServerTimeNow(),
	so all players see the same time with no per-frame network traffic.

	Anyone:      TimeCycle.getClockTime(), TimeCycle.getPhase(), TimeCycle.isNight()
	Server only: TimeCycle.setClockTime(hour), TimeCycle.setPaused(bool),
	             TimeCycle.setDayLengthMinutes(minutes)
]]

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent:WaitForChild("LightingConfig"))
local Cycle = Config.Cycle

local ATTR_EPOCH = "DayCycleEpoch" -- server time at which the cycle's progress was 0
local ATTR_LENGTH = "DayCycleMinutes" -- live day length (falls back to Config)
local ATTR_PAUSED = "DayCyclePausedAt" -- clock hour the cycle is frozen at (absent = running)

local DAY_HOURS = Cycle.DaytimeEnd - Cycle.DaytimeStart
local NIGHT_HOURS = 24 - DAY_HOURS

local TimeCycle = {}

-- Cycle progress (0-1 of real time) -> clock hour. Daylight hours get DaytimeShare of the time.
function TimeCycle.progressToClock(progress: number): number
	progress %= 1
	if progress < Cycle.DaytimeShare then
		return Cycle.DaytimeStart + (progress / Cycle.DaytimeShare) * DAY_HOURS
	end
	local nightProgress = (progress - Cycle.DaytimeShare) / (1 - Cycle.DaytimeShare)
	return (Cycle.DaytimeEnd + nightProgress * NIGHT_HOURS) % 24
end

-- Clock hour -> cycle progress (inverse of progressToClock).
function TimeCycle.clockToProgress(clock: number): number
	local sinceDawn = (clock - Cycle.DaytimeStart) % 24
	if sinceDawn < DAY_HOURS then
		return (sinceDawn / DAY_HOURS) * Cycle.DaytimeShare
	end
	return Cycle.DaytimeShare + ((sinceDawn - DAY_HOURS) / NIGHT_HOURS) * (1 - Cycle.DaytimeShare)
end

function TimeCycle.getDayLengthSeconds(): number
	local minutes = Lighting:GetAttribute(ATTR_LENGTH)
	if typeof(minutes) ~= "number" or minutes <= 0 then
		minutes = Cycle.DayLengthMinutes
	end
	return (minutes :: number) * 60
end

function TimeCycle.getClockTime(): number
	local paused = Lighting:GetAttribute(ATTR_PAUSED)
	if typeof(paused) == "number" then
		return paused % 24
	end
	local epoch = Lighting:GetAttribute(ATTR_EPOCH)
	if typeof(epoch) ~= "number" then
		return Cycle.StartClockTime -- server hasn't started the clock yet
	end
	local elapsed = Workspace:GetServerTimeNow() - epoch
	return TimeCycle.progressToClock(elapsed / TimeCycle.getDayLengthSeconds())
end

-- "Night" | "Dawn" | "Day" | "Dusk" (handy for lamps, NPC schedules, time-based fish...)
function TimeCycle.getPhase(clock: number?): string
	local c = (clock or TimeCycle.getClockTime()) % 24
	if c < 5 then
		return "Night"
	elseif c < 7 then
		return "Dawn"
	elseif c < 17 then
		return "Day"
	elseif c < 19.5 then
		return "Dusk"
	end
	return "Night"
end

function TimeCycle.isNight(clock: number?): boolean
	return TimeCycle.getPhase(clock) == "Night"
end

local function assertServer(name: string)
	assert(RunService:IsServer(), "TimeCycle." .. name .. " can only be called on the server")
end

-- Jump the clock to an hour (0-24); it keeps running from there.
function TimeCycle.setClockTime(clock: number)
	assertServer("setClockTime")
	local progress = TimeCycle.clockToProgress(clock % 24)
	Lighting:SetAttribute(ATTR_EPOCH, Workspace:GetServerTimeNow() - progress * TimeCycle.getDayLengthSeconds())
	if typeof(Lighting:GetAttribute(ATTR_PAUSED)) == "number" then
		Lighting:SetAttribute(ATTR_PAUSED, clock % 24)
	end
end

function TimeCycle.setPaused(paused: boolean)
	assertServer("setPaused")
	local clock = TimeCycle.getClockTime()
	if paused then
		Lighting:SetAttribute(ATTR_PAUSED, clock)
	else
		Lighting:SetAttribute(ATTR_PAUSED, nil)
		TimeCycle.setClockTime(clock)
	end
end

-- Change the day length without jumping the current time.
function TimeCycle.setDayLengthMinutes(minutes: number)
	assertServer("setDayLengthMinutes")
	local clock = TimeCycle.getClockTime()
	Lighting:SetAttribute(ATTR_LENGTH, minutes)
	TimeCycle.setClockTime(clock)
end

-- Server bootstrap: start the clock once per server.
function TimeCycle.start()
	assertServer("start")
	if typeof(Lighting:GetAttribute(ATTR_EPOCH)) ~= "number" then
		Lighting:SetAttribute(ATTR_LENGTH, Cycle.DayLengthMinutes)
		TimeCycle.setClockTime(Cycle.StartClockTime)
	end
end

return TimeCycle
