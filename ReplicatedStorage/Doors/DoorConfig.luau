--!strict
--[[
	DoorConfig
	What: tunables for interactive doors, shared by DoorService (server) and DoorController (client)
	Doors: models tagged Door; each Leaf model's PrimaryPart (Hinge) sits on the hinge line, and its Hand attribute
		is 1 for a left-hung leaf or -1 for a right-hung one (seen from outside)
	State: the door's Open (bool) and Swing (1 opens inward, -1 outward) attributes, written only by the server
]]

local config = {
	tag = "Door",
	open_angle = 90, -- note: degrees
	open_time = 0.45, -- note: seconds for a full swing
	close_time = 0.4,
	toggle_cooldown = 0.35, -- note: seconds before the same door can be used again
	open_text = "Open",
	close_text = "Close",
}

return config