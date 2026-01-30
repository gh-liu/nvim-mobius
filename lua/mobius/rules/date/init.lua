local constants = require("mobius.engine.constants")

local M = {}

-- Helper to get days in month
local function days_in_month(year, month)
	if not month or month < 1 or month > 12 then
		return 31 -- fallback
	end
	local days = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
	if (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0) then
		days[2] = 29
	end
	return days[month]
end

-- Build regex pattern from date pattern.
-- Use placeholders so %%d does not replace %d inside already-expanded %%Y/%%m (gsub is global).
local PH = {
	Y4 = "@Y4@",
	y2 = "@y2@",
	y2q = "@y2q@",
	m2 = "@m2@",
	m2q = "@m2q@",
	d2 = "@d2@",
	d2q = "@d2q@",
	H2 = "@H2@",
	H2q = "@H2q@",
	I2 = "@I2@",
	I2q = "@I2q@",
	M2 = "@M2@",
	M2q = "@M2q@",
	S2 = "@S2@",
	S2q = "@S2q@",
}

local function build_regex_pattern(pattern)
	local regex = pattern
		:gsub("%%%%", "\1PCT\1")
		:gsub("%%-y", "(" .. PH.y2q .. ")")
		:gsub("%%-m", "(" .. PH.m2q .. ")")
		:gsub("%%-d", "(" .. PH.d2q .. ")")
		:gsub("%%-H", "(" .. PH.H2q .. ")")
		:gsub("%%-I", "(" .. PH.I2q .. ")")
		:gsub("%%-M", "(" .. PH.M2q .. ")")
		:gsub("%%-S", "(" .. PH.S2q .. ")")
		:gsub("%%Y", "(" .. PH.Y4 .. ")")
		:gsub("%%y", "(" .. PH.y2 .. ")")
		:gsub("%%m", "(" .. PH.m2 .. ")")
		:gsub("%%d", "(" .. PH.d2 .. ")")
		:gsub("%%H", "(" .. PH.H2 .. ")")
		:gsub("%%I", "(" .. PH.I2 .. ")")
		:gsub("%%M", "(" .. PH.M2 .. ")")
		:gsub("%%S", "(" .. PH.S2 .. ")")
		:gsub("\1PCT\1", "%%")
	regex = regex
		:gsub(PH.Y4, "%%d%%d%%d%%d")
		:gsub(PH.y2, "%%d%%d")
		:gsub(PH.y2q, "%%d%%d?")
		:gsub(PH.m2, "%%d%%d")
		:gsub(PH.m2q, "%%d%%d?")
		:gsub(PH.d2, "%%d%%d")
		:gsub(PH.d2q, "%%d%%d?")
		:gsub(PH.H2, "%%d%%d")
		:gsub(PH.H2q, "%%d%%d?")
		:gsub(PH.I2, "%%d%%d")
		:gsub(PH.I2q, "%%d%%d?")
		:gsub(PH.M2, "%%d%%d")
		:gsub(PH.M2q, "%%d%%d?")
		:gsub(PH.S2, "%%d%%d")
		:gsub(PH.S2q, "%%d%%d?")
	regex = regex:gsub("%-", "%%-")
	return regex
end

-- Parse date pattern to extract component information
local function parse_date_pattern(pattern)
	local components = {}
	local i = 1
	while i <= #pattern do
		if pattern:sub(i, i) == "%" then
			local next = pattern:sub(i + 1, i + 1)
			if next == "-" then
				local spec = pattern:sub(i + 2, i + 2)
				if
					spec == "Y"
					or spec == "y"
					or spec == "m"
					or spec == "d"
					or spec == "H"
					or spec == "I"
					or spec == "M"
					or spec == "S"
				then
					table.insert(components, { type = spec, pos = i, padding = false })
					i = i + 3
				else
					i = i + 1
				end
			elseif
				next == "Y"
				or next == "y"
				or next == "m"
				or next == "d"
				or next == "H"
				or next == "I"
				or next == "M"
				or next == "S"
			then
				table.insert(components, { type = next, pos = i, padding = true })
				i = i + 2
			elseif next == "%" then
				i = i + 2
			else
				i = i + 1
			end
		else
			i = i + 1
		end
	end
	return components
end

