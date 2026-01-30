---@alias mobius.WordRange { [1]: number, [2]: number } 1-indexed [start_pos, end_pos] inclusive

local M = {}

-- Unified word boundary handling for rules that need to match complete words only.
-- Only whole words match: "true way" matches "true", "trueway" does not match "true".

-- Check if a position is at a word boundary (beginning of line or preceded by non-word char)
---@param line string
---@param pos number 1-indexed
---@return boolean
local function is_word_start(line, pos)
	if pos == 1 then
		return true
	end
	local char = line:sub(pos - 1, pos - 1)
	return not char:match("%w")
end

-- Check if a position is at a word boundary (end of line or followed by non-word char)
---@param line string
---@param pos number 1-indexed
---@return boolean
local function is_word_end(line, pos)
	if pos == #line then
		return true
	end
	local char = line:sub(pos + 1, pos + 1)
	return not char:match("%w")
end

-- Find all word-boundary-constrained matches in a line.
-- Only matches when word_text is a complete word (e.g. "true" in "true way", not in "trueway").
---@param line string
---@param word_text string
---@return mobius.WordRange[]
function M.find_word_matches(line, word_text)
	local matches = {}
	local start_pos = 1

	while true do
		local pos = line:find(word_text, start_pos, true) -- true = plain text search
		if not pos then
			break
		end

		local end_pos = pos + #word_text - 1

		-- Check word boundaries
		if is_word_start(line, pos) and is_word_end(line, end_pos) then
			table.insert(matches, { pos, end_pos })
		end

		start_pos = pos + 1
	end

	return matches
end

-- Find all matches in a line using a Lua pattern with word boundary enforcement.
---@param line string
---@param pattern string Lua pattern (e.g. "%d+", "[a-z]+")
---@return mobius.WordRange[]
function M.find_pattern_matches(line, pattern)
	local matches = {}
	local start_pos, end_pos = line:find(pattern)

	while start_pos do
		if is_word_start(line, start_pos) and is_word_end(line, end_pos) then
			table.insert(matches, { start_pos, end_pos })
		end
		start_pos, end_pos = line:find(pattern, end_pos + 1)
	end

	return matches
end

-- Find all matches using Lua's %f frontier pattern (boundary already in pattern).
---@param line string
---@param pattern_with_boundary string e.g. "%f[%w]word%f[^%w]"
---@return mobius.WordRange[]
function M.find_frontier_matches(line, pattern_with_boundary)
	local matches = {}
	local start_pos, end_pos = line:find(pattern_with_boundary)

	while start_pos do
		table.insert(matches, { start_pos, end_pos })
		start_pos, end_pos = line:find(pattern_with_boundary, end_pos + 1)
	end

	return matches
end

return M
