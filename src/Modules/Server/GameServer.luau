local PlayersManager = require(script.Parent.PlayersManager)
local WorldServer = require(script.Parent.WorldServer)
local GameServer = {}

local playerRecords = {}

function GameServer._onPlayerAdded(player: Player, sessionId: number)
	local playerRecord = {
		playerSessionId = sessionId,
	}
	playerRecords[sessionId] = playerRecord

	local charEntityId = WorldServer:SpawnCharacter(sessionId)
	playerRecord.charEntityId = charEntityId
end

function GameServer._onPlayerRemoving(player: Player, sessionId: number)
	playerRecords[sessionId] = nil
	WorldServer:DespawnCharacter(sessionId)
end

function GameServer.ReceiveInput()

end

function GameServer.Init()
	
end

function GameServer.Start()
	PlayersManager:ConnectAllPlayers(GameServer._onPlayerAdded)
end

return GameServer
