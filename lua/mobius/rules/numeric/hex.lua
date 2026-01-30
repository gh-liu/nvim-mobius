local M = {
	id = "hex",
	priority = 51,
	cyclic = true,
}

local match_scorer = require("mobius.engine.match_scorer")

---@param cursor mobius.Cursor 0-indexed { row, col }
---@return mobius.RuleMatch?
function M.find(cursor)
	local row, col = cursor.row, cursor.col
	local buf = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)
	local line = lines[1] or ""

	local pattern = "0[xX][0-9a-fA-F]+"
	local matches = match_scorer.find_all_matches(line, pattern)

	local best = match_scorer.find_best_match(line, matches, col, function(text)
		-- Remove 0x/0X prefix before parsing: tonumber() with base doesn't recognize the prefix
		local digits = text:sub(3)
		return { text = text, value = tonumber(digits, 16) }
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

	local num_hex_digits = #metadata.text - 2
	local cycle = 16 ^ num_hex_digits
	local raw = value + (addend or 1)

	-- When going below zero, wrap by digit count (0x0 - 1 = 0xf, 0x00 - 1 = 0xff).
	-- Avoids raw = -1 formatting as 0xffffffffffffffff. Increment overflow still grows (0xff+1 = 0x100).
	local new_value = raw >= 0 and raw or (raw % cycle)

	local prefix = metadata.text:sub(1, 2)
	local hex_str
	if raw >= 0 then
		hex_str = string.format("%x", new_value)
	else
		hex_str = string.format("%0" .. num_hex_digits .. "x", new_value)
	end
	if prefix == "0X" then
		hex_str = hex_str:upper()
	end

	return prefix .. hex_str
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
