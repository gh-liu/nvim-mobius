local M = {}

-- Detect case type
local function detect_case(text)
	if text:match("^[a-z]+$") then
		-- All lowercase, single word - cannot determine
		return nil
	elseif text:match("^[A-Z][a-z]+$") then
		-- PascalCase (single word)
		return nil
	elseif text:match("^[A-Z_]+$") then
		-- SCREAMING_SNAKE_CASE
		return "SCREAMING_SNAKE_CASE"
	elseif text:match("^[a-z_]+$") then
		-- snake_case
		return "snake_case"
	elseif text:match("^[a-z%-]+$") then
		-- kebab-case
		return "kebab-case"
	elseif text:match("^[a-z][a-zA-Z0-9]*$") and text:match("[A-Z]") then
		-- camelCase
		return "camelCase"
	elseif text:match("^[A-Z][a-zA-Z0-9]*$") and text:match("[A-Z][a-z]") then
		-- PascalCase
		return "PascalCase"
	end
	return nil
end

-- Convert text to different case styles
local function to_case(text, target_case)
	-- Split into words
	local words = {}

	-- Handle different input formats
	if text:match("_") then
		-- snake_case or SCREAMING_SNAKE_CASE
		for word in text:gmatch("[^_]+") do
			table.insert(words, word:lower())
		end
	elseif text:match("-") then
		-- kebab-case
		for word in text:gmatch("[^-]+") do
			table.insert(words, word:lower())
		end
	else
		-- camelCase or PascalCase
		local current_word = ""
		for char in text:gmatch(".") do
			if char:match("%u") and current_word ~= "" then
				table.insert(words, current_word:lower())
				current_word = char
			else
				current_word = current_word .. char
			end
		end
		if current_word ~= "" then
			table.insert(words, current_word:lower())
		end
	end

	if #words == 0 then
		return nil
	end

	-- Convert to target case
	if target_case == "camelCase" then
		local result = words[1]
		for i = 2, #words do
			result = result .. words[i]:sub(1, 1):upper() .. words[i]:sub(2)
		end
		return result
	elseif target_case == "PascalCase" then
		local result = ""
		for _, word in ipairs(words) do
			result = result .. word:sub(1, 1):upper() .. word:sub(2)
		end
		return result
	elseif target_case == "snake_case" then
		return table.concat(words, "_")
	elseif target_case == "SCREAMING_SNAKE_CASE" then
		local upper_words = {}
		for _, word in ipairs(words) do
			table.insert(upper_words, word:upper())
		end
		return table.concat(upper_words, "_")
	elseif target_case == "kebab-case" then
		return table.concat(words, "-")
	end

	return nil
end

-- Create case rule
---@param opts? { types?: string[], cyclic?: boolean, word?: boolean, priority?: number, id?: string }
---@return mobius.Rule
function M.new(opts)
	opts = opts or {}
	local types = opts.types or { "camelCase", "snake_case", "PascalCase" }
	local cyclic = opts.cyclic ~= nil and opts.cyclic or true
	local word = opts.word ~= nil and opts.word or true
	local priority = opts.priority or 65 -- case: high priority for identifier conversion
	local id = opts.id or "case"

	local match_scorer = require("mobius.engine.match_scorer")
	local word_boundary = require("mobius.engine.word_boundary")

	return {
		id = id,
		priority = priority,
		cyclic = cyclic,

		---@return mobius.RuleMatch?
		find = function(cursor)
			local row, col = cursor.row, cursor.col
			local buf = vim.api.nvim_get_current_buf()
			local lines = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)
			local line = lines[1] or ""

			-- Find identifiers (words with case variations)
			local pattern = "[a-zA-Z][a-zA-Z0-9_%-]*"
			local raw_matches = match_scorer.find_all_matches(line, pattern)

			-- Filter matches by word boundary and case type detection
			local matches = {}
			for _, match in ipairs(raw_matches) do
				local start_pos, end_pos = match[1], match[2]
				local match_text = line:sub(start_pos, end_pos)

				-- Check word boundary if needed
				if word then
					local before_ok = start_pos == 1 or not line:sub(start_pos - 1, start_pos - 1):match("%w")
					local after_ok = end_pos == #line or not line:sub(end_pos + 1, end_pos + 1):match("%w")
					if not (before_ok and after_ok) then
						goto continue
					end
				end

				-- Detect case type
				local case_type = detect_case(match_text)
				if case_type then
					-- Check if this case type is in our types list
					local found = false
					for _, t in ipairs(types) do
						if t == case_type then
							found = true
							break
						end
					end
					if found then
						table.insert(matches, { start_pos, end_pos, match_text, case_type })
					end
				end

				::continue::
			end

			-- Find best match using unified scorer
			local best = match_scorer.find_best_match(line, matches, col, function(text, match)
				return {
					text = match[3],
					case_type = match[4],
					types = types,
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
			local text = metadata.text
			local current_case = metadata.case_type
			local types = metadata.types

			-- Find current index in types list
			local current_idx = nil
			for i, case_type in ipairs(types) do
				if case_type == current_case then
					current_idx = i
					break
				end
			end

			if not current_idx then
				return nil
			end

			-- Calculate next index
			local next_idx
			if cyclic then
				next_idx = ((current_idx - 1 + addend) % #types) + 1
			else
				next_idx = current_idx + addend
				if next_idx < 1 or next_idx > #types then
					return nil -- Boundary reached
				end
			end

			local target_case = types[next_idx]
			return to_case(text, target_case)
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
