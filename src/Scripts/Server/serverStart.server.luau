local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Loader = require(ReplicatedStorage.Packages.Loader)

local ServerModules = Loader.LoadChildren(ServerStorage.Source.Server)
for moduleName, moduleData in ServerModules do
	if moduleData.Init then
		moduleData.Init()
	end
end
Loader.SpawnAll(ServerModules, "Start")
