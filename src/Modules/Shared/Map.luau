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
type MapData = {
	shapes: { [string]: MapShape },
}

local Map = {}
Map.__index = Map
type MapType = typeof(setmetatable({} :: MapData, Map))

function Map.new(mapModel: Instance): MapType
	local mapBase = mapModel:FindFirstChild("MAPBASE") :: BasePart?
	assert(mapBase, "Map model must have a MAPBASE part")

	local baseCFrame = mapBase.CFrame
	local shapes: { [string]: MapShape } = {}

	local shapeCount = 0
	for _, child in mapModel:GetChildren() do
		if not child:IsA("BasePart") or child.Name == "MAPBASE" then
			continue
		end

		shapeCount += 1
		local part = child :: BasePart
		local localCFrame = baseCFrame:ToObjectSpace(part.CFrame)

		-- 2D position: 3D X -> 2D X, 3D -Z -> 2D Y
		local pos2D = Vector2.new(localCFrame.Position.X, -localCFrame.Position.Z)

		if part.Name == "Circle" then
			-- Use average of X and Z size for radius
			local radius = (part.Size.X + part.Size.Z) / 4
			shapes[`Circle{shapeCount}`] = {
				shape = "Circle",
				position = pos2D,
				radius = radius,
			}
		elseif part.Name == "Box" then
			-- 2D size: X and Z from 3D
			local size2D = Vector2.new(part.Size.X, part.Size.Z)

			-- Rotation around Y axis (3D) -> 2D rotation (CCW)
			local _, rotY, _ = localCFrame:ToOrientation()
			local rotDeg = math.deg(rotY) -- Negate for CCW convention

			-- Snap rotation to 5 degree increments to avoid floating point errors
			rotDeg = math.round(rotDeg / 5) * 5

			shapes[`Box{shapeCount}`] = {
				shape = "Box",
				position = pos2D,
				size = size2D,
				rotation = rotDeg,
			}
		end
	end

	print(shapes)

	return setmetatable({
		shapes = shapes,
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

		for _, shape in map.shapes do
			local hit, t, normal = sweepAgainstShape(radius, currentPos, remainingTravel, shape)
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
		local normalDot = remainingTravel:Dot(hitNormal)
		if normalDot < 0 then
			remainingTravel = remainingTravel - hitNormal * normalDot
		end

		-- Small nudge away from surface to prevent getting stuck
		currentPos = currentPos + hitNormal * 0.001
	end

	return anyCollision, currentPos
end

return Map
