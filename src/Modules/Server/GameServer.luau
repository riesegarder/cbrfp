local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Simulation = require(ReplicatedStorage.Source.Shared.Simulation)
local Map = require(ReplicatedStorage.Source.Shared.Map)
local ItemEntity = require(ReplicatedStorage.Source.Shared.ItemEntity)

local GameTest = {}
local playerRecords = {}
local gameMap = Map.new(workspace.Map)
local counterStates = {} -- Global counter states, separate from map
local itemEntities = {} -- Item entity registry (authoritative on server)
local nextItemId = 1 -- Server-authoritative ID counter

function GameTest._onPlayerAdded(player: Player)
	local playerRecord = {
		simulation = Simulation.new(gameMap),
	}
	playerRecords[tostring(player.UserId)] = playerRecord
end

function GameTest._onPlayerRemoving(player: Player)
	playerRecords[tostring(player.UserId)] = nil
end

function GameTest.Init()
	-- Initialize counter states
	for counterId, _ in gameMap.counters do
		counterStates[counterId] = nil
	end

	for _, player in Players:GetPlayers() do
		task.spawn(GameTest._onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(GameTest._onPlayerAdded)
	Players.PlayerRemoving:Connect(GameTest._onPlayerRemoving)

	ReplicatedStorage.Remotes.Command.OnServerEvent:Connect(function(player: Player, cmd)
		if not playerRecords[tostring(player.UserId)] then
			return
		end

		-- Create entity callback for server-authoritative entity creation
		local function createEntity(itemType: string): number
			local newEntity = ItemEntity.create(nextItemId, itemType, 0)
			ItemEntity.add(itemEntities, newEntity)
			local createdId = nextItemId
			nextItemId += 1
			print(`[SERVER] Created entity #{createdId} of type {itemType}`)
			return createdId
		end

		-- Pass counter states, item entities, and create callback to the simulation
		playerRecords[tostring(player.UserId)].simulation:processCommand(cmd, counterStates, itemEntities, createEntity)
	end)
end

local wsRemote = ReplicatedStorage.Remotes.WorldState
function GameTest.Start()
	task.spawn(function()
		while true do
			task.wait(1 / 20)
			local worldState = {
				players = playerRecords,
				counterStates = counterStates, -- Send the global counter states
				itemEntities = itemEntities, -- Send all item entities
			}
			wsRemote:FireAllClients(worldState)
		end
	end)
end

return GameTest
