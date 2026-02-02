local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemEntity = require(ReplicatedStorage.Source.Shared.ItemEntity)

local UIController = {}
local SCALE = 50

local RENDER_SERVER_SELF = true

local lastws = nil
local gui = Instance.new("ScreenGui")
gui.Parent = Players.LocalPlayer.PlayerGui
gui.ResetOnSpawn = false
gui.Enabled = false
local mapFrame = Instance.new("Frame")
mapFrame.Position = UDim2.fromScale(0.5, 0.5)
mapFrame.Size = UDim2.fromOffset(0, 0)
mapFrame.BackgroundTransparency = 1
mapFrame.Parent = gui

local playerFramePrefab = ReplicatedStorage.Assets.UI.playerFrame

local playerFrames = {}
local ownFrame = nil
local counterItemFrames = {} -- Track item frames on counters
local counterFrames = {} -- Track counter frames for efficient updates

-- Helper function to create item display frame
local function createItemFrame(itemName: string, parent: GuiObject): Frame
	local itemFrame = Instance.new("Frame")
	local stroke = Instance.new("UIStroke", itemFrame)
	local corner = Instance.new("UICorner", itemFrame)
	local label = Instance.new("TextLabel", itemFrame)

	itemFrame.Size = UDim2.fromOffset(20, 20)
	itemFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	itemFrame.Position = UDim2.fromScale(0.5, 0.3) -- Above the object
	itemFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	itemFrame.ZIndex = 10

	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 1

	corner.CornerRadius = UDim.new(0, 3)

	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = itemName
	label.TextColor3 = Color3.fromRGB(0, 0, 0)
	label.TextScaled = true
	label.Font = Enum.Font.SourceSansBold
	label.ZIndex = 11

	itemFrame.Parent = parent
	return itemFrame
end

function UIController._renderMap(map)
	-- Helper function to render a shape with optional styling
	local function renderShape(id, objData, color, strokeColor)
		local frame = Instance.new("Frame")
		local stroke = Instance.new("UIStroke", frame)
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromOffset(objData.position.X * SCALE, -objData.position.Y * SCALE)
		frame.BackgroundColor3 = color or Color3.fromRGB(100, 100, 100)
		stroke.Color = strokeColor or Color3.fromRGB(255, 255, 255)

		if objData.shape == "Circle" then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 1)
			corner.Parent = frame
			frame.Size = UDim2.fromOffset(objData.radius * 2 * SCALE, objData.radius * 2 * SCALE)
		elseif objData.shape == "Box" then
			frame.Rotation = -objData.rotation
			frame.Size = UDim2.fromOffset(objData.size.X * SCALE, objData.size.Y * SCALE)
		end

		frame.Parent = mapFrame
		print(`RENDERED: {id}, {frame:GetFullName()}`)
	end

	-- Render regular map shapes (gray)
	for id, objData in map.shapes do
		renderShape(id, objData, Color3.fromRGB(100, 100, 100), Color3.fromRGB(255, 255, 255))
	end

	-- Render counters (blue)
	for id, objData in map.counters do
		local counterFrame = Instance.new("Frame")
		local stroke = Instance.new("UIStroke", counterFrame)
		counterFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		counterFrame.Position = UDim2.fromOffset(objData.position.X * SCALE, -objData.position.Y * SCALE)
		counterFrame.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
		stroke.Color = Color3.fromRGB(255, 255, 255)

		if objData.shape == "Circle" then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 1)
			corner.Parent = counterFrame
			counterFrame.Size = UDim2.fromOffset(objData.radius * 2 * SCALE, objData.radius * 2 * SCALE)
		elseif objData.shape == "Box" then
			counterFrame.Rotation = -objData.rotation
			counterFrame.Size = UDim2.fromOffset(objData.size.X * SCALE, objData.size.Y * SCALE)
		end

		counterFrame.Parent = mapFrame
		counterFrames[id] = counterFrame -- Store reference for efficient updates
		print(`RENDERED COUNTER: {id}, {counterFrame:GetFullName()}`)

		-- Initial item rendering
		local counterItem = map.counterStates[id]
		if counterItem then
			counterItemFrames[id] = createItemFrame(counterItem, counterFrame)
		end
	end

	-- Render ingredient boxes (green) with labels
	for id, objData in map.ingredientBoxes do
		local frame = Instance.new("Frame")
		local stroke = Instance.new("UIStroke", frame)
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromOffset(objData.position.X * SCALE, -objData.position.Y * SCALE)
		frame.BackgroundColor3 = Color3.fromRGB(100, 255, 150)
		stroke.Color = Color3.fromRGB(255, 255, 255)

		if objData.shape == "Circle" then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 1)
			corner.Parent = frame
			frame.Size = UDim2.fromOffset(objData.radius * 2 * SCALE, objData.radius * 2 * SCALE)
		elseif objData.shape == "Box" then
			frame.Rotation = -objData.rotation
			frame.Size = UDim2.fromOffset(objData.size.X * SCALE, objData.size.Y * SCALE)
		end

		-- Add ingredient label
		if objData.ingredientName then
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Text = objData.ingredientName
			label.TextColor3 = Color3.fromRGB(0, 0, 0)
			label.TextScaled = true
			label.Font = Enum.Font.SourceSansBold
			label.Parent = frame
		end

		frame.Parent = mapFrame
		print(`RENDERED INGREDIENT: {id}, {frame:GetFullName()}`)
	end

	-- Render spawn markers (red, smaller)
	for id, spawnData in map.spawns do
		local frame = Instance.new("Frame")
		local stroke = Instance.new("UIStroke", frame)
		local corner = Instance.new("UICorner", frame)

		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromOffset(spawnData.position.X * SCALE, -spawnData.position.Y * SCALE)
		frame.Size = UDim2.fromOffset(10, 10) -- Small fixed size for spawn markers
		frame.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
		frame.Rotation = -spawnData.rotation

		stroke.Color = Color3.fromRGB(255, 255, 255)
		corner.CornerRadius = UDim.new(0, 2)

		-- Add team label
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = spawnData.team
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextScaled = true
		label.Font = Enum.Font.SourceSansBold
		label.Parent = frame

		frame.Parent = mapFrame
		print(`RENDERED SPAWN: {id}, {frame:GetFullName()}`)
	end
