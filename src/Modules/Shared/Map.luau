--!strict
-- Strictly-typed circle / OBB sweep + sliding resolver (Luau)
-- API is unchanged: Map.new(), Map.sweepCircle(map, radius, startPosition, travelVector)

type Circle = {
	shape: "Circle",
	position: Vector2,
	radius: number,
}
type Box = {
	shape: "Box",
	position: Vector2,
	size: Vector2, -- FULL size
	rotation: number, -- degrees, CCW
}
type MapShape = Circle | Box
type IngredientBox = {
	shape: "Circle" | "Box",
	position: Vector2,
	radius: number?,
	size: Vector2?,
	rotation: number?,
	ingredientName: string?,
}
type SpawnMarker = {
	team: string,
	position: Vector2,
	rotation: number,
}

type MapData = {
	shapes: { [string]: MapShape },
	counters: { [string]: MapShape },
	choppingBoards: { [string]: MapShape },
	ingredientBoxes: { [string]: IngredientBox },
	spawns: { [string]: SpawnMarker },
	counterStates: { [string]: number? }, -- Track what item ID is on each counter
	choppingBoardStates: { [string]: number? }, -- Track what item ID is on each chopping board
}

local Map = {}
Map.__index = Map
type MapType = typeof(setmetatable({} :: MapData, Map))

