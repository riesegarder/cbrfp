--!strict
-- Chopping Board Configuration
-- Defines which ingredients can be chopped and what they transform into

export type ChoppingRecipe = {
	result: string, -- What the ingredient becomes when chopped
	choppingTime: number, -- Time in seconds to complete chopping
}

-- Mapping of ingredient type to chopping recipe
local CHOPPING_RECIPES: { [string]: ChoppingRecipe } = {
	Apple = {
		result = "SlicedApple",
		choppingTime = 1.0,
	},
	Tomato = {
		result = "SlicedTomato",
		choppingTime = 1.0,
	},
	Lettuce = {
		result = "SlicedLettuce",
		choppingTime = 0.8,
	},
	Onion = {
		result = "SlicedOnion",
		choppingTime = 1.2,
	},
}

local ChoppingBoardConfig = {}

-- Check if an ingredient can be chopped
function ChoppingBoardConfig.isChoppable(ingredientType: string): boolean
	return CHOPPING_RECIPES[ingredientType] ~= nil
end

-- Get the chopping recipe for an ingredient
function ChoppingBoardConfig.getRecipe(ingredientType: string): ChoppingRecipe?
	return CHOPPING_RECIPES[ingredientType]
end

-- Get the result of chopping an ingredient
function ChoppingBoardConfig.getChoppedResult(ingredientType: string): string?
	local recipe = CHOPPING_RECIPES[ingredientType]
	return recipe and recipe.result
end

-- Get the time required to chop an ingredient
function ChoppingBoardConfig.getChoppingTime(ingredientType: string): number?
	local recipe = CHOPPING_RECIPES[ingredientType]
	return recipe and recipe.choppingTime
end

return ChoppingBoardConfig