end

-- Efficient function to update only counter items without re-rendering entire map
function UIController._updateCounterItems(map, itemEntities)
	-- First, clear ALL existing counter item frames to prevent duplication
	for counterId, itemFrame in counterItemFrames do
		if itemFrame then
			itemFrame:Destroy()
		end
	end
	counterItemFrames = {}

	-- Then add item frames for counters that have items
	for counterId, itemId in map.counterStates do
		local counterFrame = counterFrames[counterId]
		if counterFrame and itemId then
			-- Look up entity type from ID
			local entity = ItemEntity.get(itemEntities, itemId)
			local itemType = entity and entity.type or `Item#{itemId}`
			counterItemFrames[counterId] = createItemFrame(itemType, counterFrame)
		end
	end
end

function UIController._renderWorldState(ws: any, itemEntities)
	if lastws == nil then
		gui.Enabled = true
	end

	for playerUserIdString, playerRecord in ws do
		local simState = playerRecord.simulation.state
		local playerFrame = playerFrames[playerUserIdString]
		if not playerFrame then
			local newPlayerFrame = playerFramePrefab:Clone()
			newPlayerFrame.Size = UDim2.fromOffset(simState.radius * 2 * SCALE, simState.radius * 2 * SCALE)
			newPlayerFrame.Parent = mapFrame
			playerFrame = newPlayerFrame
			playerFrames[playerUserIdString] = playerFrame
		end
		playerFrame.Position = UDim2.fromOffset(simState.position.X * SCALE, -simState.position.Y * SCALE)
		playerFrame.Rotation = -simState.rotation
		if playerUserIdString == tostring(Players.LocalPlayer.UserId) then
			playerFrame.Visible = RENDER_SERVER_SELF
		end

		-- Handle held item display
		local existingItemFrame = playerFrame:FindFirstChild("HeldItem")
		if simState.heldItem then
			-- Look up entity type from ID
			local entity = ItemEntity.get(itemEntities, simState.heldItem)
			local itemType = entity and entity.type or `Item#{simState.heldItem}`

			if not existingItemFrame then
				existingItemFrame = createItemFrame(itemType, playerFrame)
				existingItemFrame.Name = "HeldItem"
			else
				existingItemFrame.TextLabel.Text = itemType
			end
		else
			if existingItemFrame then
				existingItemFrame:Destroy()
			end
		end
	end
end

function UIController._renderLocalState(sim: any, itemEntities)
	if not ownFrame then
		local newPlayerFrame = playerFramePrefab:Clone()
		newPlayerFrame.Name = "SELF"
		newPlayerFrame.Size = UDim2.fromOffset(sim.state.radius * 2 * SCALE, sim.state.radius * 2 * SCALE)
		newPlayerFrame.BackgroundColor3 = Color3.new(1, 1, 0)
		newPlayerFrame.Parent = mapFrame
		ownFrame = newPlayerFrame
	end
	ownFrame.Position = UDim2.fromOffset(sim.state.position.X * SCALE, -sim.state.position.Y * SCALE)
	ownFrame.Rotation = -sim.state.rotation

	-- Handle held item display for local player
	local existingItemFrame = ownFrame:FindFirstChild("HeldItem")
	if sim.state.heldItem then
		-- Look up entity type from ID
		local entity = ItemEntity.get(itemEntities, sim.state.heldItem)
		local itemType = entity and entity.type or `Item#{sim.state.heldItem}`

		if not existingItemFrame then
			existingItemFrame = createItemFrame(itemType, ownFrame)
			existingItemFrame.Name = "HeldItem"
		else
			existingItemFrame.TextLabel.Text = itemType
		end
	else
		if existingItemFrame then
			existingItemFrame:Destroy()
		end
	end
end

return UIController
