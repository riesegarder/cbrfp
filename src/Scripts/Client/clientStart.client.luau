local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function preLoad() end

local function postLoad()
	local Loader = require(ReplicatedStorage.Packages.Loader)
	local ClientModules = Loader.LoadChildren(ReplicatedStorage.Source.Client)
	for moduleName, moduleData in ClientModules do
		if moduleData.Init then
			moduleData.Init()
		end
	end
	Loader.SpawnAll(ClientModules, "Start")
end

preLoad()
if not game:IsLoaded() then
	game.Loaded:Wait()
end
postLoad()
