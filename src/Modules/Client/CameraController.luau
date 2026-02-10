--[[
	Does nothing atm.
]]
local Camera = workspace.CurrentCamera
local CameraController = {}

function CameraController.Init()
	Camera.CameraType = Enum.CameraType.Scriptable
	Camera.CFrame = CFrame.new(10, 10, 10)
end

return CameraController