function Map.new(mapModel: Instance): MapType
	local mapBase = mapModel:FindFirstChild("MAPBASE") :: BasePart?
	assert(mapBase, "Map model must have a MAPBASE part")

	local baseCFrame = mapBase.CFrame
	local shapes: { [string]: MapShape } = {}
	local counters: { [string]: MapShape } = {}
	local choppingBoards: { [string]: MapShape } = {}
	local ingredientBoxes: { [string]: IngredientBox } = {}
	local spawns: { [string]: SpawnMarker } = {}
	local counterStates: { [string]: number? } = {}
	local choppingBoardStates: { [string]: number? } = {}

	-- Helper function to create a shape from a part
	local function createShapeFromPart(part: BasePart, namePrefix: string, counter: number): MapShape?
		local shapeAttribute = part:GetAttribute("Shape")
		if not shapeAttribute or (shapeAttribute ~= "Box" and shapeAttribute ~= "Circle") then
			warn(`Part {part.Name} missing or invalid Shape attribute`)
			return nil
		end

		local localCFrame = baseCFrame:ToObjectSpace(part.CFrame)
		-- 2D position: 3D X -> 2D X, 3D -Z -> 2D Y
		local pos2D = Vector2.new(localCFrame.Position.X, -localCFrame.Position.Z)

		if shapeAttribute == "Circle" then
			-- Use average of X and Z size for radius
			local radius = (part.Size.X + part.Size.Z) / 4
			return {
				shape = "Circle",
				position = pos2D,
				radius = radius,
			}
		else -- Box
			-- 2D size: X and Z from 3D
			local size2D = Vector2.new(part.Size.X, part.Size.Z)

			-- Rotation around Y axis (3D) -> 2D rotation (CCW)
			local _, rotY, _ = localCFrame:ToOrientation()
			local rotDeg = math.deg(rotY)

			-- Snap rotation to 5 degree increments to avoid floating point errors
			rotDeg = math.round(rotDeg / 5) * 5

			return {
				shape = "Box",
				position = pos2D,
				size = size2D,
				rotation = rotDeg,
			}
		end
	end

	-- Process Interactables
	local interactables = mapModel:FindFirstChild("Interactables")
	if interactables then
		-- Process Counters
		local countersFolder = interactables:FindFirstChild("Counters")
		if countersFolder then
			-- Sort parts by name for deterministic ordering
			local counterParts: { BasePart } = {}
			for _, counterPart in countersFolder:GetChildren() do
				if counterPart:IsA("BasePart") then
					table.insert(counterParts, counterPart)
				end
			end
			table.sort(counterParts, function(a: BasePart, b: BasePart)
				return a.Name < b.Name
			end)

			local counterCount = 0
			for _, counterPart in counterParts do
				counterCount += 1
				local shape = createShapeFromPart(counterPart, "Counter", counterCount)
				if shape then
					-- Use deterministic ID based on name and position
					local localCFrame = baseCFrame:ToObjectSpace(counterPart.CFrame)
					local pos2D = Vector2.new(localCFrame.Position.X, -localCFrame.Position.Z)
					local counterId = `{counterPart.Name}_{math.floor(pos2D.X * 100)}_{math.floor(pos2D.Y * 100)}`
					counters[counterId] = shape
					counterStates[counterId] = nil -- Initialize as empty
					print(`Added counter: {counterId}`)
				end
			end
		end

		-- Process IngredientBoxes
		local ingredientBoxesFolder = interactables:FindFirstChild("IngredientBoxes")
		if ingredientBoxesFolder then
			local ingredientCount = 0
			for _, ingredientPart in ingredientBoxesFolder:GetChildren() do
				if ingredientPart:IsA("BasePart") then
					ingredientCount += 1
					local shape = createShapeFromPart(ingredientPart, ingredientPart.Name, ingredientCount)
					if shape then
						-- Store with unique key but preserve ingredient name
						local ingredientShape: IngredientBox = shape :: IngredientBox
						ingredientShape.ingredientName = ingredientPart.Name
						ingredientBoxes[`{ingredientPart.Name}{ingredientCount}`] = ingredientShape
						print(`Added ingredient box: {ingredientPart.Name}{ingredientCount}`)
					end
				end
			end
		end

		-- Process Stations (Chopping Boards, etc.)
		local stationsFolder = interactables:FindFirstChild("Stations")
		if stationsFolder then
			-- Process Chopping Boards
			local choppingBoardParts: { BasePart } = {}
			for _, stationPart in stationsFolder:GetChildren() do
				if stationPart:IsA("BasePart") and stationPart.Name == "ChoppingBoard" then
					table.insert(choppingBoardParts, stationPart)
				end
			end
			table.sort(choppingBoardParts, function(a: BasePart, b: BasePart)
				return a.Name < b.Name
			end)

			local boardCount = 0
			for _, boardPart in choppingBoardParts do
				boardCount += 1
				local shape = createShapeFromPart(boardPart, "ChoppingBoard", boardCount)
				if shape then
					-- Use deterministic ID based on name and position
					local localCFrame = baseCFrame:ToObjectSpace(boardPart.CFrame)
					local pos2D = Vector2.new(localCFrame.Position.X, -localCFrame.Position.Z)
					local boardId = `ChoppingBoard_{math.floor(pos2D.X * 100)}_{math.floor(pos2D.Y * 100)}`
					choppingBoards[boardId] = shape
					choppingBoardStates[boardId] = nil -- Initialize as empty
					print(`Added chopping board: {boardId}`)
				end
			end
		end
	end

	-- Process Markers (Spawns)
	local markers = mapModel:FindFirstChild("Markers")
	if markers then
		local spawnsFolder = markers:FindFirstChild("Spawns")
		if spawnsFolder then
			local spawnCount = 0
			for _, spawnPart in spawnsFolder:GetChildren() do
				if spawnPart:IsA("BasePart") then
					spawnCount += 1
					local localCFrame = baseCFrame:ToObjectSpace(spawnPart.CFrame)
					local pos2D = Vector2.new(localCFrame.Position.X, -localCFrame.Position.Z)
					local _, rotY, _ = localCFrame:ToOrientation()
					local rotDeg = math.deg(rotY)

					spawns[`{spawnPart.Name}{spawnCount}`] = {
						team = spawnPart.Name,
						position = pos2D,
						rotation = rotDeg,
					}
					print(`Added spawn: {spawnPart.Name}{spawnCount} at {pos2D}`)
				end
			end
		end
	end

	-- Process Parts (regular collision shapes)
	local partsFolder = mapModel:FindFirstChild("Parts")
	if partsFolder then
		local partCount = 0
		for _, part in partsFolder:GetChildren() do
			if part:IsA("BasePart") then
				partCount += 1
				local shape = createShapeFromPart(part, part.Name, partCount)
				if shape then
					shapes[`{part.Name}{partCount}`] = shape
				end
			end
		end
	end

	print("Map loaded:")
	print("- Shapes:", shapes)
	print("- Counters:", counters)
	print("- Chopping Boards:", choppingBoards)
	print("- IngredientBoxes:", ingredientBoxes)
	print("- Spawns:", spawns)

	return setmetatable({
		shapes = shapes,
		counters = counters,
		choppingBoards = choppingBoards,
		ingredientBoxes = ingredientBoxes,
		spawns = spawns,
		counterStates = counterStates,
		choppingBoardStates = choppingBoardStates,
	}, Map)
