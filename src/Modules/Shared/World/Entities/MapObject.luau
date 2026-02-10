local MapObject = {}

function MapObject.create(world, data, id)
	local collider = {
		entityType = script.Name,
		position = data.position,
		rotation = data.rotation,
		size = data.size,

		canCollide = data.canCollide or true,
	}

	return collider
end

return MapObject