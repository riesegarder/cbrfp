local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local CharacterController = require(ReplicatedStorage.Source.Client.CharacterController)
local UIController = require(ReplicatedStorage.Source.Client.UIController)
local Simulation = require(ReplicatedStorage.Source.Shared.Simulation)
local Map = require(ReplicatedStorage.Source.Shared.Map)

local GameClient = {}

local cmdRemote = ReplicatedStorage.Remotes.Command
local lastReceivedServerState = nil
local lastConfirmedFrameNumber = nil
local pendingCommands = {}
local stateCache = {}
local gameMap, sim

function GameClient._onWorldStateReceived(worldState: any)
	local players = worldState.players or worldState -- Handle both old and new format
	local counterStates = worldState.counterStates

	-- CRITICAL: Properly sync counter states from server
	-- Clear ALL counter states first, then set from server to handle both additions and removals
	if counterStates and gameMap then
		-- First, clear all existing counter states
		for counterId, _ in gameMap.counters do
			gameMap.counterStates[counterId] = nil
		end
		-- Then set counter states from server (including nil/empty counters)
		for counterId, serverItem in counterStates do
			gameMap.counterStates[counterId] = serverItem
		end
	end

	local ownWorldState = players[tostring(Players.LocalPlayer.UserId)]
	if ownWorldState then
		local serverState = ownWorldState.simulation.state
		local serverFrame = serverState.frame

		-- Always check if we need to rollback by comparing current state to server
		local doRollback = false
		local positionDifference = 0
		if sim and sim.state and sim.state.position then
			positionDifference = (sim.state.position - serverState.position).Magnitude
			-- Use a more reasonable threshold - 0.1 units instead of 0.01
			-- This accounts for small floating point differences and timing variations
			if positionDifference > 0.1 then
				doRollback = true
			end
		else
			-- First state received, initialize from server
			doRollback = true
		end

		-- IMPORTANT: Always reset counter states to server state to prevent duplication
		if counterStates and gameMap then
			-- Clear all counter states first
			for counterId, _ in gameMap.counters do
				gameMap.counterStates[counterId] = nil
			end
			-- Then apply server's authoritative state
			for counterId, serverItem in counterStates do
				gameMap.counterStates[counterId] = serverItem
			end
		end

		if doRollback then
			lastReceivedServerState = serverState
			lastConfirmedFrameNumber = serverFrame

			-- Only warn for significant rollbacks to reduce spam
			if positionDifference > 0.5 then
				warn(`ROLLBACK: {lastConfirmedFrameNumber} (diff: {math.floor(positionDifference * 100) / 100})`)
			end

			-- First, clean up old commands and cache
			for frameNumber, _ in pairs(pendingCommands) do
				if frameNumber <= lastConfirmedFrameNumber then
					pendingCommands[frameNumber] = nil
					stateCache[frameNumber] = nil
				end
			end

			-- Reset to server state
			sim:read(lastReceivedServerState)

			-- Replay remaining commands in order
			local framesToReplay = {}
			for frameNumber, _ in pairs(pendingCommands) do
				table.insert(framesToReplay, frameNumber)
			end
			table.sort(framesToReplay)

			for _, frameNumber in ipairs(framesToReplay) do
				sim:processCommand(pendingCommands[frameNumber], gameMap.counterStates)
			end
		end

		-- Clean up old confirmed states to prevent memory leak
		if lastConfirmedFrameNumber then
			for frameNumber, _ in pairs(stateCache) do
				if frameNumber < lastConfirmedFrameNumber - 60 then
					stateCache[frameNumber] = nil
					pendingCommands[frameNumber] = nil
				end
			end
		end
	end

	-- Update counter states without re-rendering entire map
	if counterStates and gameMap then
		UIController._updateCounterItems(gameMap)
	end

	UIController._renderWorldState(players)
end

function GameClient.Start()
	gameMap = Map.new(workspace.Map)
	UIController._renderMap(gameMap)
	sim = Simulation.new(gameMap)

	RunService.Heartbeat:Connect(function(deltaTime: number)
		local cmd = {
			frame = sim.state.frame,
			deltaTime = deltaTime,
			moveDirection = CharacterController:GetMoveVector(),
			interact = CharacterController:IsInteractDown(),
		}
		pendingCommands[sim.state.frame] = cmd
		stateCache[sim.state.frame] = sim:write()

		sim:processCommand(cmd, gameMap.counterStates)
		UIController._renderLocalState(sim)
		cmdRemote:FireServer(cmd)
	end)

	ReplicatedStorage.Remotes.WorldState.OnClientEvent:Connect(GameClient._onWorldStateReceived)
end

return GameClient
