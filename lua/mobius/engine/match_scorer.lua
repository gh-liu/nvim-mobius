local constants = require("mobius.engine.constants")

local M = {}

-- Unified match scoring algorithm used across all rules
-- Scoring strategy:
--   - Match contains cursor: 1000 + match_length
--   - Match after cursor: 100 - (distance_to_start)
--   - Match before cursor: -100 - (distance_from_end)
--   - Bonus for longer matches: length * 0.1
--   - Rule priority bonus: priority * 0.01 (applied in engine, not here)

---@param match_start number 1-indexed
---@param match_end number 1-indexed inclusive
---@param cursor_col number 0-indexed
---@param match_length number
---@return number
function M.calculate_score(match_start, match_end, cursor_col, match_length)
	local score = 0

	-- Check if match contains cursor
	-- Note: match_start and match_end are 1-indexed; cursor_col is 0-indexed
	if match_start <= cursor_col + 1 and match_end >= cursor_col + 1 then
		score = constants.SCORE_CONTAINS_CURSOR + match_length
	elseif match_start > cursor_col + 1 then
		score = constants.SCORE_AFTER_CURSOR_BASE - (match_start - cursor_col)
	else
		score = constants.SCORE_BEFORE_CURSOR_BASE - (cursor_col - match_end)
	end

	-- Prefer longer matches
	score = score + match_length * constants.SCORE_LENGTH_MULTIPLIER

	return score
end

-- Score for engine: given a RuleMatch (0-indexed col/end_col), cursor_col, and rule priority.
-- Single place for cross-rule comparison so engine and rule-internal scoring stay in sync.
---@param match mobius.RuleMatch
---@param cursor_col number 0-indexed
---@param rule_priority number
---@return number
function M.score_for_rule_match(match, cursor_col, rule_priority)
	local match_len = match.end_col - match.col + 1
	local base = M.calculate_score(match.col + 1, match.end_col + 1, cursor_col, match_len)
	return base + (rule_priority or constants.DEFAULT_PRIORITY) * constants.SCORE_PRIORITY_MULTIPLIER
end

-- Helper to find all matches in a line using Lua pattern
-- Returns: list of {start_pos, end_pos} (1-indexed)
---@param line string
---@param pattern string
---@return { [1]: number, [2]: number }[]
function M.find_all_matches(line, pattern)
	local matches = {}
	local start_pos, end_pos = line:find(pattern)
	while start_pos do
		table.insert(matches, { start_pos, end_pos })
		start_pos, end_pos = line:find(pattern, end_pos + 1)
	end
	return matches
end

-- Find best match from a list of candidates using scoring
-- Returns: best match table {col, end_col, metadata} or nil
---@param line string
---@param matches { [1]: number, [2]: number }[]
---@param cursor_col number 0-indexed
---@param metadata_extractor fun(text: string, match: { [1]: number, [2]: number }): mobius.RuleMetadata
---@return mobius.RuleMatch?
function M.find_best_match(line, matches, cursor_col, metadata_extractor)
	if #matches == 0 then
		return nil
	end

	local best_match = nil
	local best_score = -math.huge

	for _, match in ipairs(matches) do
		local start_pos, end_pos = match[1], match[2]
		local match_len = end_pos - start_pos + 1
		local score = M.calculate_score(start_pos, end_pos, cursor_col, match_len)

		if score > best_score then
			best_score = score
			local text = line:sub(start_pos, end_pos)
			best_match = {
				col = start_pos - 1, -- Convert to 0-indexed
				end_col = end_pos - 1, -- Convert to 0-indexed, inclusive
				metadata = metadata_extractor(text, match),
			}
		end
	end

	return best_match
end

return M
