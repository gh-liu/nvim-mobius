local M = {}

-- Unified factory for rule find() results
-- Ensures all rules return consistent structure: {col, end_col, metadata}
-- where metadata must contain 'text' field

-- Create a match result from match data
-- Parameters:
--   match_start: 1-indexed start position
--   match_end: 1-indexed end position (inclusive)
--   match_text: the matched text
--   extra_metadata: optional table with additional metadata fields
-- Returns: {col, end_col, metadata}
---@param match_start number 1-indexed
---@param match_end number 1-indexed inclusive
---@param match_text string
---@param extra_metadata? mobius.RuleMetadata
---@return mobius.RuleMatch
function M.match(match_start, match_end, match_text, extra_metadata)
	extra_metadata = extra_metadata or {}

	return {
		col = match_start - 1, -- Convert to 0-indexed
		end_col = match_end - 1, -- Convert to 0-indexed, inclusive
		metadata = vim.tbl_extend("keep", { text = match_text }, extra_metadata),
	}
end

-- Validate a find() result structure
-- Returns: true if valid, false + error message otherwise
---@param result mobius.RuleMatch?
---@return boolean valid
---@return string? err
function M.validate(result)
	if result == nil then
		return true -- nil is valid (no match found)
	end

	if type(result) ~= "table" then
		return false, "Result must be a table"
	end

	if type(result.col) ~= "number" or type(result.end_col) ~= "number" then
		return false, "Result must have col and end_col as numbers"
	end

	if result.col < 0 or result.end_col < result.col then
		return false, "col and end_col must be 0-indexed with col <= end_col"
	end

	if type(result.metadata) ~= "table" then
		return false, "Result must have metadata table"
	end

	if type(result.metadata.text) ~= "string" then
		return false, "metadata.text must be a string"
	end

	return true
end

return M
