--[[
	World

	Shared game world simulation
	Should be deterministic, so given the same inputs, should arrive at the exact same state
]]
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

		-- this is a local cache that shouldn't get replicated
		-- great for fast lookups
		entityMap = {},

		lastId = 0, -- entity id counter to prevent collisions
	}
	setmetatable(self, World)
	return self
end

-- this should really only happen for characters, right?
-- yeah, should really only be for characters
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

	local newEntity = entityModule.create(self, data)
	newEntity.entityType = entityType
	newEntity.entityId = entityId
	self.entities[entityId] = newEntity
	local entityMap = self.entityMap[entityType]
	if not entityMap then
		entityMap = {}
		self.entityMap[entityType] = entityMap
	end
	entityMap[entityId] = newEntity

	if isPredicted then
		predictedEntityCache[entityId] = newEntity
	end

	return entityId
end

function World.RemoveEntity(self, entityId)
	local entity = self.entities[entityId]
	if not entity then
		return
	end
	local entityType = entity.entityType
	local entityMap = self.entityMap[entityType]
	self.entities[entityId] = nil
	entityMap[entityId] = nil
end

function World.Destroy(self) end

return World
