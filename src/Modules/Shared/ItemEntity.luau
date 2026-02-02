--!strict
-- Item Entity System
-- Handles item instances with unique IDs and properties

export type ItemEntity = {
	id: number,
	type: string, -- "Apple", "Tomato", "SlicedApple", etc.
	choppedPercentage: number?, -- 0 to 1 for chopping progress
}

export type ItemEntityRegistry = { [number]: ItemEntity }

local ItemEntity = {}

-- Create a new item entity
function ItemEntity.create(id: number, itemType: string, choppedPercentage: number?): ItemEntity
	return {
		id = id,
		type = itemType,
		choppedPercentage = choppedPercentage or 0,
	}
end

-- Clone an entity with a new ID (useful for duplicating items)
function ItemEntity.clone(entity: ItemEntity, newId: number): ItemEntity
	return {
		id = newId,
		type = entity.type,
		choppedPercentage = entity.choppedPercentage,
	}
end

-- Get entity from registry by ID
function ItemEntity.get(registry: ItemEntityRegistry, id: number): ItemEntity?
	return registry[id]
end

-- Add entity to registry
function ItemEntity.add(registry: ItemEntityRegistry, entity: ItemEntity)
	registry[entity.id] = entity
end

-- Remove entity from registry
function ItemEntity.remove(registry: ItemEntityRegistry, id: number)
	registry[id] = nil
end

return ItemEntity
