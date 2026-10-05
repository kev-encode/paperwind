--!strict
--[[
	TimeCycle
	What: the shared in-game clock
	How: the server stores a start point as Lighting attributes; everyone computes the time from Workspace:GetServerTimeNow(), so there is no per-frame network traffic
	Anyone: getClockTime(), getPhase(), isNight()
	Server only: setClockTime(hour), setPaused(bool), setDayLengthMinutes(minutes), start()
]]

local lighting = game:GetService("Lighting")
local run_service = game:GetService("RunService")
local workspace = game:GetService("Workspace")
local config = require(script.Parent:WaitForChild("LightingConfig"))

local cycle = config.cycle
local ATTR_EPOCH = "DayCycleEpoch" -- note: server time when the cycle's progress was 0
local ATTR_LENGTH = "DayCycleMinutes" -- note: live day length, falls back to config
local ATTR_PAUSED = "DayCyclePausedAt" -- note: clock hour the cycle is frozen at, absent while running
local DAY_HOURS = cycle.daytime_end - cycle.daytime_start
local NIGHT_HOURS = 24 - DAY_HOURS
local time_cycle = {}

-- note: cycle progress (0 to 1 of real time) to clock hour; daylight gets daytime_share of the time
function time_cycle.progressToClock(progress: number): number
	progress %= 1
	
	if progress < cycle.daytime_share then
		return cycle.daytime_start + (progress / cycle.daytime_share) * DAY_HOURS
	end
	
	local night_progress = (progress - cycle.daytime_share) / (1 - cycle.daytime_share)
	return (cycle.daytime_end + night_progress * NIGHT_HOURS) % 24
end

-- note: clock hour to cycle progress, the inverse of progressToClock
function time_cycle.clockToProgress(clock: number): number
	local since_dawn = (clock - cycle.daytime_start) % 24
	
	if since_dawn < DAY_HOURS then
		return (since_dawn / DAY_HOURS) * cycle.daytime_share
	end
	
	return cycle.daytime_share + ((since_dawn - DAY_HOURS) / NIGHT_HOURS) * (1 - cycle.daytime_share)
end

function time_cycle.getDayLengthSeconds(): number
	local minutes = lighting:GetAttribute(ATTR_LENGTH)
	if typeof(minutes) ~= "number" or minutes <= 0 then
		minutes = cycle.day_length
	end
	
	return (minutes :: number) * 60
end

function time_cycle.getClockTime(): number
	local paused = lighting:GetAttribute(ATTR_PAUSED)
	if typeof(paused) == "number" then
		return paused % 24
	end
	
	local epoch = lighting:GetAttribute(ATTR_EPOCH)
	if typeof(epoch) ~= "number" then
		return cycle.start_time -- note: the server hasn't started the clock yet
	end
	
	local elapsed = workspace:GetServerTimeNow() - epoch
	return time_cycle.progressToClock(elapsed / time_cycle.getDayLengthSeconds())
end

-- note: returns "Night", "Dawn", "Day" or "Dusk" for lamps, npc schedules and similar
function time_cycle.getPhase(clock: number?): string
	local hour = (clock or time_cycle.getClockTime()) % 24
	if hour < 5 then
		return "Night"
		
	elseif hour < 7 then
		return "Dawn"
		
	elseif hour < 17 then
		return "Day"
		
	elseif hour < 19.5 then
		return "Dusk"
	end
	
	return "Night"
end

function time_cycle.isNight(clock: number?): boolean
	return time_cycle.getPhase(clock) == "Night"
end

local function assertServer(name: string)
	assert(run_service:IsServer(), "TimeCycle." .. name .. " can only be called on the server")
end

-- note: jumps the clock to an hour (0 to 24), it keeps running from there
function time_cycle.setClockTime(clock: number)
	assertServer("setClockTime")
	local progress = time_cycle.clockToProgress(clock % 24)
	lighting:SetAttribute(ATTR_EPOCH, workspace:GetServerTimeNow() - progress * time_cycle.getDayLengthSeconds())
	
	if typeof(lighting:GetAttribute(ATTR_PAUSED)) == "number" then
		lighting:SetAttribute(ATTR_PAUSED, clock % 24)
	end
end

function time_cycle.setPaused(paused: boolean)
	assertServer("setPaused")
	local clock = time_cycle.getClockTime()
	
	if paused then
		lighting:SetAttribute(ATTR_PAUSED, clock)
		
	else
		lighting:SetAttribute(ATTR_PAUSED, nil)
		time_cycle.setClockTime(clock)
	end
end

-- note: changes the day length without jumping the current time
function time_cycle.setDayLengthMinutes(minutes: number)
	assertServer("setDayLengthMinutes")
	local clock = time_cycle.getClockTime()
	lighting:SetAttribute(ATTR_LENGTH, minutes)
	time_cycle.setClockTime(clock)
end

-- note: server bootstrap, starts the clock once per server
function time_cycle.start()
	assertServer("start")
	
	if typeof(lighting:GetAttribute(ATTR_EPOCH)) ~= "number" then
		lighting:SetAttribute(ATTR_LENGTH, cycle.day_length)
		time_cycle.setClockTime(cycle.start_time)
	end
end

return time_cycle