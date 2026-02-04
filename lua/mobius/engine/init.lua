local constants = require("mobius.engine.constants")
local match_scorer = require("mobius.engine.match_scorer")
local rule_result = require("mobius.engine.rule_result")

local M = {}

-- Cache for loaded rules. Key: buf_id .. "|" .. rule_spec
-- This ensures buffer-local rules are properly isolated
local rule_cache = {}

-- Store last action for cumulative mode (g<C-a>)
-- Note: Normal mode uses native . repeat via g@ operator
-- This state is ONLY needed for cumulative mode
local last_action = {
	step = 1,
	direction = "increment",
	rule = nil, ---@type mobius.Rule?
	cumsum = 0,
	cumulative = false,
}

-- Load a rule (supports lazy-loading with string references and function factories)
-- With cache invalidation support for buffer-local rules
---@param rule_spec mobius.RuleSpec
---@param buf? number
---@return mobius.Rule?
local function load_rule(rule_spec, buf)
	buf = buf or vim.api.nvim_get_current_buf()
	local cache_key = buf .. "|" .. (type(rule_spec) == "string" and rule_spec or "inline")

	if rule_cache[cache_key] then
		return rule_cache[cache_key]
	end

	local rule = nil

	if type(rule_spec) == "string" then
		-- Lazy-load from module path; valid rule must have .find (factories for user config are skipped)
		local ok, loaded_rule = pcall(require, rule_spec)
		if ok and type(loaded_rule) == "table" and loaded_rule.find then
			rule = loaded_rule
			rule_cache[cache_key] = rule
		elseif not ok then
			vim.notify("[mobius] Failed to load rule: " .. rule_spec, vim.log.levels.WARN)
		end
		-- No .find: skip (e.g. factory module for user: require("mobius.rules.hexcolor")())
	elseif type(rule_spec) == "function" then
		-- Function returns rule table (lazy-load via function call)
		local ok, result = pcall(rule_spec)
		if ok and type(result) == "table" then
			rule = result
		else
			vim.notify("[mobius] Function must return a rule table", vim.log.levels.WARN)
		end
	elseif type(rule_spec) == "table" then
		-- Direct rule definition (do not cache inline rules)
		rule = rule_spec
	end

	return rule
end

-- Clear cache for a specific buffer (useful for buffer switching, hot reload)
---@param buf? number
function M.clear_cache(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	for key in pairs(rule_cache) do
		if key:match("^" .. buf .. "|") then
			rule_cache[key] = nil
		end
	end
end

-- Get all rules (global + buffer-local), or restrict to opts.rules when provided. Prioritized.
-- Note: all require() calls here load rules from mobius.rules.* namespace
---@param opts? {rules?: mobius.RuleSpec[]}
---@return mobius.Rule[]
local function get_rules(opts)
	local rules = {} ---@type mobius.Rule[]

	if opts and opts.rules and #opts.rules > 0 then
		-- Restrict to given rule set only
		for _, rule_spec in ipairs(opts.rules) do
			local rule = load_rule(rule_spec)
			if rule then
				table.insert(rules, rule)
			end
		end
	else
		-- Default: buffer-local + global. b:mobius_rules only: first element true = inherit (global base + b[2..]).
		local buf = vim.api.nvim_get_current_buf()
		local buf_rules = vim.b[buf].mobius_rules
		local global_rules = vim.g.mobius_rules
		local inherit = buf_rules and #buf_rules > 0 and type(buf_rules[1]) == "boolean" and buf_rules[1] == true

		if inherit then
			-- b[1] = true: effective = global .. b[2..]
			if global_rules then
				for _, rule_spec in ipairs(global_rules) do
					local rule = load_rule(rule_spec)
					if rule then
						table.insert(rules, rule)
					end
				end
			end
			for i = 2, #buf_rules do
				local rule_spec = buf_rules[i]
				local rule = load_rule(rule_spec)
				if rule then
					table.insert(rules, rule)
				end
			end
		else
			-- No inherit: buffer first, then global
			if buf_rules then
				for _, rule_spec in ipairs(buf_rules) do
					local rule = load_rule(rule_spec)
					if rule then
						table.insert(rules, rule)
					end
				end
			end
			if global_rules then
				for _, rule_spec in ipairs(global_rules) do
					local rule = load_rule(rule_spec)
					if rule then
						table.insert(rules, rule)
					end
				end
			end
		end
	end

	table.sort(rules, function(a, b)
		local priority_a = a.priority or constants.DEFAULT_PRIORITY
		local priority_b = b.priority or constants.DEFAULT_PRIORITY
		return priority_a > priority_b
	end)

	return rules
end

-- Apply text to buffer at the specified match position
-- Replaces the text between match.col and match.end_col with new_text
---@param row number
---@param match mobius.RuleMatch
---@param new_text string
local function apply_text_to_buffer(row, match, new_text)
	local buf = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)
	local line = lines[1] or ""

	local prefix = line:sub(1, match.col)
	local suffix = line:sub(match.end_col + 2)

	local new_line = prefix .. new_text .. suffix
	vim.api.nvim_buf_set_lines(buf, row, row + 1, false, { new_line })
	return new_line
