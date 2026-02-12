--[[
	Handles the server side world simulation.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local World = require(ReplicatedStorage.Source.Shared.World)
local WorldServer = {}

local currentWorld = nil :: typeof(World.new())

local charIds = {}

function WorldServer:StartWorld()
	currentWorld = World.new()
	ReplicatedStorage.Remotes.NewWorld:FireAllClients({ entities = currentWorld.entities })
end

function WorldServer:SpawnCharacter(playerSessionId: number): number -- entity id
	local charEntityId = currentWorld:AddEntity("Character", {
		position = Vector2.new(0, 0),
		rotation = 0,

		playerSessionId = playerSessionId,
	})
	charIds[playerSessionId] = charEntityId
end

function WorldServer:DespawnCharacter(playerSessionId: number)
	currentWorld:RemoveEntity(charIds[playerSessionId])
end

function WorldServer._onInvokeGetInitialWorldState(player: Player)
	if not currentWorld then
		return nil
	end
	return { entities = currentWorld.entities }
end

function WorldServer:ReceiveInput(playerSessionId: number, input: any)
	local charId = charIds[playerSessionId]
	if not charId then
		return
	end
	currentWorld:ProcessInput(charId, input)
end

function WorldServer.Init()
	ReplicatedStorage.Remotes.GetInitialWorldState.OnServerInvoke = WorldServer._onInvokeGetInitialWorldState
end

function WorldServer.Start()
	WorldServer:StartWorld()
end

return WorldServer
