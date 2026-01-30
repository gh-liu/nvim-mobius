local constants = require("mobius.engine.constants")
local match_scorer = require("mobius.engine.match_scorer")

local M = {}

-- Create hexcolor rule
---@param opts? {case?: string, priority?: number, id?: string}
---@return mobius.Rule
function M.new(opts)
	opts = opts or {}
	local case = opts.case or "prefer_lower" -- upper, lower, prefer_upper, prefer_lower
	local priority = opts.priority or 60 -- hexcolor: specific format #RRGGBB
	local id = opts.id or "hexcolor"

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

			-- Match hex color: #RRGGBB or #RGB
			-- Try 6-digit first, then 3-digit
			local matches = {}
			local pattern6 = "#[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]"
			local pattern3 = "#[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]"

			-- Find all 6-digit hex colors
			local start = 1
			while true do
				local s, e = line:find(pattern6, start)
				if not s then
					break
				end
				table.insert(matches, { s, e })
				start = e + 1
			end

			-- Find all 3-digit hex colors (but avoid matching first 3 chars of a 6-digit)
			start = 1
			while true do
				local s, e = line:find(pattern3, start)
				if not s then
					break
				end
				-- Check if this is not part of a 6-digit pattern already found
				local is_part_of_6 = false
				for _, match in ipairs(matches) do
					if s >= match[1] and e <= match[2] then
						is_part_of_6 = true
						break
					end
				end
				if not is_part_of_6 then
					table.insert(matches, { s, e })
				end
				start = e + 1
			end

			-- Find best match and determine which color component cursor is on
			local best = match_scorer.find_best_match(line, matches, col, function(text, match)
				-- match is {start_pos, end_pos} (1-indexed)
				-- cursor_offset is 1-indexed position within the match
				local start_pos = match[1]
				-- Determine which component cursor is on
				local cursor_offset = col + 2 - start_pos
				local component = "all"
				if cursor_offset > 0 and cursor_offset <= #text then
					if text:len() == 7 then -- #RRGGBB format
						if cursor_offset >= 2 and cursor_offset <= 3 then
							component = "r"
						elseif cursor_offset >= 4 and cursor_offset <= 5 then
							component = "g"
						elseif cursor_offset >= 6 and cursor_offset <= 7 then
							component = "b"
						end
					elseif text:len() == 4 then -- #RGB format
						if cursor_offset == 2 then
							component = "r"
						elseif cursor_offset == 3 then
							component = "g"
						elseif cursor_offset == 4 then
							component = "b"
						end
					end
				end

				-- Parse hex values
				local hex_str = text:sub(2) -- Remove #
				local r, g, b
				if #hex_str == 6 then
					r = tonumber(hex_str:sub(1, 2), 16)
					g = tonumber(hex_str:sub(3, 4), 16)
					b = tonumber(hex_str:sub(5, 6), 16)
				else -- 3-digit format
					r = tonumber(hex_str:sub(1, 1) .. hex_str:sub(1, 1), 16)
					g = tonumber(hex_str:sub(2, 2) .. hex_str:sub(2, 2), 16)
					b = tonumber(hex_str:sub(3, 3) .. hex_str:sub(3, 3), 16)
				end

				return {
					text = text,
					component = component,
					r = r,
					g = g,
					b = b,
					original_case = text:match("[a-fA-F]") and (text:match("[A-F]") and "upper" or "lower") or nil,
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
			local r, g, b = metadata.r, metadata.g, metadata.b
			local component = metadata.component
			local case_option = case
			local original_case = metadata.original_case

			-- Apply increment to the appropriate component
			if component == "r" then
				r = math.max(constants.RGB_MIN, math.min(constants.RGB_MAX, r + addend))
			elseif component == "g" then
				g = math.max(constants.RGB_MIN, math.min(constants.RGB_MAX, g + addend))
			elseif component == "b" then
				b = math.max(constants.RGB_MIN, math.min(constants.RGB_MAX, b + addend))
			else
				-- Increment all components
				r = math.max(constants.RGB_MIN, math.min(constants.RGB_MAX, r + addend))
				g = math.max(constants.RGB_MIN, math.min(constants.RGB_MAX, g + addend))
				b = math.max(constants.RGB_MIN, math.min(constants.RGB_MAX, b + addend))
			end

			-- Format hex string
			local hex_str = string.format("%02x%02x%02x", r, g, b)

			-- Handle case option
			if case_option == "upper" then
				hex_str = hex_str:upper()
			elseif case_option == "lower" then
				hex_str = hex_str:lower()
			elseif case_option == "prefer_upper" then
				if original_case == "upper" then
					hex_str = hex_str:upper()
				elseif original_case == "lower" then
					hex_str = hex_str:lower()
				else
					hex_str = hex_str:upper() -- Default to upper
				end
			elseif case_option == "prefer_lower" then
				if original_case == "lower" then
					hex_str = hex_str:lower()
				elseif original_case == "upper" then
					hex_str = hex_str:upper()
				else
					hex_str = hex_str:lower() -- Default to lower
				end
			end

			return "#" .. hex_str
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
