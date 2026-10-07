--!strict
--[[
	Waterwheels
	What: turns every model tagged Waterwheel around its pivot (the axle, along the model's local z)
	How: client-side only, and only while the camera is near, so distant wheels cost nothing
]]

local collection_service = game:GetService("CollectionService")
local run_service = game:GetService("RunService")
local workspace = game:GetService("Workspace")

local SPIN_SPEED = math.rad(24) -- note: radians per second
local ACTIVE_DISTANCE = 300

run_service.Heartbeat:Connect(function(delta_time: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local step = CFrame.Angles(0, 0, -SPIN_SPEED * delta_time)
	for _, wheel in collection_service:GetTagged("Waterwheel") do
		if wheel:IsA("Model") and wheel:IsDescendantOf(workspace) then
			local pivot = wheel:GetPivot()
			if (pivot.Position - camera.CFrame.Position).Magnitude < ACTIVE_DISTANCE then
				wheel:PivotTo(pivot * step)
			end
		end
	end
end)