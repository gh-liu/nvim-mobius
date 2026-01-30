local M = {
	id = "octal",
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

	local pattern = "0[oO][0-7]+"
	local matches = match_scorer.find_all_matches(line, pattern)

	local best = match_scorer.find_best_match(line, matches, col, function(text)
		-- Remove 0o/0O prefix before parsing: tonumber() with base doesn't recognize the prefix
		local digits = text:sub(3)
		return { text = text, value = tonumber(digits, 8) }
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

	local num_octal_digits = #metadata.text - 2
	local cycle = 8 ^ num_octal_digits
	local raw = value + (addend or 1)

	-- When going below zero, wrap by digit count (0o0 - 1 = 0o7, 0o00 - 1 = 0o77).
	local new_value = raw >= 0 and raw or (raw % cycle)

	local prefix = metadata.text:sub(1, 2)
	local octal_str
	if raw >= 0 then
		octal_str = string.format("%o", new_value)
	else
		octal_str = string.format("%0" .. num_octal_digits .. "o", new_value)
	end
	if prefix == "0O" then
		octal_str = octal_str:upper()
	end

	return prefix .. octal_str
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
