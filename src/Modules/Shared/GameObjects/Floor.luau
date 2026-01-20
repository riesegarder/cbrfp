local Floor = {}
Floor.__index = Floor

function Floor.new()
	local self = {}
	setmetatable(self, Floor)
	return self
end

return Floor