--!strict
--[[
	Vignette
	What: darkens the screen edges for the local player
	How: one full-screen image under every other gui, client-side only
]]

local players = game:GetService("Players")

local IMAGE = "rbxassetid://126241354924787"
local STRENGTH = 0.5 -- note: image transparency; 0 is the full effect, 1 hides it

local gui = Instance.new("ScreenGui")
gui.Name = "VignetteGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = -1 -- note: below every other gui so the hud stays clear

local image = Instance.new("ImageLabel")
image.Name = "Vignette"
image.BackgroundTransparency = 1
image.Size = UDim2.fromScale(1, 1)
image.Image = IMAGE
image.ImageTransparency = STRENGTH
image.Parent = gui

gui.Parent = players.LocalPlayer:WaitForChild("PlayerGui")