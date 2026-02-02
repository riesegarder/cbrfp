local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Simulation = require(ReplicatedStorage.Source.Shared.Simulation)
local RunService = game:GetService("RunService")
local Map = require(ReplicatedStorage.Source.Shared.Map)

local GameTest = {}
local playerRecords = {}
local gameMap = Map.new(workspace.Map)
local counterStates = {} -- Global counter states, separate from map

function GameTest._onPlayerAdded(player: Player)
	local playerRecord = {
		simulation = Simulation.new(gameMap),
	}
	playerRecords[tostring(player.UserId)] = playerRecord

	-- Initialize counter states if empty
	if not next(counterStates) then
		for counterId, _ in gameMap.counters do
			counterStates[counterId] = nil
		end
	end
end

function GameTest._onPlayerRemoving(player: Player)
	playerRecords[tostring(player.UserId)] = nil
end

function GameTest.Init()
	for _, player in Players:GetPlayers() do
		task.spawn(GameTest._onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(GameTest._onPlayerAdded)
	Players.PlayerRemoving:Connect(GameTest._onPlayerRemoving)

	ReplicatedStorage.Remotes.Command.OnServerEvent:Connect(function(player: Player, cmd)
		if not playerRecords[tostring(player.UserId)] then
			return
		end

		-- Pass counter states to the simulation
		playerRecords[tostring(player.UserId)].simulation:processCommand(cmd, counterStates)
	end)
end

local wsRemote = ReplicatedStorage.Remotes.WorldState
function GameTest.Start()
	task.spawn(function()
		while true do
			task.wait(1 / 20)
			local worldState = {
				players = playerRecords,
				counterStates = gameMap.counterStates,
			}
			wsRemote:FireAllClients(worldState)
		end
	end)
end

return GameTest
