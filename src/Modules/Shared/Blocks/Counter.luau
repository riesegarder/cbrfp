return {
	Interact = function(block, character, blockItem, charItem)
		local charItemId = character.itemId
		local blockItemId = block.itemId
		if charItemId and blockItemId then
			-- try to combine
		elseif charItemId and blockItemId == nil then
			-- put on counter
			character.itemId = nil
			block.itemId = charItemId
		elseif charItemId == nil and blockItemId then
			-- take from counter
			block.itemId = nil 
			character.itemId = blockItemId
		end
	end,
}