-- Determine which component to increment based on cursor position in matched text
-- Returns: component name string, or nil if cursor is not on a valid component
local function determine_component(pattern, match_text, cursor_offset, default_kind)
	-- Parse components from pattern
	local components = {}
	local i = 1
	while i <= #pattern do
		if pattern:sub(i, i) == "%" then
			local next = pattern:sub(i + 1, i + 1)
			if next == "-" then
				local spec = pattern:sub(i + 2, i + 2)
				if
					spec == "Y"
					or spec == "y"
					or spec == "m"
					or spec == "d"
					or spec == "H"
					or spec == "I"
					or spec == "M"
					or spec == "S"
				then
					table.insert(components, { type = spec, pos = i, padding = false })
					i = i + 3
				else
					i = i + 1
				end
			elseif
				next == "Y"
				or next == "y"
				or next == "m"
				or next == "d"
				or next == "H"
				or next == "I"
				or next == "M"
				or next == "S"
			then
				table.insert(components, { type = next, pos = i, padding = true })
				i = i + 2
			elseif next == "%" then
				i = i + 2
			else
				i = i + 1
			end
		else
			i = i + 1
		end
	end

	-- Length in match text for each specifier: Y=4, others 2 or 1
	local spec_len = { Y = 4, y = 2, m = 2, d = 2, H = 2, I = 2, M = 2, S = 2 }
	local match_pos = 0

	for i, comp in ipairs(components) do
		local pat_len = comp.padding and 2 or 3 -- %Y vs %-Y
		local comp_len = spec_len[comp.type] or (comp.padding and 2 or 1)

		-- Calculate literal characters between previous component and this one
		local pattern_end_prev
		if i == 1 then
			pattern_end_prev = 0
		else
			local prev_pat_len = components[i - 1].padding and 2 or 3
			pattern_end_prev = components[i - 1].pos + prev_pat_len - 1
		end

		local literal_len = comp.pos - pattern_end_prev - 1

		-- Add literal characters from pattern to match_pos (e.g., '/', '-', ':')
		match_pos = match_pos + math.max(0, literal_len)

		if cursor_offset >= match_pos and cursor_offset < match_pos + comp_len then
			local kind_map = {
				Y = "year",
				y = "year",
				m = "month",
				d = "day",
				H = "hour",
				I = "hour",
				M = "min",
				S = "sec",
			}
			return kind_map[comp.type] or default_kind
		end
		match_pos = match_pos + comp_len
	end

	-- Cursor is not on any component (e.g., on a separator), return default_kind
	return default_kind
end

