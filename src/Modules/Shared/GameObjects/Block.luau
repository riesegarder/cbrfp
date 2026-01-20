local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Loader = require(ReplicatedStorage.Packages.Loader)

local Block = {}
Block.__index = Block

local blockTypes = Loader.LoadChildren(ReplicatedStorage.Source.Shared.Blocks)

function Block.new(data: any)
	local blockType = data.BlockType
	local blockModule = blockTypes[blockType]
	local self = {
		collider = {
			shape = "Block",
			position = data.Position,
			rotation = data.Rotation,
		},
		blockType = blockType,

		interact = blockModule.Interact,
	}
	setmetatable(self, Block)
	return self
end

return Block