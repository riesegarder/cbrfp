local Players = game:GetService("Players")
local PlayersInterface = {}

local idMap = {} :: { [number]: Player }
local reverseMap = {} :: { [Player]: number }

function PlayersInterface:GetSessionId(player: Player): number
	return reverseMap[player]
end

function PlayersInterface:GetPlayerFromSessionId(sessionId: number): Player?
	return idMap[sessionId]
end

function PlayersInterface._onPlayerAdded(player: Player)
	local sessionId = player:GetAttribute("SessionId")
	if not sessionId then
		warn(`WAITING FOR SESSION ID: {player.Name}`)
		player:GetAttributeChangedSignal("SessionId"):Wait()
		sessionId = player:GetAttribute("SessionId")
	end
	idMap[sessionId] = player
	reverseMap[player] = sessionId
end

function PlayersInterface._onPlayerRemoving(player: Player)
	local sessionId = reverseMap[player]
	if not sessionId then
		return
	end
	idMap[sessionId] = nil
	reverseMap[player] = nil
end

function PlayersInterface.Init()
	for _, player in Players:GetPlayers() do
		task.spawn(PlayersInterface._onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(PlayersInterface._onPlayerAdded)
	Players.PlayerRemoving:Connect(PlayersInterface._onPlayerRemoving)
end

return PlayersInterface