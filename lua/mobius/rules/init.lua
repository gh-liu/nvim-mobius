local M = {}

-- Constant toggle rules (flat or grouped elements)
M.constant = require("mobius.rules.constant")

-- Numeric rules (number, hex)
M.numeric = require("mobius.rules.numeric")

local match_scorer = require("mobius.engine.match_scorer")
local word_boundary = require("mobius.engine.word_boundary")

-- Simple regex-based rule factory
-- Recommended for straightforward pattern matching without complex metadata extraction
-- Parameters:
--   pattern: Lua regex pattern (e.g., "%d+", "[a-z]+")
--   add: function(metadata, addend) -> new_text
--   opts: optional {priority, cyclic, word, id}
--     word: if true, enforce word boundary matching
---@param opts {pattern: string, add: fun(metadata: mobius.RuleMetadata, addend: number): string?, priority?: number, cyclic?: boolean, word?: boolean, id?: string}
---@return mobius.Rule
function M.pattern(opts)
	opts = opts or {}

	local pattern = opts.pattern
	local add_fn = opts.add ---@type fun(metadata: mobius.RuleMetadata, addend: number): string?
	local cyclic = opts.cyclic or false
	local word = opts.word or false
	local priority = opts.priority or 50 -- Baseline; users can override
	local id = opts.id or ("pattern_" .. pattern:gsub("%W", "_"))

	---@param row number
	---@param col number
	---@return mobius.RuleMatch?
	local find_func = function(row, col)
		local buf = vim.api.nvim_get_current_buf()
		local lines = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)
		local line = lines[1] or ""

		local matches
		if word then
			-- Use word boundary matching
			matches = word_boundary.find_pattern_matches(line, pattern)
		else
			-- Simple pattern matching without boundaries
			matches = match_scorer.find_all_matches(line, pattern)
		end

		-- Find best match using unified scorer
		local best = match_scorer.find_best_match(line, matches, col, function(text)
			return { text = text }
		end)

		return best
	end

	return {
		id = id,
		priority = priority,
		find = find_func,
		add = add_fn,
		cyclic = cyclic,
	}
end

return M
