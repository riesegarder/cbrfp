--[[
	Handles client-side world simulation.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local World = require(ReplicatedStorage.Source.Shared.World)
local WorldClient = {}

local currentWorld = nil

function WorldClient._onNewWorld(worldState)
	currentWorld = World.new()
	for entityId, entity in worldState.entities do
		currentWorld:AddEntity(entity.entityType, entity)
	end
end

function WorldClient.Init()
	-- get initial world state
	local initialWorldState = ReplicatedStorage.Remotes.GetInitialWorldState:InvokeServer()
	if initialWorldState then
		WorldClient._onNewWorld(initialWorldState)
	end

	-- listen for other world state
	ReplicatedStorage.Remotes.NewWorld.OnClientEvent:Connect(WorldClient._onNewWorld)
end

function WorldClient.Start() end

return WorldClient