end

----------------------------------------------------------------
-- Helper functions
----------------------------------------------------------------

local function rotateVector(v: Vector2, angleDeg: number): Vector2
	local rad = math.rad(angleDeg)
	local c, s = math.cos(rad), math.sin(rad)
	return Vector2.new(v.X * c - v.Y * s, v.X * s + v.Y * c)
end

local function clamp(val: number, min: number, max: number): number
	return math.max(min, math.min(max, val))
end

-- Find closest point on OBB to a circle center
local function closestPointOnOBB(circlePos: Vector2, box: Box): Vector2
	-- Transform circle to box's local space
	local localPos = circlePos - box.position
	localPos = rotateVector(localPos, -box.rotation)

	-- Clamp to box extents
	local halfSize = box.size * 0.5
	local clamped = Vector2.new(clamp(localPos.X, -halfSize.X, halfSize.X), clamp(localPos.Y, -halfSize.Y, halfSize.Y))

	-- Transform back to world space
	clamped = rotateVector(clamped, box.rotation)
	return clamped + box.position
end

-- Sweep circle against circle
local function sweepCircleCircle(
	radius: number,
	pos: Vector2,
	travel: Vector2,
	obstacle: Circle
): (boolean, number, Vector2?)
	local combinedRadius = radius + obstacle.radius
	local toObstacle = obstacle.position - pos

	local a = travel:Dot(travel)
	if a < 1e-10 then
		return false, 1, nil
	end

	local b = -2 * travel:Dot(toObstacle)
	local c = toObstacle:Dot(toObstacle) - combinedRadius * combinedRadius

	local discriminant = b * b - 4 * a * c
	if discriminant < 0 then
		return false, 1, nil
	end

	local t = (-b - math.sqrt(discriminant)) / (2 * a)

	if t < 0 or t > 1 then
		return false, 1, nil
	end

	local hitPos = pos + travel * t
	local normal = (hitPos - obstacle.position).Unit

	return true, t, normal
end

-- Sweep circle against OBB
local function sweepCircleBox(radius: number, pos: Vector2, travel: Vector2, box: Box): (boolean, number, Vector2?)
	local minT = math.huge
	local hitNormal: Vector2? = nil
	local hit = false

	-- Sample along the path for collision detection
	local steps = math.max(10, math.ceil(travel.Magnitude / (radius * 0.5)))

	for i = 0, steps do
		local t = i / steps
		local testPos = pos + travel * t
		local closest = closestPointOnOBB(testPos, box)
		local dist = (testPos - closest).Magnitude

		if dist < radius then
			if t < minT then
				minT = t
				local delta = testPos - closest
				hitNormal = if delta.Magnitude > 1e-6 then delta.Unit else Vector2.new(0, 1)
				hit = true
			end
		end
	end

	if not hit then
		return false, 1, nil
	end

	return true, minT, hitNormal
end