-- Create date rule
---@param opts? { pattern?: string, default_kind?: string, only_valid?: boolean, word?: boolean, priority?: number, id?: string }
---@return mobius.Rule
function M.new(opts)
	opts = opts or {}
	local pattern = opts.pattern or "%Y/%m/%d"
	local default_kind = opts.default_kind or "day"
	local only_valid = opts.only_valid ~= false -- default true
	local word = opts.word or false
	local priority = opts.priority or 55 -- Date rules at mid priority
	local id = opts.id or ("date_" .. pattern:gsub("%W", "_"))

	local regex_pattern = build_regex_pattern(pattern)
	local components = parse_date_pattern(pattern)

	return {
		id = id,
		priority = priority,
		cyclic = false,

		---@return mobius.RuleMatch?
		find = function(cursor)
			local ok, result = pcall(function()
				local row, col = cursor.row, cursor.col
				local buf = vim.api.nvim_get_current_buf()
				local lines = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)
				local line = lines[1] or ""

				-- Build word boundary pattern if needed
				local search_pattern = regex_pattern
				if word then
					search_pattern = "%f[%w]" .. regex_pattern .. "%f[^%w]"
				end

				-- Find all matches
				local matches = {}
				local start_pos, end_pos = line:find(search_pattern)
				while start_pos do
					table.insert(matches, { start_pos, end_pos })
					start_pos, end_pos = line:find(search_pattern, end_pos + 1)
				end

				-- Find best match based on cursor position
				local best_match = nil
				local best_score = -math.huge

				for _, match in ipairs(matches) do
					local start_pos, end_pos = match[1], match[2]
					local match_len = end_pos - start_pos + 1
					local match_text = line:sub(start_pos, end_pos)

					-- Parse the match
					local captures = { match_text:match(regex_pattern) }
					if #captures == 0 then
						goto continue
					end

					-- Validate date if only_valid is true
					if only_valid then
						-- Map captures to year, month, day based on pattern order
						local captures_map = {}
						for i, comp in ipairs(components) do
							captures_map[comp.type] = tonumber(captures[i]) or 0
						end

						local y = captures_map.Y or captures_map.y or 0
						local m = captures_map.m or 0
						local d = captures_map.d or 0

						if y > 0 and m > 0 and d > 0 then
							-- Adjust 2-digit year if needed
							if y < 100 then
								y = 2000 + y
							end
							if m < 1 or m > 12 or d < 1 or d > days_in_month(y, m) then
								goto continue
							end
						end
					end

					local score = 0
					if start_pos <= col + 1 and end_pos >= col + 1 then
						score = constants.SCORE_CONTAINS_CURSOR + match_len
					elseif start_pos > col + 1 then
						score = constants.SCORE_AFTER_CURSOR_BASE - (start_pos - col)
					else
						score = constants.SCORE_BEFORE_CURSOR_BASE - (col - end_pos)
					end

					score = score + match_len * constants.SCORE_LENGTH_MULTIPLIER

					if score > best_score then
						best_score = score
						local cursor_offset = (col + 1) - start_pos
						local component = determine_component(pattern, match_text, cursor_offset, default_kind)
						best_match = {
							col = start_pos - 1,
							end_col = end_pos - 1,
							metadata = {
								text = match_text,
								pattern = pattern,
								component = component,
								captures = captures,
							},
						}
					end

					::continue::
				end

				return best_match
			end)

			if not ok then
				vim.notify("[mobius:date] " .. tostring(result), vim.log.levels.ERROR)
				return nil
			end
			return result
		end,

		---@param addend number
		---@param metadata? mobius.RuleMetadata
		---@return string?
		add = function(addend, metadata)
			if not metadata then
				return nil
			end
			local text = metadata.text
			local pattern = metadata.pattern
			local component = metadata.component
			local captures = metadata.captures

			-- Parse current date/time
			local year, month, day, hour, min, sec
			local idx = 1
			local components = parse_date_pattern(pattern)

			for _, comp in ipairs(components) do
				local val = tonumber(captures[idx])
				if comp.type == "Y" or comp.type == "y" then
					year = val
					if comp.type == "y" and year < 100 then
						year = 2000 + year
					end
				elseif comp.type == "m" then
					month = val
				elseif comp.type == "d" then
					day = val
				elseif comp.type == "H" or comp.type == "I" then
					hour = val
				elseif comp.type == "M" then
					min = val
				elseif comp.type == "S" then
					sec = val
				end
				idx = idx + 1
			end

			-- Default values
			year = year or os.date("*t").year
			month = month or os.date("*t").month
			day = day or os.date("*t").day
			hour = hour or 0
			min = min or 0
			sec = sec or 0

			-- Apply increment based on component
			if component == "year" then
				year = year + addend
			elseif component == "month" then
				month = month + addend
				-- Handle month overflow
				while month > 12 do
					month = month - 12
					year = year + 1
				end
				while month < 1 do
					month = month + 12
					year = year - 1
				end
			elseif component == "day" then
				day = day + addend
				-- Handle day overflow
				while day > days_in_month(year, month) do
					day = day - days_in_month(year, month)
					month = month + 1
					if month > 12 then
						month = 1
						year = year + 1
					end
				end
				while day < 1 do
					month = month - 1
					if month < 1 then
						month = 12
						year = year - 1
					end
					day = day + days_in_month(year, month)
				end
			elseif component == "hour" then
				hour = hour + addend
				while hour >= 24 do
					hour = hour - 24
					day = day + 1
				end
				while hour < 0 do
					hour = hour + 24
					day = day - 1
				end
			elseif component == "min" then
				min = min + addend
				while min >= 60 do
					min = min - 60
					hour = hour + 1
				end
				while min < 0 do
					min = min + 60
					hour = hour - 1
				end
			elseif component == "sec" then
				sec = sec + addend
				while sec >= 60 do
					sec = sec - 60
					min = min + 1
				end
				while sec < 0 do
					sec = sec + 60
					min = min - 1
				end
			end

			-- Format back according to pattern
			local result = pattern
			result = result:gsub("%%Y", string.format("%04d", year))
			result = result:gsub("%%y", string.format("%02d", year % 100))
			result = result:gsub("%%-y", tostring(year % 100))
			result = result:gsub("%%m", string.format("%02d", month))
			result = result:gsub("%%-m", tostring(month))
			result = result:gsub("%%d", string.format("%02d", day))
			result = result:gsub("%%-d", tostring(day))
			result = result:gsub("%%H", string.format("%02d", hour))
			result = result:gsub("%%-H", tostring(hour))
			result = result:gsub("%%I", string.format("%02d", hour % 12 == 0 and 12 or hour % 12))
			result = result:gsub("%%-I", tostring(hour % 12 == 0 and 12 or hour % 12))
			result = result:gsub("%%M", string.format("%02d", min))
			result = result:gsub("%%-M", tostring(min))
			result = result:gsub("%%S", string.format("%02d", sec))
			result = result:gsub("%%-S", tostring(sec))
			result = result:gsub("%%%%", "%")

			-- Calculate cursor position: keep cursor at the start of modified component
			local cursor_offset = nil
			local components = parse_date_pattern(pattern)
			local pattern_pos = 0
			local result_pos = 0

			for _, comp in ipairs(components) do
				local pat_len = comp.padding and 2 or 3 -- %Y vs %-Y
				local literal_len = comp.pos and (comp.pos - pattern_pos - pat_len) or 0
				literal_len = math.max(0, literal_len) -- first component has no literal before it
				result_pos = result_pos + literal_len

				local comp_len = (comp.type == "Y" and 4) or (comp.padding and 2 or 1)

				local kind_map = {
					Y = "year",
					y = "year",
					m = "month",
					d = "day",
					H = "hour",
					I = "hour",
					M = "min",
					S = "sec",
				}
				if kind_map[comp.type] == component then
					cursor_offset = result_pos
					break
				end

				result_pos = result_pos + comp_len
				pattern_pos = comp.pos
			end

			return result
		end,
	}
end

-- Support direct call: require("mobius.rules.date")("%Y/%m/%d") or require("mobius.rules.date")(opts)
setmetatable(M, {
	__call = function(self, opts)
		if type(opts) == "string" then
			return self.new({ pattern = opts })
		end
		return self.new(opts)
	end,
})

return M
