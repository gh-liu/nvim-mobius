-- LSP enum rule: cycle through enum members from LSP completion at the current position.
-- At cursor position, requests LSP completion, filters by symbol kinds (default: EnumMember, Key, Constant),
-- finds the longest matching enum element in the current line, and allows cycling through.
-- Constant is included so gopls (and similar) const/iota completions are accepted.
-- Only active when vim.lsp.get_clients({ bufnr }) has at least one client (LSP attached).
--
-- Example usage (add to b:mobius_rules or g:mobius_rules):
--   "mobius.rules.lsp_enum"  -- lazy load, use defaults (enabled only when LSP attached)
--   require("mobius.rules.lsp_enum")({ symbol_kinds = {...}, cyclic = true, timeout_ms = 200 })

local rule_result = require("mobius.engine.rule_result")

-- Default symbol kinds (CompletionItemKind) to include in enum candidates.
-- EnumMember, Key; Constant for gopls/Go const and similar LSPs.
-- Values from vim.lsp.protocol.CompletionItemKind when available.
local function get_default_symbol_kinds()
	if vim.lsp.protocol and vim.lsp.protocol.CompletionItemKind then
		local K = vim.lsp.protocol.CompletionItemKind
		local result = {}
		-- Collect kinds, filtering out nil values (e.g., Key may not exist on some Neovim versions)
		if K.EnumMember then
			table.insert(result, K.EnumMember)
		end
		if K.Key then
			table.insert(result, K.Key)
		end
		if K.Constant then
			table.insert(result, K.Constant)
		end
		return result
	else
		-- Fallback: EnumMember=13, Key=16, Constant=21 (LSP CompletionItemKind values)
		return { 13, 16, 21 }
	end
end

-- Parse LSP completion result and extract items.
-- LSP allows CompletionList (result.items) or CompletionItem[] (result is array).
-- Returns first non-empty items from results, or empty list if none found.
---@param results table LSP response results (client_id -> response)
---@return table items List of CompletionItem objects
local function extract_completion_items(results)
	if not results or type(results) ~= "table" then
		return {}
	end

	for _, response in pairs(results) do
		if not response or not response.result then
			goto continue
		end
		local result = response.result
		if type(result) ~= "table" then
			goto continue
		end
		if result.items and #result.items > 0 then
			return result.items
		end
		-- result may be CompletionItem[] (array, no .items)
		if not result.items and #result > 0 then
			return result
		end
		::continue::
	end

	return {}
end

-- Filter completion items by symbol kinds and extract labels.
---@param items table List of CompletionItem
---@param symbol_kinds number[] List of kind numbers to include
---@param exclude_labels? table Set of labels to exclude (e.g., {"false", "true"})
---@return string[] List of item labels (candidates)
local function filter_items_by_kind(items, symbol_kinds, exclude_labels)
	local kind_set = {}
	for _, k in ipairs(symbol_kinds) do
		kind_set[k] = true
	end

	local exclude_set = {}
	if exclude_labels then
		for _, label in ipairs(exclude_labels) do
			exclude_set[label] = true
		end
	end

	local candidates = {}
	for _, item in ipairs(items) do
		if item.label and kind_set[item.kind] and not exclude_set[item.label] then
			table.insert(candidates, item.label)
		end
	end

	return candidates
end

-- Find all occurrences of a pattern in a line using plain string search.
-- Returns list of {start, end} (1-indexed, inclusive).
---@param line string The line to search in
---@param pattern string The substring to find (literal)
---@return table[] List of {start, end} positions
local function find_all_occurrences(line, pattern)
	local matches = {}
	local start = 1

	while true do
		local pos = line:find(pattern, start, true) -- true = plain string match
		if not pos then
			break
		end

		local match_start = pos
		local match_end = pos + #pattern - 1
		table.insert(matches, { match_start, match_end })
		start = pos + 1
	end

	return matches
end

-- Find the best (longest, then earliest) candidate that contains the cursor position.
-- col is 0-indexed; candidates are 1-indexed in the line.
---@param line string The current line
---@param col number Cursor column (0-indexed)
---@param candidates string[] List of candidate labels
---@return {start: number, end: number, text: string}? Best match or nil
local function find_best_candidate_match(line, col, candidates)
	local col_1indexed = col + 1 -- Convert to 1-indexed

	local best_match = nil
	local best_length = 0

	for _, candidate in ipairs(candidates) do
		local matches = find_all_occurrences(line, candidate)
		for _, match in ipairs(matches) do
			local match_start, match_end = match[1], match[2]
			-- Check if cursor position is within this match (inclusive)
			if match_start <= col_1indexed and col_1indexed <= match_end then
				local length = match_end - match_start + 1
				-- Prefer longer matches; if equal, prefer earlier start
				if
					length > best_length
					or (length == best_length and (not best_match or match_start < best_match.start))
				then
					best_length = length
					best_match = {
						start = match_start,
						_end = match_end, -- Store as _end to avoid conflict with Lua keyword
						text = line:sub(match_start, match_end),
					}
				end
			end
		end
	end

	return best_match