-- Single sweep against one shape
local function sweepAgainstShape(
	radius: number,
	pos: Vector2,
	travel: Vector2,
	shape: MapShape
): (boolean, number, Vector2?)
	if shape.shape == "Circle" then
		return sweepCircleCircle(radius, pos, travel, shape)
	else
		return sweepCircleBox(radius, pos, travel, shape)
	end
end

----------------------------------------------------------------
-- Multi-collision sweep (sliding)
-- Returns: (collided: boolean, finalPosition: Vector2)
----------------------------------------------------------------
function Map.sweepCircle(
	map: MapType,
	radius: number,
	startPosition: Vector2,
	travelVector: Vector2
): (boolean, Vector2)
	local maxIterations = 4
	local currentPos = startPosition
	local remainingTravel = travelVector
	local anyCollision = false

	for iteration = 1, maxIterations do
		if remainingTravel.Magnitude < 1e-6 then
			break
		end

		-- Find earliest collision
		local minT = 1
		local hitNormal: Vector2? = nil

		-- Check collision against all collidable objects
		-- Regular map shapes
		for _, shape in map.shapes do
			local hit, t, normal = sweepAgainstShape(radius, currentPos, remainingTravel, shape)
			if hit and t < minT then
				minT = t
				hitNormal = normal
				anyCollision = true
			end
		end

		-- Counter shapes
		for _, shape in map.counters do
			local hit, t, normal = sweepAgainstShape(radius, currentPos, remainingTravel, shape)
			if hit and t < minT then
				minT = t
				hitNormal = normal
				anyCollision = true
			end
		end

		-- Chopping board shapes
		for _, shape in map.choppingBoards do
			local hit, t, normal = sweepAgainstShape(radius, currentPos, remainingTravel, shape)
			if hit and t < minT then
				minT = t
				hitNormal = normal
				anyCollision = true
			end
		end

		-- Ingredient box shapes
		for _, shape in map.ingredientBoxes do
			local mapShape: MapShape = if shape.shape == "Circle"
				then {
					shape = "Circle",
					position = shape.position,
					radius = shape.radius or 0,
				}
				else {
					shape = "Box",
					position = shape.position,
					size = shape.size or Vector2.zero,
					rotation = shape.rotation or 0,
				}
			local hit, t, normal = sweepAgainstShape(radius, currentPos, remainingTravel, mapShape)
			if hit and t < minT then
				minT = t
				hitNormal = normal
				anyCollision = true
			end
		end

		-- Move to collision point (or full distance if no collision)
		currentPos = currentPos + remainingTravel * minT

		if minT >= 1 or not hitNormal then
			break
		end

		-- Slide along surface
		remainingTravel = remainingTravel * (1 - minT)
		if hitNormal then
			local normalDot = remainingTravel:Dot(hitNormal)
			if normalDot < 0 then
				remainingTravel = remainingTravel - hitNormal * normalDot
			end

			-- Small nudge away from surface to prevent getting stuck
			currentPos = currentPos + hitNormal * 0.001
		end
	end

	return anyCollision, currentPos
end

-- Counter state management methods
function Map.setCounterItem(map: MapType, counterId: string, itemId: number?)
	if map.counterStates[counterId] ~= nil then -- Counter exists
		map.counterStates[counterId] = itemId
	end
end

function Map.getCounterItem(map: MapType, counterId: string): number?
	return map.counterStates[counterId]
end

function Map.getCounterStates(map: MapType): { [string]: number? }
	return map.counterStates
end

-- Chopping board state management methods
function Map.setChoppingBoardItem(map: MapType, boardId: string, itemId: number?)
	if map.choppingBoardStates[boardId] ~= nil then -- Board exists
		map.choppingBoardStates[boardId] = itemId
	end
end

function Map.getChoppingBoardItem(map: MapType, boardId: string): number?
	return map.choppingBoardStates[boardId]
end

function Map.getChoppingBoardStates(map: MapType): { [string]: number? }
	return map.choppingBoardStates
end

return Map
