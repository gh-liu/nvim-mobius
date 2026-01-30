local M = {}

local match_scorer = require("mobius.engine.match_scorer")

-- Create semver rule
---@param opts? {priority?: number, id?: string}
---@return mobius.Rule
function M.new(opts)
	opts = opts or {}
	local priority = opts.priority or 60 -- semver: specific format with dots (higher than date)
	local id = opts.id or "semver"

	return {
		id = id,
		priority = priority,
		cyclic = false,

		---@return mobius.RuleMatch?
		find = function(cursor)
			local row, col = cursor.row, cursor.col
			local buf = vim.api.nvim_get_current_buf()
			local lines = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)
			local line = lines[1] or ""

			-- Match semantic version: major.minor.patch
			local pattern = "(%d+)%.(%d+)%.(%d+)"
			local matches = match_scorer.find_all_matches(line, pattern)

			local best = match_scorer.find_best_match(line, matches, col, function(text, match)
				-- Parse version components
				local major, minor, patch = text:match(pattern)
				if not major or not minor or not patch then
					return { text = text, component = "patch", major = 0, minor = 0, patch = 0 }
				end

				-- Determine which component to increment based on cursor position
				-- match is {start_pos, end_pos} (1-indexed)
				-- cursor_offset is 1-indexed position within the match
				local start_pos = match[1]
				local cursor_offset = col + 2 - start_pos
				local component = "patch"
				-- Clamp cursor_offset to valid range to handle edge cases
				if cursor_offset < 1 then
					cursor_offset = 1
				elseif cursor_offset > #text then
					cursor_offset = #text
				end
				if cursor_offset >= 1 and cursor_offset <= #text then
					local major_end = #major
					local minor_start = major_end + 2
					local minor_end = minor_start + #minor - 1

					if cursor_offset <= major_end then
						component = "major"
					elseif cursor_offset >= minor_start and cursor_offset <= minor_end then
						component = "minor"
					else
						component = "patch"
					end
				end

				return {
					text = text,
					component = component,
					major = tonumber(major),
					minor = tonumber(minor),
					patch = tonumber(patch),
				}
			end)

			return best
		end,

		---@param addend number
		---@param metadata? mobius.RuleMetadata
		---@return string?
		add = function(addend, metadata)
			if not metadata then
				return nil
			end
			local major = metadata.major
			local minor = metadata.minor
			local patch = metadata.patch
			local component = metadata.component

			-- Apply increment based on component
			if component == "major" then
				major = major + addend
				if major < 0 then
					return nil -- Cannot go below 0
				end
				-- Reset minor and patch when major increments
				minor = 0
				patch = 0
			elseif component == "minor" then
				minor = minor + addend
				if minor < 0 then
					return nil -- Cannot go below 0
				end
				-- Reset patch when minor increments
				patch = 0
			else -- patch
				patch = patch + addend
				if patch < 0 then
					return nil -- Cannot go below 0
				end
			end

			return string.format("%d.%d.%d", major, minor, patch)
		end,
	}
end

-- Support direct call
setmetatable(M, {
	__call = function(self, opts)
		return self.new(opts)
	end,
})

return M