end

-- Create the LSP enum rule.
-- Options:
--   symbol_kinds (number[]): Completion item kinds to include (default: EnumMember, Key, Constant)
--   exclude_labels (string[]): Labels to exclude from candidates (e.g., {"false", "true"})
--   cyclic (boolean): Wrap around at boundaries (default: true)
--   priority (number): Rule priority (default: 60)
--   id (string): Rule ID (default: "lsp_enum")
--   timeout_ms (number): LSP request timeout in ms (default: 150)
---@param opts table? Configuration options
---@return mobius.Rule
local function create_lsp_enum_rule(opts)
	opts = opts or {}

	local symbol_kinds = opts.symbol_kinds or get_default_symbol_kinds()
	local exclude_labels = opts.exclude_labels or { "false", "true" }
	local cyclic = opts.cyclic ~= false -- default true
	local priority = opts.priority or 68  -- lsp_enum: highest priority (requires LSP context)
	local id = opts.id or "lsp_enum"
	local timeout_ms = opts.timeout_ms or 150

	-- Pre-check: only proceed if cursor is on a keyword character
	-- This avoids expensive LSP requests for whitespace, punctuation, etc.
	---@param cursor mobius.Cursor 0-indexed { row, col }
	---@return boolean
	local function enable(cursor)
		local row, col = cursor.row, cursor.col
		local lines = vim.api.nvim_buf_get_lines(0, row, row + 1, false)
		local line = lines[1] or ""
		local char = line:sub(col + 1, col + 1) -- col is 0-indexed

		if char == "" then
			return false
		end

		-- Use Vim's \k pattern (corresponds to 'iskeyword')
		local result = vim.fn.matchstrpos(char, "\\k")
		return result[2] >= 0
	end

	---@param cursor mobius.Cursor 0-indexed { row, col }
	---@return mobius.RuleMatch?
	local function find(cursor)
		local row, col = cursor.row, cursor.col
		local buf = vim.api.nvim_get_current_buf()
		local clients = vim.lsp.get_clients({ bufnr = buf })
		if not clients or #clients == 0 then
			return nil
		end

		local lines = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)
		local line = lines[1] or ""

		-- Build LSP params with exact (row, col) from find() so we don't rely on current cursor
		local params = {
			textDocument = { uri = vim.uri_from_bufnr(buf) },
			position = { line = row, character = col },
		}

		-- Call LSP completion synchronously
		local results = vim.lsp.buf_request_sync(buf, "textDocument/completion", params, timeout_ms)
		if not results or vim.tbl_isempty(results) then
			return nil
		end

		-- Extract and filter completion items
		local items = extract_completion_items(results)
		if #items == 0 then
			return nil
		end

		local candidates = filter_items_by_kind(items, symbol_kinds, exclude_labels)
		if #candidates == 0 then
			return nil
		end

		-- Sort candidates for stable ordering (LSP may return different orders)
		table.sort(candidates, function(a, b)
			return a < b
		end)

		-- Find best matching candidate at cursor position
		local best = find_best_candidate_match(line, col, candidates)
		if not best then
			return nil
		end

		-- Return match using rule_result.match factory
		-- available_values used by add() to cycle through candidates
		return rule_result.match(best.start, best._end, best.text, { available_values = candidates })
	end

	---@param addend number
	---@param metadata? mobius.RuleMetadata
	---@return string?
	local function add(addend, metadata)
		if not metadata then
			return nil
		end
		local candidates = metadata.available_values
		if not candidates or #candidates == 0 then
			return nil
		end

		-- Find current text in candidates
		local current_idx = nil
		for i, candidate in ipairs(candidates) do
			if candidate == metadata.text then
				current_idx = i
				break
			end
		end

		if not current_idx then
			return nil
		end

		-- Calculate next index
		local n = #candidates
		local next_idx

		if cyclic then
			-- Cyclic: wrap around at boundaries
			next_idx = ((current_idx - 1 + addend) % n + n) % n + 1
		else
			-- Non-cyclic: return nil at boundaries (no change)
			next_idx = current_idx + addend
			if next_idx < 1 or next_idx > n then
				return nil
			end
		end

		return candidates[next_idx]
	end

	return {
		id = id,
		priority = priority,
		cyclic = cyclic,
		enable = enable,
		find = find,
		add = add,
	}
end

-- Return default rule table so string "mobius.rules.lsp_enum" works (lazy-load, use defaults).
-- With opts: require("mobius.rules.lsp_enum")({ symbol_kinds = {...}, ... })
local M = create_lsp_enum_rule(nil)
return setmetatable(M, {
	__call = function(_, opts)
		return create_lsp_enum_rule(opts)
	end,
})
