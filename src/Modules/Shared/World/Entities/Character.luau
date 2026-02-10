local Character = {}

function Character.create(world, data, id)
	local char = {
		entityType = script.Name,
		position = data.spawnPosition or Vector2.new(0, 0),
		rotation = data.spawnRotation or 0,
		radius = 0.45,
		moveSpeed = 3, 
		t = 0,
		frame = 0,

		player = data.playerSessionId,
	}
	return char
end

function Character.ProcessInput(world, character, input, deltaTime)
	local moveDirection = input.moveDirection
	if moveDirection.Magnitude > 0 then
		character.position += moveDirection.Unit * character.moveSpeed * input.deltaTime
	end
end

return Character