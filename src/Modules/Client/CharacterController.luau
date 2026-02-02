local UserInputService = game:GetService("UserInputService")
local CharacterController = {}

function CharacterController:GetMoveVector()
	local moveVector = Vector2.new()
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		moveVector += Vector2.yAxis
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		moveVector -= Vector2.yAxis
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		moveVector += Vector2.xAxis
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		moveVector -= Vector2.xAxis
	end
	if moveVector.Magnitude > 0 then
		moveVector = moveVector.Unit
	end
	return moveVector
end

function CharacterController:IsInteractDown() 
	return UserInputService:IsKeyDown(Enum.KeyCode.Space)
end 

function CharacterController.Init() end

return CharacterController
