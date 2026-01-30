local M = {
	id = "integer",
	priority = 50,  -- Base numeric type; other numeric types override this
	cyclic = false,
}

local match_scorer = require("mobius.engine.match_scorer")
local rule_result = require("mobius.engine.rule_result")

---@param cursor mobius.Cursor 0-indexed { row, col }
---@return mobius.RuleMatch?
function M.find(cursor)
	local row, col = cursor.row, cursor.col
	local buf = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)
	local line = lines[1] or ""

	-- Match optional sign then digits so "-1" and "+1" are one number each
	local pattern = "[+-]?%d+"
	local matches = match_scorer.find_all_matches(line, pattern)

	local best = match_scorer.find_best_match(line, matches, col, function(text)
		return { text = text }
	end)

	return best
end

---@param addend number
---@param metadata? mobius.RuleMetadata
---@return string?
function M.add(addend, metadata)
	if not metadata or not metadata.text then
		return nil
	end
	local num = tonumber(metadata.text)
	if not num then
		return nil
	end
	return tostring(num + (addend or 1))
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