end

-- Find the best match at the given position
---@param cursor {row: number, col: number} 0-indexed
---@param opts? {rules?: mobius.RuleSpec[], use_rule?: mobius.Rule}
---@return {rule: mobius.Rule, match: mobius.RuleMatch}?
local function find_match(cursor, opts)
	local row, col = cursor.row, cursor.col
	local rules
	if opts and opts.use_rule then
		rules = { opts.use_rule }
	else
		rules = get_rules(opts or {})
	end
	local best_match = nil ---@type {rule: mobius.Rule, match: mobius.RuleMatch}?
	local best_score = -math.huge

	-- Filter rules by enable() if present (pre-filter before expensive find())
	local enabled_rules = {}
	for _, rule in ipairs(rules) do
		if rule.find and (not rule.enable or rule.enable(cursor)) then
			table.insert(enabled_rules, rule)
		end
	end

	for _, rule in ipairs(enabled_rules) do
		local match = rule.find(cursor)
		if match then
			-- Only apply when cursor is inside match
			if col < match.col or col > match.end_col then
				match = nil
			end
			if match then
				local score = match_scorer.score_for_rule_match(match, col, rule.priority)
				local priority = rule.priority or constants.DEFAULT_PRIORITY
				local best_priority = best_match and (best_match.rule.priority or constants.DEFAULT_PRIORITY) or -1
				-- Prefer higher-priority rule; when equal, prefer higher score
				if priority > best_priority or (priority == best_priority and score > best_score) then
					best_score = score
					best_match = {
						rule = rule,
						match = match,
					}
				end
			end
		end
	end

	return best_match
end

