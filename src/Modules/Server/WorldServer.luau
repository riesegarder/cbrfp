local ReplicatedStorage = game:GetService("ReplicatedStorage")
local World = require(ReplicatedStorage.Source.Shared.World)
local WorldServer = {}

local currentWorld

function WorldServer:StartWorld()
	currentWorld = World.new()
end

function WorldServer:Step()

end

function WorldServer:SpawnCharacter(player: Player?): number -- entity id
	currentWorld:AddEntity()
end

return WorldServer