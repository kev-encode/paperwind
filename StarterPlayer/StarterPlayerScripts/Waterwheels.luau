--!strict
--[[
	Waterwheels
	What: turns every model tagged Waterwheel around its pivot (the axle, along the model's local z)
	How: client-side only, and only while the camera is near, so distant wheels cost nothing
	Streaming: wheels are tracked as they stream in and out, so each frame walks a short list
]]

local collection_service = game:GetService("CollectionService")
local run_service = game:GetService("RunService")
local workspace = game:GetService("Workspace")

local TAG = "Waterwheel"
local SPIN_SPEED = math.rad(24) -- note: radians per second
local ACTIVE_DISTANCE = 300

local wheels: { Model } = {}

-- Tracking ------------------------------------------------------------------

local function addWheel(instance: Instance)
	if instance:IsA("Model") and not table.find(wheels, instance) then
		table.insert(wheels, instance)
	end
end

local function removeWheel(instance: Instance)
	local index = table.find(wheels, instance :: any)
	if index then
		table.remove(wheels, index)
	end
end

-- Start ---------------------------------------------------------------------

collection_service:GetInstanceAddedSignal(TAG):Connect(addWheel)
collection_service:GetInstanceRemovedSignal(TAG):Connect(removeWheel)
for _, instance in collection_service:GetTagged(TAG) do
	addWheel(instance)
end

run_service.Heartbeat:Connect(function(delta_time: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local camera_position = camera.CFrame.Position
	local step = CFrame.Angles(0, 0, -SPIN_SPEED * delta_time)
	for _, wheel in wheels do
		local pivot = wheel:GetPivot()
		if (pivot.Position - camera_position).Magnitude < ACTIVE_DISTANCE then
			wheel:PivotTo(pivot * step)
		end
	end
end)
