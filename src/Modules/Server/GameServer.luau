local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayersManager = require(script.Parent.PlayersManager)
local World = require(ReplicatedStorage.Source.Shared.World)
local GameServer = {}

local world = World.new()

function GameServer._onPlayerAdded(player: Player, sessionId: number)
	world:addEntity("Character", {playerSessionId = sessionId})
end

function GameServer._onPlayerRemoving(player: Player, sessionId: number)

end

function GameServer.Init()

end

function GameServer.Start()
	PlayersManager:ConnectAllPlayers(GameServer._onPlayerAdded)
end

return GameServer
