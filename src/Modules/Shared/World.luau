local World = {}
World.__index = World

type ClassType = typeof(setmetatable({} :: {}, World))

function World.new()
	local self = {}
	setmetatable(self, World)
	return self
end

function World.step(self: ClassType, deltaTime: number)

end

function World:Destroy()

end

return World