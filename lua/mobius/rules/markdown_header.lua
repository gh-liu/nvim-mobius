local constants = require("mobius.engine.constants")

local M = {}

-- Create markdown header rule
---@param opts? {priority?: number, id?: string}
---@return mobius.Rule
function M.new(opts)
	opts = opts or {}
	local priority = opts.priority or 70 -- markdown_header: highest (pure structure, no conflict)
	local id = opts.id or "markdown_header"

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

			-- Match markdown header: # Header (MIN-MAX #)
			-- Special: also match when cursor is after # (unlike other rules)
			local pattern = "^(#+)"
			local match_text = line:match(pattern)

			if not match_text then
				return nil
			end

			local start_pos = 1
			local end_pos = #match_text
			local count = end_pos

			-- Check if cursor is on or after the header
			-- Special handling: match even if cursor is after #
			if col + 1 < start_pos then
				return nil
			end

			-- Validate: must be followed by space
			if line:sub(end_pos + 1, end_pos + 1) ~= " " then
				return nil
			end

			-- Limit to MIN-MAX header levels
			if count < constants.MIN_HEADER_LEVEL or count > constants.MAX_HEADER_LEVEL then
				return nil
			end

			return {
				col = start_pos - 1,
				end_col = end_pos - 1,
				metadata = {
					text = match_text,
					count = count,
				},
			}
		end,

		---@param addend number
		---@param metadata? mobius.RuleMetadata
		---@return string?
		add = function(addend, metadata)
			if not metadata then
				return nil
			end
			local count = metadata.count + addend

			-- Limit to MIN-MAX header levels
			if count < constants.MIN_HEADER_LEVEL or count > constants.MAX_HEADER_LEVEL then
				return nil
			end

			return string.rep("#", count)
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
