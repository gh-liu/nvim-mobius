-- Bracket/parenthesis swapping: () <-> [] <-> {}
local M = {
	id = "paren",
	priority = 58,  -- Higher than numeric; clearly distinguishable
	cyclic = true,
}

local match_scorer = require("mobius.engine.match_scorer")

-- Bracket pairs in cycling order
local bracket_pairs = {
	{ open = "(", close = ")" },
	{ open = "[", close = "]" },
	{ open = "{", close = "}" },
}

--- Find matching closing bracket, handling nesting
---@param line string
---@param start_idx number Position of opening bracket (1-indexed)
---@param open string Opening bracket character
---@param close string Closing bracket character
---@return number? Position of closing bracket (1-indexed)
local function find_matching_closing(line, start_idx, open, close)
	local depth = 1
	local idx = start_idx + 1
	while idx <= #line and depth > 0 do
		local char = line:sub(idx, idx)
		if char == open then
			depth = depth + 1
		elseif char == close then
			depth = depth - 1
		end
		idx = idx + 1
	end
	return depth == 0 and (idx - 1) or nil
end

--- Find all bracket pairs in line
---@param line string
---@param col number 0-indexed cursor position
---@return { start: number, end_: number, open: string, close: string }[]
local function find_all_bracket_pairs(line, col)
	local pairs = {}

	for _, bracket in ipairs(bracket_pairs) do
		local idx = 1
		while idx <= #line do
			local open_idx = line:find(bracket.open, idx, true)
			if not open_idx then
				break
			end

			local close_idx = find_matching_closing(line, open_idx, bracket.open, bracket.close)
			if close_idx then
				table.insert(pairs, {
					start = open_idx,
					end_ = close_idx,
					open = bracket.open,
					close = bracket.close,
				})
				idx = close_idx + 1
			else
				idx = open_idx + 1
			end
		end
	end

	return pairs
end

---@param cursor mobius.Cursor 0-indexed { row, col }
---@return mobius.RuleMatch?
function M.find(cursor)
	local row, col = cursor.row, cursor.col
	local buf = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)
	local line = lines[1] or ""

	-- Find all bracket pairs
	local pairs = find_all_bracket_pairs(line, col)
	if #pairs == 0 then
		return nil
	end

	-- Convert to match format and use scorer
	local matches = {}
	for _, pair in ipairs(pairs) do
		table.insert(matches, {
			pair.start,
			pair.end_,
			pair.open .. pair.close,
			open = pair.open,
			close = pair.close,
		})
	end

	local best = match_scorer.find_best_match(line, matches, col, function(text, match)
		-- Preserve content between brackets (text is open..inner..close)
		local inner = #text >= 2 and text:sub(2, -2) or ""
		return { text = text, open = match.open, close = match.close, inner = inner }
	end)

	-- Only apply when cursor is on the open or close bracket, not on content inside
	if best and (col ~= best.col and col ~= best.end_col) then
		return nil
	end
	return best
end

---@param addend number
---@param metadata? mobius.RuleMetadata
---@return string?
function M.add(addend, metadata)
	if not metadata then
		return nil
	end
	local current_open = metadata.open
	local current_close = metadata.close

	-- Find current bracket in the cycle
	local current_idx = nil
	for i, bracket in ipairs(bracket_pairs) do
		if bracket.open == current_open and bracket.close == current_close then
			current_idx = i
			break
		end
	end

	if not current_idx then
		return nil
	end

	-- Calculate next bracket index
	local n = #bracket_pairs
	local next_idx
	if addend >= 0 then
		next_idx = ((current_idx - 1 + addend) % n) + 1
	else
		next_idx = ((current_idx - 1 + addend) % n + n) % n + 1
	end

	local next_bracket = bracket_pairs[next_idx]
	local inner = (metadata.inner ~= nil) and metadata.inner or ""
	return next_bracket.open .. inner .. next_bracket.close
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
