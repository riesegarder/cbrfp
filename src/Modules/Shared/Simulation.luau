local Simulation = {}
Simulation.__index = Simulation

local Interface = {}
function Interface.new(map)
	local self = {
		state = {
			position = Vector2.new(0, 0),
			rotation = 0,
			radius = 0.45,
			moveSpeed = 3,
			t = 0,
			frame = 0,
		},
		map = map,
	}
	setmetatable(self, Simulation)
	return self
end

function Simulation.processCommand(self, cmd)
	local _didCollide, newPosition = self.map:sweepCircle(
		self.state.radius,
		self.state.position,
		cmd.moveDirection * self.state.moveSpeed * cmd.deltaTime
	)
	self.state.position = newPosition

	if cmd.moveDirection.Magnitude > 0 then
		self.state.rotation = math.deg(math.atan2(cmd.moveDirection.Y, cmd.moveDirection.X))
	end
	self.state.t += cmd.deltaTime
	self.state.frame += 1
end

function Simulation.read(self, state)
	self.state = table.clone(state)
end

function Simulation.write(self)
	return table.clone(self.state)
end

return Interface
