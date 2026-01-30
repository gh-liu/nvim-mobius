-- Constant (toggle) rule: cycle through a fixed list of strings or groups.
-- Dial-style sugar so users can define rules without writing pattern/add by hand.
--
-- Example (flat list):
--   require("mobius.rules.constant").new({ elements = { "&&", "||" }, word = false, cyclic = true })
--
-- Example (grouped):
--   require("mobius.rules.constant").new({
--     elements = { { "true", "false" }, { "True", "False" } },
--     word = true,
--     cyclic = true
--   })
--   -- Switches within the matched group: true<->false, True<->False

local match_scorer = require("mobius.engine.match_scorer")
local word_boundary = require("mobius.engine.word_boundary")

--- Escape string for use inside a Lua pattern (literal match).
---@param s string
---@return string
local function escape_lua_pattern(s)
	return (
		s:gsub("%%", "%%%%")
			:gsub("^%^", "%%^")
			:gsub("%$", "%%$")
			:gsub("%(", "%%(")
			:gsub("%)", "%%)")
			:gsub("%.", "%%.")
			:gsub("%[", "%%[")
			:gsub("%]", "%%]")
			:gsub("%*", "%%*")
			:gsub("%+", "%%+")
			:gsub("%-", "%%-")
			:gsub("%?", "%%?")
	)
end

--- Detect if elements is grouped (nested tables) or flat (strings).
---@param elements any[]
---@return boolean is_grouped
local function is_grouped(elements)
	return type(elements[1]) == "table"
end

--- Flatten grouped elements to single list and track group membership.
---@param elements any[] Grouped or flat elements
---@return table flat_elements, table group_map (element -> group_index)
local function analyze_elements(elements)
	if not is_grouped(elements) then
		local flat = {}
		local group_map = {}
		for _, elem in ipairs(elements) do
			table.insert(flat, elem)
			group_map[elem] = 1
		end
		return flat, group_map
	end

	local flat = {}
	local group_map = {}
	for group_idx, group in ipairs(elements) do
		for _, elem in ipairs(group) do
			table.insert(flat, elem)
			group_map[elem] = group_idx
		end
	end
	return flat, group_map
end

--- Create a constant (toggle) rule from a list of elements.
--- Options:
---   elements (string[] | string[][]): flat list or grouped lists to cycle through (required)
---   word (boolean): match only on word boundary (default: true)
---   cyclic (boolean): wrap at end/start of list/group (default: true)
---   preserve_case (boolean): match elements case-insensitively when finding current index (default: false)
---   id (string): rule id (default: "constant_" .. first element)
---   priority (number): rule priority (default: 55)
---
---@param opts { elements: any[], word?: boolean, cyclic?: boolean, preserve_case?: boolean, id?: string, priority?: number }
---@return mobius.Rule
local function create_rule(opts)
	opts = opts or {}
	local elements = opts.elements
	if not elements or #elements == 0 then
		error("constant: elements (non-empty list) is required")
	end

	local word = opts.word ~= false
	local cyclic = opts.cyclic ~= false
	local preserve_case = opts.preserve_case == true
	local priority = opts.priority or 56 -- Enums/constants at mid-high priority

	local is_grouped_input = is_grouped(elements)
	local flat_elements, group_map = analyze_elements(elements)

	local id = opts.id or ("constant_" .. tostring(flat_elements[1]):gsub("%W", "_"))

	---@param cursor mobius.Cursor 0-indexed { row, col }
	---@return mobius.RuleMatch?
	local function find(cursor)
		local row, col = cursor.row, cursor.col
		local buf = vim.api.nvim_get_current_buf()
		local lines = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)
		local line = lines[1] or ""

		local matches = {}

		for _, elem in ipairs(flat_elements) do
			if word then
				for _, m in ipairs(word_boundary.find_word_matches(line, elem)) do
					table.insert(matches, { m[1], m[2], line:sub(m[1], m[2]) })
				end
			else
				local pattern = escape_lua_pattern(elem)
				for _, m in ipairs(match_scorer.find_all_matches(line, pattern)) do
					table.insert(matches, { m[1], m[2], line:sub(m[1], m[2]) })
				end
			end
		end

		local best = match_scorer.find_best_match(line, matches, col, function(text, match)
			return { text = match[3] }
		end)
		return best
	end

	---@param addend number
	---@param metadata? mobius.RuleMetadata
	---@return string?
	local function add(addend, metadata)
		metadata = metadata or {}
		local current_idx = nil
		local query = preserve_case and function(elem)
			return metadata.text:lower() == elem:lower()
		end or function(elem)
			return metadata.text == elem
		end

		for i, elem in ipairs(flat_elements) do
			if query(elem) then
				current_idx = i
				break
			end
		end

		if not current_idx then
			return nil
		end

		-- In grouped mode, only cycle within the matched group
		if is_grouped_input then
			local current_group_idx = group_map[metadata.text]
			local group = elements[current_group_idx]
			local group_size = #group
			local group_start = 1
			for i = 1, current_group_idx - 1 do
				group_start = group_start + #elements[i]
			end

			local pos_in_group = current_idx - group_start + 1
			local next_pos
			if cyclic then
				next_pos = ((pos_in_group - 1 + addend) % group_size + group_size) % group_size + 1
			else
				next_pos = pos_in_group + addend
				if next_pos < 1 then
					next_pos = 1
				end
				if next_pos > group_size then
					next_pos = group_size
				end
			end

			return group[next_pos]
		else
			-- In flat mode, cycle through entire list
			local n = #flat_elements
			local next_idx
			if cyclic then
				next_idx = ((current_idx - 1 + addend) % n + n) % n + 1
			else
				next_idx = current_idx + addend
				if next_idx < 1 then
					next_idx = 1
				end
				if next_idx > n then
					next_idx = n
				end
			end

			return flat_elements[next_idx]
		end
	end

	return {
		id = id,
		priority = priority,
		cyclic = cyclic,
		find = find,
		add = add,
	}
end

-- Return factory function, support both styles:
--   require("mobius.rules.constant")({ elements = {...} })
--   require("mobius.rules.constant")({ ... })  -- array form
return setmetatable({}, {
	__call = function(_, opts)
		if type(opts) == "table" and #opts > 0 and not opts.elements then
			-- Array form: require("mobius.rules.constant")({ "true", "false" })
			return create_rule({ elements = opts })
		end
		return create_rule(opts)
	end,
})
