local MapObject = {}

function MapObject.create(world, data, id)
	local collider = {
		position = data.position, -- Vector2
		rotation = data.rotation, -- number
		size = data.size, -- Vector2 (for Box, this is the box size, for Circle, this is a radius)
		shape = data.shape, -- "Box" or "Circle",

		canCollide = data.canCollide or true,
	}

	return collider
end

return MapObject