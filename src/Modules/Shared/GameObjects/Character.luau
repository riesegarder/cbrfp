local Character = {}
Character.__index = Character

function Character.new(simulation)
	local self = simulation.state
	setmetatable(self, Character)
	return self
end

return Character