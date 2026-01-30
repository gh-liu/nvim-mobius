-- Decimal fraction (e.g., 1.5, 3.14)
local M = {
	id = "decimal_fraction",
	priority = 54,  -- More specific than bare integers (has decimal point)
	cyclic = false,
}

local match_scorer = require("mobius.engine.match_scorer")

---@param cursor mobius.Cursor 0-indexed { row, col }
---@return mobius.RuleMatch?
function M.find(cursor)
	local row, col = cursor.row, cursor.col
	local buf = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)
	local line = lines[1] or ""

	-- Match optional sign, digits, decimal point, and fractional digits
	-- Pattern: [-+]?\d+\.\d+
	local pattern = "[+-]?%d+%.%d+"
	local matches = match_scorer.find_all_matches(line, pattern)

	local best = match_scorer.find_best_match(line, matches, col, function(text)
		return { text = text, value = tonumber(text) }
	end)

	return best
end

---@param addend number
---@param metadata? mobius.RuleMetadata
---@return string?
function M.add(addend, metadata)
	if not metadata then
		return nil
	end
	local value = metadata.value
	if not value then
		return nil
	end

	local new_value = value + (addend or 1)

	-- Preserve decimal places from original
	local original_text = metadata.text
	local decimal_places = 0
	if original_text:find("%.") then
		decimal_places = #original_text:sub(original_text:find("%.") + 1)
	end

	local new_text
	if decimal_places > 0 then
		new_text = string.format("%." .. decimal_places .. "f", new_value)
	else
		new_text = tostring(math.floor(new_value))
	end
	-- Cursor at end of replacement (column offset from match start)
	return { text = new_text, cursor = #new_text - 1 }
end

-- Support customization via __call metatable
setmetatable(M, {
	__call = function(self, opts)
		opts = opts or {}
		local result = {
			id = opts.id or self.id,
			priority = opts.priority or self.priority,
			find = self.find,
			add = self.add,
			cyclic = opts.cyclic ~= nil and opts.cyclic or self.cyclic,
		}
		return result
	end,
})

---@cast M mobius.Rule
return M
