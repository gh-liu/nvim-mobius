-- Decimal fraction (e.g., 1.5, 3.14)
local M = {
	id = "decimal_fraction",
	priority = 54,  -- More specific than bare integers (has decimal point)
	cyclic = false,
}

local match_scorer = require("mobius.engine.match_scorer")

---@param cursor mobius.Cursor 0-indexed { row, col }
---@return mobius.RuleMatch?
function M.find(cursor)
	local row, col = cursor.row, cursor.col
	local buf = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)
	local line = lines[1] or ""

	-- Match optional sign, digits, decimal point, and fractional digits
	-- Pattern: [-+]?\d+\.\d+
	local pattern = "[+-]?%d+%.%d+"
	local matches = match_scorer.find_all_matches(line, pattern)

	local best = match_scorer.find_best_match(line, matches, col, function(text, match)
		local metadata = {
			text = text,
			value = tonumber(text),
		}
		-- Calculate cursor offset relative to start of match
		-- match[1] is 1-indexed start position
		-- col is 0-indexed cursor position
		-- cursor_offset = how many chars from match start to cursor
		if col + 1 >= match[1] and col + 1 <= match[2] + 1 then
			-- Cursor is within this match
			metadata.cursor_offset = col + 1 - match[1]  -- 0-indexed offset from match start
		end
		return metadata
	end)

	return best
end

---@param addend number
---@param metadata? mobius.RuleMetadata
---@return string?|{text: string, cursor: number}
function M.add(addend, metadata)
	if not metadata then
		return nil
	end
	
	local original_text = metadata.text
	local cursor_offset = metadata.cursor_offset

	-- If cursor_offset is not provided, operate on the whole number (backward compat)
	if not cursor_offset then
		local value = metadata.value
		if not value then
			return nil
		end
		local new_value = value + (addend or 1)

		local decimal_places = 0
		local dot_pos = original_text:find("%.")
		if dot_pos then
			decimal_places = #original_text:sub(dot_pos + 1)
		end

		local has_positive_sign = original_text:match("^%+")
		
		local new_text
		if decimal_places > 0 then
			new_text = string.format("%." .. decimal_places .. "f", new_value)
		else
			new_text = tostring(math.floor(new_value))
		end
		
		if has_positive_sign and not new_text:match("^%-") then
			new_text = "+" .. new_text
		end
		
		return { text = new_text, cursor = #new_text - 1 }
	end

	-- Cursor is inside the match, determine which part to modify
	local dot_pos = original_text:find("%.")
	if not dot_pos then
		-- No decimal point found (shouldn't happen for decimal_fraction)
		return nil
	end

	-- cursor_offset is relative to start of match (0-indexed within match.col .. match.end_col)
	local pos_in_number = cursor_offset + 1  -- Convert to 1-indexed position within original_text

	-- Determine if cursor is before or after decimal point
	-- Cursor on or before decimal point = modify integer part
	local cursor_before_dot = pos_in_number <= dot_pos
	
	if cursor_before_dot then
		-- Cursor before decimal: modify integer part
		local sign = ""
		local integer_part = ""
		local frac_part = ""
		
		-- Extract sign
		local sign_match = original_text:match("^([+-])")
		if sign_match then
			sign = sign_match
		end
		
		-- Extract integer and fractional parts
		local num_part = original_text:gsub("^[+-]", "")  -- Remove sign
		integer_part, frac_part = num_part:match("^(%d+)%.(%d+)$")
		
		if not integer_part or not frac_part then
			return nil
		end

		local int_val = tonumber(integer_part)
		if not int_val then
			return nil
		end

		-- Modify integer value considering sign
		-- For -3.2: if sign is "-", the actual value is -3, so -3 + 1 = -2
		local actual_value = (sign == "-") and -int_val or int_val
		local new_actual_value = actual_value + (addend or 1)
		
		-- Extract new sign and absolute value
		local new_sign = ""
		local new_int_abs = new_actual_value
		if new_actual_value < 0 then
			new_sign = "-"
			new_int_abs = -new_actual_value
		end
		
		local new_text = new_sign .. tostring(new_int_abs) .. "." .. frac_part
		
		-- Cursor stays on integer part (at the end)
		local int_len = #tostring(new_int_abs)
		local sign_len = #new_sign
		return { text = new_text, cursor = sign_len + int_len - 1 }
	else
		-- Cursor after decimal: modify the digit at cursor position (not always last place)
		-- e.g. "1.46" with cursor on "4" (tenths): add 0.1 -> 1.56; on "6" (hundredths): add 0.01 -> 1.47
		local num_part = original_text:gsub("^[+-]", "")  -- Remove sign
		local integer_part, frac_part = num_part:match("^(%d+)%.(%d+)$")
		
		if not integer_part or not frac_part then
			return nil
		end

		local frac_val = tonumber(frac_part)
		local decimal_places = #frac_part
		-- Which decimal place is the cursor in? (1 = first digit after dot, e.g. tenths)
		local cursor_place = pos_in_number - dot_pos
		if cursor_place < 1 then
			cursor_place = 1
		elseif cursor_place > decimal_places then
			cursor_place = decimal_places
		end
		local frac_addend = addend * (10 ^ (-cursor_place))
		
		local int_val = tonumber(integer_part)
		local full_val = int_val + frac_val / (10 ^ decimal_places)
		local new_full_val = full_val + frac_addend

		-- Check for sign in original
		local sign = ""
		local sign_match = original_text:match("^([+-])")
		if sign_match then
			sign = sign_match
		end

		-- Format result preserving decimal places
		local new_text = string.format("%s%." .. decimal_places .. "f", sign, new_full_val)
		
		-- Cursor stays on the digit we modified (same decimal place)
		local sign_len = #sign
		local int_part_new = tostring(math.floor(math.abs(new_full_val)))
		local cursor_on_digit = sign_len + #int_part_new + 1 + (cursor_place - 1) - 1  -- 0-indexed
		return { text = new_text, cursor = cursor_on_digit }
	end
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
