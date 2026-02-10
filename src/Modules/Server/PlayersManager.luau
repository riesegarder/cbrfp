local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)
local PlayersManager = {
	PlayerAdded = Signal.new(),
	PlayerRemoving = Signal.new(),
}

local count = 0
local idMap = {} :: { [number]: Player }
local reverseMap = {} :: { [Player]: number }
local function cycleCount()
	count += 1
	if count > 255 then
		count = 0
	end
end
local function getNewId()
	cycleCount()
	while idMap[count] do
		cycleCount()
	end
	return count
end

function PlayersManager:ConnectAllPlayers(callback: (player: Player, sessionId: number) -> ())
	for player, sessionId in pairs(reverseMap) do 
		task.spawn(callback, player, sessionId)
	end
	return PlayersManager.PlayerAdded:Connect(callback)
end

function PlayersManager:ConnectPlayerRemoving(callback: (player: Player, sessionId: number) -> ())
	return PlayersManager.PlayerRemoving:Connect(callback)
end

function PlayersManager:GetPlayerFromSessionId(sessionId: number): Player?
	return idMap[sessionId]
end

function PlayersManager:GetSessionId(player: Player): number
	return reverseMap[player]
end

function PlayersManager._onPlayerAdded(player: Player)
	local sessionId = getNewId()
	idMap[sessionId] = player
	reverseMap[player] = sessionId
	player:SetAttribute("SessionId", sessionId)

	PlayersManager.PlayerAdded:Fire(player, sessionId)
end

function PlayersManager._onPlayerRemoving(player: Player)
	local sessionId = reverseMap[player]
	PlayersManager.PlayerRemoving:Fire(player, sessionId)
	idMap[sessionId] = nil
	reverseMap[player] = nil
end

function PlayersManager.Init()
	for _, player in Players:GetPlayers() do
		task.spawn(PlayersManager._onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(PlayersManager._onPlayerAdded)
	Players.PlayerRemoving:Connect(PlayersManager._onPlayerRemoving)
end

return PlayersManager