-- Apply a transformation at the given position
---@param cursor {row: number, col: number} 0-indexed
---@param addend number
---@param opts? {rules?: mobius.RuleSpec[], use_rule?: mobius.Rule}
---@return boolean ok
---@return string? new_text_or_error
---@return mobius.Rule? matched_rule (for storing in last_action)
local function apply_transform(cursor, addend, opts)
	local row, col = cursor.row, cursor.col
	local matched = find_match(cursor, opts)

	if not matched then
		return false, "No match found", nil
	end

	local rule = matched.rule ---@type mobius.Rule
	local match = matched.match ---@type mobius.RuleMatch

	-- Validate match structure
	local valid, err = rule_result.validate(match)
	if not valid then
		return false, "Invalid match: " .. err, nil
	end

	-- Extract and validate metadata
	local metadata = match.metadata ---@type mobius.RuleMetadata
	if not metadata or not metadata.text then
		return false, "Rule find() must return { col, end_col, metadata: { text } }", nil
	end

	-- Call the add function (addend first, metadata second)
	-- add() may return string or { text = string, cursor = number } (col offset from match.col)
	local result = rule.add(addend, metadata)

	if not result then
		local error_reason
		if rule.cyclic == true then
			error_reason = "Cyclic rule boundary reached"
		else
			error_reason = "Cannot transform at boundary"
		end
		return false, error_reason, nil
	end

	if type(result) ~= "string" and type(result) ~= "table" then
		return false, "Rule add() must return a string or { text, cursor? }, got " .. type(result), nil
	end
	local new_text = type(result) == "string" and result or result.text
	local cursor_offset = type(result) == "table" and result.cursor

	if not new_text or type(new_text) ~= "string" then
		return false, "Rule add() must return a string or { text, cursor? }, got " .. type(result), nil
	end

	-- Update the buffer
	apply_text_to_buffer(row, match, new_text)

	-- Oracle: Cursor should stay on the modified element
	-- Calculation:
	--   1. Find where cursor was relative to match start (offset_in_match)
	--   2. Apply rule-provided cursor_offset if present
	--   3. Otherwise, keep relative position but clamp to new text length
	local offset_in_match = col - match.col
	local new_col = match.col

	if type(cursor_offset) == "number" then
		-- Rule explicitly specifies where cursor should be (relative to match.col)
		new_col = math.max(0, match.col + cursor_offset)
	else
		-- Default: keep same relative offset within the new text
		-- Clamp to [0, len-1] to stay within bounds
		new_col = match.col + math.min(offset_in_match, math.max(0, #new_text - 1))
	end

	vim.api.nvim_win_set_cursor(0, { row + 1, new_col })

	return true, new_text, rule
end

-- Main execution interface
---@param direction "increment"|"decrement"
---@param opts? {visual?: boolean, seqadd?: boolean, step?: number, rules?: mobius.RuleSpec[]}
---@return nil
function M.execute(direction, opts)
	opts = opts or {}
	local visual = opts.visual or false
	local seqadd = opts.seqadd or false
	local step = opts.step or 1

	-- Determine addend from direction (cumulative: repeat_last passes increased step each time)
	local addend = step
	if direction == "decrement" then
		addend = -step
	end

	-- Handle visual mode
	if visual then
		-- Get visual selection
		local start_pos = vim.api.nvim_buf_get_mark(0, "<")
		local end_pos = vim.api.nvim_buf_get_mark(0, ">")

		local start_row = start_pos[1] - 1
		local end_row = end_pos[1] - 1
		
		-- Determine if this is block selection (same col range for all rows)
		-- or char selection (different col ranges per row)
		-- Heuristic: if start_col == end_col, it's block mode; otherwise char mode
		local is_block_selection = start_pos[2] == end_pos[2]

		-- Collect all matches in the selection
		local matches = {}

		for row = start_row, end_row do
			local col_start = 0
			local col_end = nil
			
			if is_block_selection then
				-- Block selection: same column for all rows
				col_start = start_pos[2]
				col_end = start_pos[2]
			else
				-- Char selection: different columns per row
				if row == start_row then
					col_start = start_pos[2]
					-- For single row or start row, don't limit end
					if row ~= end_row then
						col_end = nil  -- to end of line
					else
						col_end = end_pos[2]  -- single row: use end_pos[2]
					end
				elseif row == end_row then
					col_start = 0
					col_end = end_pos[2]
				else
					-- Middle rows
					col_start = 0
					col_end = nil  -- to end of line
				end
			end

			-- Find all matches in this row by checking each position
			-- We need to find all non-overlapping matches from left to right
			local buf = vim.api.nvim_get_current_buf()
			local lines = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)
			local line = lines[1] or ""

			-- Try finding matches at each position, collecting unique ones
			local seen_matches = {}
			local max_try_col = col_end ~= nil and math.min(col_end, #line - 1) or (#line - 1)
			
			for try_col = col_start, max_try_col do
				local matched = find_match({ row = row, col = try_col }, opts)
				if matched then
					local key = matched.match.col .. ":" .. matched.match.end_col
					if not seen_matches[key] then
						seen_matches[key] = true
						local item = { row = row, match = matched.match, rule = matched.rule }
						---@cast item {row: number, match: mobius.RuleMatch, rule: mobius.Rule}
						table.insert(matches, item)
					end
				end
			end
		end

		-- Sort matches by position (left to right) for proper seqadd ordering
		table.sort(matches, function(a, b)
			if a.row == b.row then
				return a.match.col < b.match.col
			end
			return a.row < b.row
		end)

		if #matches == 0 then
			vim.notify("[mobius] No matches found in selection", vim.log.levels.WARN)
			return
		end

		-- Apply transformations
		-- Important: process from bottom to top to avoid position shifting
		for i = #matches, 1, -1 do
			local item = matches[i]
			local current_addend = addend

			-- Sequential add: each match gets a different addend
			if seqadd then
				current_addend = addend * i
			end

			local match = item.match
			local rule = item.rule
			local metadata = match.metadata

			if not metadata or not metadata.text then
				vim.notify("[mobius] Rule find() must return { col, end_col, metadata: { text } }", vim.log.levels.WARN)
			else
				local result = rule.add(current_addend, metadata)
				local new_text = type(result) == "string" and result or (type(result) == "table" and result.text)
				if new_text then
					apply_text_to_buffer(item.row, match, new_text)
				end
			end
		end

		-- Set cursor to first match
		if #matches > 0 then
			local first_match = matches[1].match
			vim.api.nvim_win_set_cursor(0, { matches[1].row + 1, first_match.col })
		end

		-- Note: visual mode operations don't support . repeat in Vim
		-- This is expected behavior

		return
	end

	-- Handle normal mode
	local cursor_pos = vim.api.nvim_win_get_cursor(0)
	local cursor = { row = cursor_pos[1] - 1, col = cursor_pos[2] }

	-- use_rule is only set by repeat_last() for dot repeat
	local ok, result, matched_rule = apply_transform(cursor, addend, opts)

	if not ok then
		-- vim.notify("[mobius] " .. result, vim.log.levels.DEBUG)
		return
	end

	-- Store action for cumulative mode only
	-- For non-cumulative mode, native . repeat works via g@ operator
	if opts.cumulative then
		last_action.direction = direction
		last_action.rule = matched_rule
		last_action.cumulative = true
		last_action.cumsum = step
	else
		last_action.cumulative = false
	end
end

-- Function to repeat last action (for cumulative mode only)
-- For normal mode, native . repeat works via g@ operator
-- This is ONLY used for cumulative mode (g<C-a> / g<C-x>)
---@return nil
function M.repeat_last()
	if not last_action.direction or not last_action.cumulative then
		return
	end

	-- Cumulative mode (g<C-a>): each repeat adds one more (cumsum 1, 2, 3, ...)
	local count = vim.v.count1
	if count > 0 then
		last_action.cumsum = last_action.cumsum + count
	end

	M.execute(last_action.direction, {
		visual = false,
		seqadd = false,
		step = last_action.cumsum,
		cumulative = true,
		use_rule = last_action.rule,
	})
end

---@cast M mobius.Engine
return M
