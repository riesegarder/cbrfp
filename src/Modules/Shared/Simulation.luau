local Simulation = {}
Simulation.__index = Simulation

local ItemEntity = require(script.Parent.ItemEntity)
local ChoppingBoardConfig = require(script.Parent.ChoppingBoardConfig)
type ItemEntityRegistry = ItemEntity.ItemEntityRegistry

local Interface = {}
function Interface.new(map)
	local self = {
		state = {
			position = Vector2.new(0, 0),
			radius = 0.45,
			moveSpeed = 3,
			t = 0,
			frame = 0,
			rotation = 0,
			heldItem = nil, -- Now stores item ID (number?) instead of item name
			lastInteractState = false, -- Track previous interact state
			justPlacedItem = false, -- Track if item was just placed (prevents immediate chopping)
		},
		map = map,
	}
	setmetatable(self, Simulation)
	return self
end

function Simulation.processCommand(self, cmd, counterStates, itemEntities, createEntityCallback, choppingBoardStates)
	-- Use provided counterStates or fall back to map's (for client compatibility)
	local activeCounterStates = counterStates or self.map.counterStates
	local activeChoppingBoardStates = choppingBoardStates or self.map.choppingBoardStates

	local _didCollide, newPosition = self.map:sweepCircle(
		self.state.radius,
		self.state.position,
		cmd.moveDirection * self.state.moveSpeed * cmd.deltaTime
	)
	self.state.position = newPosition

	if cmd.moveDirection.Magnitude > 0 then
		self.state.rotation = math.deg(math.atan2(cmd.moveDirection.Y, cmd.moveDirection.X))
	end

	-- Handle interaction (only on key press, not while held)
	if cmd.interact and not self.state.lastInteractState then
		self:processInteraction(activeCounterStates, itemEntities, createEntityCallback, activeChoppingBoardStates)
	end

	-- Clear justPlacedItem flag when interact is released
	if not cmd.interact and self.state.lastInteractState then
		self.state.justPlacedItem = false
	end

	-- Handle hold-down chopping (only if interact is held AND item wasn't just placed)
	if cmd.interact and self.state.lastInteractState and not self.state.justPlacedItem then
		self:processChopping(cmd.deltaTime, itemEntities, activeChoppingBoardStates)
	end

	self.state.lastInteractState = cmd.interact

	self.state.t += cmd.deltaTime
	self.state.frame += 1
end

-- Helper function to check if target is in front of character
function Simulation.isInFront(self, targetPos: Vector2): boolean
	local toTarget = (targetPos - self.state.position)
	if toTarget.Magnitude == 0 then
		return false
	end

	local facingDir = Vector2.new(math.cos(math.rad(self.state.rotation)), math.sin(math.rad(self.state.rotation)))

	local dot = toTarget.Unit:Dot(facingDir)
	return dot > 0.5 -- Must be roughly in front (within ~60 degrees)
end

-- Find the closest valid interactable
function Simulation.findInteractable(self): (string?, string?) -- returns (type, id)
	local INTERACTION_RANGE = 1.5
	local closestDistance = math.huge
	local closestType: string? = nil
	local closestId: string? = nil

	-- Check ingredient boxes
	for id, ingredientBox in self.map.ingredientBoxes do
		local distance = (ingredientBox.position - self.state.position).Magnitude
		if distance <= INTERACTION_RANGE and distance < closestDistance then
			if self:isInFront(ingredientBox.position) then
				closestDistance = distance
				closestType = "ingredient"
				closestId = id
			end
		end
	end

	-- Check counters
	for id, counter in self.map.counters do
		local distance = (counter.position - self.state.position).Magnitude
		if distance <= INTERACTION_RANGE and distance < closestDistance then
			if self:isInFront(counter.position) then
				closestDistance = distance
				closestType = "counter"
				closestId = id
			end
		end
	end

	-- Check chopping boards
	for id, board in self.map.choppingBoards do
		local distance = (board.position - self.state.position).Magnitude
		if distance <= INTERACTION_RANGE and distance < closestDistance then
			if self:isInFront(board.position) then
				closestDistance = distance
				closestType = "choppingBoard"
				closestId = id
			end
		end
	end

	return closestType, closestId
end

-- Process interaction with the nearest valid target
function Simulation.processInteraction(self, counterStates, itemEntities, createEntityCallback, choppingBoardStates)
	local interactType, interactId = self:findInteractable()

	if interactType == "ingredient" then
		-- Pick up from ingredient box (only if not already holding something)
		if not self.state.heldItem then
			local ingredientBox = self.map.ingredientBoxes[interactId]
			if ingredientBox and ingredientBox.ingredientName then
				-- Create a new item entity via callback
				if createEntityCallback then
					local newItemId = createEntityCallback(ingredientBox.ingredientName)
					self.state.heldItem = newItemId
					print(`Picked up new {ingredientBox.ingredientName} with ID {newItemId}`)
				end
			end
		end
	elseif interactType == "counter" then
		-- Counter interaction: pickup or place
		local currentItemId = counterStates[interactId]

		if self.state.heldItem then
			-- Character holding something: place it on counter (if counter is empty)
			if not currentItemId then
				local itemEntity = ItemEntity.get(itemEntities, self.state.heldItem)
				local itemType = itemEntity and itemEntity.type or "Unknown"
				print(
					`[BEFORE PLACE] Character holding: Item#{self.state.heldItem} ({itemType}), Counter {interactId}: {currentItemId}`
				)
				counterStates[interactId] = self.state.heldItem
				local itemIdToPlace = self.state.heldItem
				self.state.heldItem = nil
				print(
					`[AFTER PLACE] Character holding: {self.state.heldItem}, Counter {interactId}: {counterStates[interactId]}`
				)
				print(`Placed Item#{itemIdToPlace} ({itemType}) on counter {interactId}`)
			else
				local currentEntity = ItemEntity.get(itemEntities, currentItemId)
				local currentType = currentEntity and currentEntity.type or "Unknown"
				print(`Cannot place - counter {interactId} already has: Item#{currentItemId} ({currentType})`)
			end
		else
			-- Character not holding anything: pick up from counter (if counter has something)
			if currentItemId then
				local itemEntity = ItemEntity.get(itemEntities, currentItemId)
				local itemType = itemEntity and itemEntity.type or "Unknown"
				print(
					`[BEFORE PICKUP] Character holding: {self.state.heldItem}, Counter {interactId}: Item#{currentItemId} ({itemType})`
				)
				self.state.heldItem = currentItemId
				counterStates[interactId] = nil
				print(
					`[AFTER PICKUP] Character holding: Item#{self.state.heldItem}, Counter {interactId}: {counterStates[interactId]}`
				)
				print(`Picked up Item#{currentItemId} ({itemType}) from counter {interactId}`)
			else
				print(`Cannot pickup - counter {interactId} is empty`)
			end
		end
	elseif interactType == "choppingBoard" then
		-- Chopping board interaction: place or pickup
		local currentItemId = choppingBoardStates[interactId]

		if self.state.heldItem then
			-- Character holding something: place it on chopping board (if board is empty and item is choppable)
			if not currentItemId then
				local itemEntity = ItemEntity.get(itemEntities, self.state.heldItem)
				if itemEntity then
					-- Check if item is choppable
					if ChoppingBoardConfig.isChoppable(itemEntity.type) then
						print(
							`[BEFORE PLACE] Character holding: Item#{self.state.heldItem} ({itemEntity.type}), Board {interactId}: {currentItemId}`
						)
						choppingBoardStates[interactId] = self.state.heldItem
						local itemIdToPlace = self.state.heldItem
						self.state.heldItem = nil
						self.state.justPlacedItem = true -- Set flag to prevent immediate chopping
						print(
							`[AFTER PLACE] Character holding: {self.state.heldItem}, Board {interactId}: {choppingBoardStates[interactId]}`
						)
						print(`Placed Item#{itemIdToPlace} ({itemEntity.type}) on chopping board {interactId}`)
					else
						print(`Cannot place - Item#{self.state.heldItem} ({itemEntity.type}) is not choppable`)
					end
				end
			else
				local currentEntity = ItemEntity.get(itemEntities, currentItemId)
				local currentType = currentEntity and currentEntity.type or "Unknown"
				print(`Cannot place - chopping board {interactId} already has: Item#{currentItemId} ({currentType})`)
			end
		else
			-- Character not holding anything: pick up from chopping board
			if currentItemId then
				local itemEntity = ItemEntity.get(itemEntities, currentItemId)
				if itemEntity then
					local itemType = itemEntity.type
					local isChoppable = ChoppingBoardConfig.isChoppable(itemType)
					local choppedPercentage = itemEntity.choppedPercentage or 0

					-- Allow pickup if: item is NOT choppable (already sliced) OR item is fully chopped
					if not isChoppable or choppedPercentage >= 1.0 then
						print(
							`[BEFORE PICKUP] Character holding: {self.state.heldItem}, Board {interactId}: Item#{currentItemId} ({itemType})`
						)
						self.state.heldItem = currentItemId
						choppingBoardStates[interactId] = nil
						print(
							`[AFTER PICKUP] Character holding: Item#{self.state.heldItem}, Board {interactId}: {choppingBoardStates[interactId]}`
						)
						print(`Picked up Item#{currentItemId} ({itemType}) from chopping board {interactId}`)
					else
						local percentageDisplay = math.floor(choppedPercentage * 100)
						print(
							`Cannot pickup - Item#{currentItemId} ({itemType}) is only {percentageDisplay}% chopped. Finish chopping first.`
						)
					end
				end
			else
				print(`Cannot pickup - chopping board {interactId} is empty`)
			end
		end
	end
end

-- Process chopping (while interact key is held down)
function Simulation.processChopping(self, deltaTime: number, itemEntities, choppingBoardStates)
	-- Only chop if not holding anything
	if self.state.heldItem then
		return
	end

	local interactType, interactId = self:findInteractable()

	if interactType == "choppingBoard" then
		local itemId = choppingBoardStates[interactId]
		if itemId then
			local itemEntity = ItemEntity.get(itemEntities, itemId)
			if itemEntity then
				local recipe = ChoppingBoardConfig.getRecipe(itemEntity.type)
				if recipe then
					-- Item is choppable, increment chopped percentage
					local choppingSpeed = 1.0 / recipe.choppingTime -- percentage per second
					itemEntity.choppedPercentage = (itemEntity.choppedPercentage or 0) + (choppingSpeed * deltaTime)

					-- Check if chopping is complete
					if itemEntity.choppedPercentage >= 1.0 then
						-- Transform item to chopped version
						local oldType = itemEntity.type
						itemEntity.type = recipe.result
						itemEntity.choppedPercentage = 0 -- Reset for future chopping if needed
						print(`Item#{itemId} transformed from {oldType} to {itemEntity.type}`)
					end
				end
			end
		end
	end
end

function Simulation.read(self, state)
	self.state = table.clone(state)
end

function Simulation.write(self)
	return table.clone(self.state)
end

return Interface
