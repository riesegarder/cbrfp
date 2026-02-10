local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Loader = require(ReplicatedStorage.Packages.Loader)
local World = {}
World.__index = World

local Entities = Loader.LoadChildren(script.Entities)

local lastPredictedId = 0
local predictedEntityCache = {}

function World.new()
	local self = {
		-- technically speaking this is the state table for the whole world simulation
		entities = {}, -- everything is an entity, this is the main "state" table for the whole thing
		-- entities: {[entityId (number)]: entityData (table with key-value pairs of all entity data)}

		lastId = 0, -- entity id counter to prevent collisions
	}
	setmetatable(self, World)
	return self
end

-- this should really only happen for characters, right?
function World.ProcessInput(self, entityId: number, input)
	local entity = self.entities[entityId]
	if not entity then
		error(`No entity {entityId}`)
	end
	local entityType = entity.entityType
	local entityModule = Entities[entityType]

	entityModule.ProcessInput(self, entity, input)
end

function World.AddEntity(self, entityType: string, data: any, isPredicted: boolean?)
	local entityModule = Entities[entityType] -- loaded modules to at least separate code by entity type
	if not entityModule then
		error(`Invalid entity type: {entityType}`)
	end

	local entityId = 0
	if isPredicted then
		lastPredictedId -= 1
		entityId = lastPredictedId
	else 
		self.lastId += 1 
		entityId = self.lastId
	end

	local newEntity = entityModule.create(self, data, entityId)
	self.entities[entityId] = newEntity
	if isPredicted then
		predictedEntityCache[entityId] = newEntity
	end

	return entityId
end

function World.Destroy(self)
	
end

return World
