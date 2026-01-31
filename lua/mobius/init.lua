---@class mobius.RuleMetadata
---@field text string Matched text (required). Other fields may be used by add().

---@class mobius.RuleMatch
---@field col number 0-indexed start column (inclusive).
---@field end_col number 0-indexed end column (inclusive).
---@field metadata mobius.RuleMetadata At least .text; extra fields for add().

---@class mobius.Cursor
---@field row number 0-indexed line
---@field col number 0-indexed column

---@class mobius.Rule
---@field id? string Optional identifier.
---@field priority? number Higher = tried first (default 50).
---@field find fun(cursor: mobius.Cursor): mobius.RuleMatch? find(cursor) -> match or nil.
---@field add fun(addend: number, metadata?: mobius.RuleMetadata): string|{text: string, cursor?: number}? add(addend, metadata) -> new_text or {text, cursor} or nil. cursor = column offset from match start (0 = start).
---@field cyclic? boolean If true, wrap at boundaries (e.g. true <-> false).

--- Built-in rule module path (category). Use for completion when writing string entries in mobius_rules.
---@alias mobius.RuleCat
---| 'mobius.rules.number'
---| 'mobius.rules.hex'
---| 'mobius.rules.hexcolor'
---| 'mobius.rules.bool'
---| 'mobius.rules.yes_no'
---| 'mobius.rules.on_off'
---| 'mobius.rules.case'
---| 'mobius.rules.semver'
---| 'mobius.rules.markdown_header'
---| 'mobius.rules.date'
---| 'mobius.rules.date.dmy'
---| 'mobius.rules.date.iso'
---| 'mobius.rules.date.md'
---| 'mobius.rules.date.mdy'
---| 'mobius.rules.date.ymd'
---| 'mobius.rules.date.time_hm'
---| 'mobius.rules.date.time_hms'

--- Single entry in g:mobius_rules or b:mobius_rules: module path (string), inline rule (table), or factory returning a rule.
--- b:mobius_rules only: first element may be boolean true to mean "inherit" (effective = g:mobius_rules .. b[2..]).
---@alias mobius.RuleSpec mobius.RuleCat|mobius.Rule|string|fun(): mobius.Rule

--- Engine module (require("mobius.engine")).
---@class mobius.Engine
---@field execute fun(direction: "increment"|"decrement", opts?: { visual?: boolean, seqadd?: boolean, step?: number, cumulative?: boolean, rules?: mobius.RuleSpec[] }): nil
---@field repeat_last fun(): nil
---@field clear_cache fun(buf?: number): nil

local M = {}

-- Global operator state (single table to avoid multiple vim.g.* variables)
_G._mobius_operator_state = {}

local last_step = 1

local function step_for_count(count)
	-- Dot-repeat replays "g@l" with no count prefix, so v:count1 is 1; reuse last step.
	if count == 1 and last_step > 1 then
		return last_step
	end
	last_step = count
	return count
end

--- Restore cursor to saved position so engine runs at the position where user pressed <C-a>.
--- g@ invokes us after motion "l", so the cursor has already moved one char right.
--- We save the cursor position before feeding g@l and restore it here.
local function restore_cursor_to_saved_position()
	local state = _G._mobius_operator_state
	if state.cursor_pos then
		vim.api.nvim_win_set_cursor(0, state.cursor_pos)
	end
end

---@param _ "line"|"char"|"block" motion type from g@ (unused; we use saved position)
function M.operator_increment(_)
	local state = _G._mobius_operator_state
	local direction = state.direction or "increment"
	local cumulative = state.cumulative or false
	local initial_count = state.count or 1
	local count = step_for_count(initial_count)

	restore_cursor_to_saved_position()

	local ok, err = pcall(require("mobius.engine").execute, direction, {
		visual = false,
		seqadd = false,
		step = count,
		cumulative = cumulative,
	})

	if not ok then
		vim.notify("[mobius] " .. tostring(err), vim.log.levels.ERROR)
	end
end

---@param vmode "line"|"char"|"block"
function M.operator_decrement(vmode)
	vim.g.mobius_operator_direction = "decrement"
	return M.operator_increment(vmode)
end

--- Returns a keymap callback: set operator state, register callback in _G, set operatorfunc, feed g@l.
---@param direction "increment"|"decrement"
---@param cumulative boolean
---@return fun()
function M.operator_trigger(direction, cumulative)
	return function()
		local cursor_pos = vim.api.nvim_win_get_cursor(0)
		_G._mobius_operator_state = {
			direction = direction,
			cumulative = cumulative,
			count = vim.v.count1,
			cursor_pos = cursor_pos, -- Save cursor position BEFORE g@l moves it
		}
		_G.mobius_operator_callback = (direction == "decrement" and M.operator_decrement or M.operator_increment)
		vim.opt.operatorfunc = "v:lua._G.mobius_operator_callback"
		vim.api.nvim_feedkeys("g@l", "n", false)
	end
end

--- Wrapper for visual mode execute (lazy-load engine on demand).
---@param direction "increment"|"decrement"
---@param opts {visual: boolean, seqadd: boolean, step: number}
---@return nil
function M.execute(direction, opts)
	require("mobius.engine").execute(direction, opts)
end

return M
